USE cyntia;

-- ─────────────────────────────────────────
-- 		     CONSULTAS AVANZADAS
-- ─────────────────────────────────────────

-- 1. Devuelve TRUE si un agente ha enviado latido en los últimos N minutos
DELIMITER //
CREATE FUNCTION agente_activo(id_agente CHAR(36), minutos INT)
RETURNS TINYINT(1)
DETERMINISTIC
BEGIN
    DECLARE ultima DATETIME;
    SELECT ultima_conexion INTO ultima FROM agentes WHERE id = id_agente;
    RETURN ultima >= DATE_SUB(NOW(), INTERVAL minutos MINUTE);
END //
DELIMITER ;

SELECT nombre_host, estado, agente_activo(id, 5) AS activo_hace_5min FROM agentes;


-- 2. Devuelve el número de alertas abiertas de una organización
DELIMITER //
CREATE FUNCTION contar_alertas_abiertas(id_org CHAR(36))
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE total INT;
    SELECT COUNT(*) INTO total FROM alertas WHERE org_id = id_org AND estado = 'abierta';
    RETURN total;
END //
DELIMITER ;

SELECT nombre, contar_alertas_abiertas(id) AS alertas_abiertas FROM organizaciones;


-- 3. Devuelve el nivel de riesgo en texto según la severidad numérica del evento
DELIMITER //
CREATE FUNCTION nivel_riesgo(severidad TINYINT)
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    IF severidad <= 3 THEN RETURN 'Informativo';
    ELSEIF severidad <= 5 THEN RETURN 'Bajo';
    ELSEIF severidad <= 7 THEN RETURN 'Medio';
    ELSEIF severidad <= 9 THEN RETURN 'Alto';
    ELSE RETURN 'Critico';
    END IF;
END //
DELIMITER ;

SELECT id, severidad, nivel_riesgo(severidad) AS riesgo FROM eventos ORDER BY severidad DESC;


-- ─── PROCEDIMIENTOS ──────────────────────────────────────────


-- 1. Registra una nueva alerta y la asigna al analista con menos carga
DELIMITER //
CREATE PROCEDURE crear_alerta(
    IN p_regla_id   CHAR(36),
    IN p_org_id     CHAR(36),
    IN p_titulo     VARCHAR(255),
    IN p_severidad  ENUM('baja', 'media', 'alta', 'critica'),
    OUT p_mensaje   VARCHAR(100)
)
BEGIN
    DECLARE analista_id CHAR(36);
    DECLARE nuevo_id    CHAR(36);

    SELECT u.id INTO analista_id
    FROM usuarios u
    LEFT JOIN alertas a ON a.asignado_a = u.id AND a.estado = 'abierta'
    WHERE u.org_id = p_org_id AND u.rol = 'analyst' AND u.activo = 1
    GROUP BY u.id
    ORDER BY COUNT(a.id) ASC
    LIMIT 1;

    SET nuevo_id = UUID();

    INSERT INTO alertas (id, regla_id, org_id, asignado_a, severidad, titulo)
    VALUES (nuevo_id, p_regla_id, p_org_id, analista_id, p_severidad, p_titulo);

    SET p_mensaje = CONCAT('Alerta creada y asignada al analista: ', IFNULL(analista_id, 'sin asignar'));
END //
DELIMITER ;

CALL crear_alerta(
    (SELECT id FROM reglas WHERE nombre = 'Fuerza bruta SSH'),
    (SELECT id FROM organizaciones WHERE dominio = 'demo.cyntia.local'),
    'SSH Brute Force - 192.168.1.45 -> srv-main',
    'alta',
    @mensaje
);
SELECT @mensaje;


-- 2. Cierra todas las alertas marcadas como falso positivo de una organización
DELIMITER //
CREATE PROCEDURE limpiar_falsos_positivos(
    IN p_org_id     CHAR(36),
    OUT p_mensaje   VARCHAR(100)
)
BEGIN
    DECLARE total INT;

    SELECT COUNT(*) INTO total FROM alertas
    WHERE org_id = p_org_id AND estado = 'falso_positivo';

    UPDATE alertas SET estado = 'resuelta', resuelta_en = NOW()
    WHERE org_id = p_org_id AND estado = 'falso_positivo';

    SET p_mensaje = CONCAT(total, ' alertas cerradas correctamente.');
END //
DELIMITER ;

CALL limpiar_falsos_positivos(
    (SELECT id FROM organizaciones WHERE dominio = 'demo.cyntia.local'),
    @mensaje
);
SELECT @mensaje;


-- ─── TRIGGERS ────────────────────────────────────────────────


-- 1. Registra en auditoría cualquier cambio de estado en una alerta
DELIMITER //
CREATE TRIGGER auditoria_cambio_alerta
AFTER UPDATE ON alertas
FOR EACH ROW
BEGIN
    IF OLD.estado != NEW.estado THEN
        INSERT INTO registros_auditoria (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
        VALUES (
            UUID(),
            NEW.org_id,
            'cambio_estado_alerta',
            'alerta',
            NEW.id,
            JSON_OBJECT('estado_anterior', OLD.estado, 'estado_nuevo', NEW.estado),
            NOW()
        );
    END IF;
END //
DELIMITER ;


-- 2. Impide registrar un agente con una IP ya existente en la misma organización
DELIMITER //
CREATE TRIGGER validar_ip_agente
BEFORE INSERT ON agentes
FOR EACH ROW
BEGIN
    DECLARE existe INT;

    SELECT COUNT(*) INTO existe FROM agentes
    WHERE org_id = NEW.org_id AND direccion_ip = NEW.direccion_ip;

    IF existe > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ya existe un agente con esa IP en la organización.';
    END IF;
END //
DELIMITER ;


-- 3. Cuando se resuelve una alerta, registra automáticamente la fecha de cierre
DELIMITER //
CREATE TRIGGER fecha_resolucion_alerta
BEFORE UPDATE ON alertas
FOR EACH ROW
BEGIN
    IF NEW.estado IN ('resuelta', 'falso_positivo') AND OLD.resuelta_en IS NULL THEN
        SET NEW.resuelta_en = NOW();
    END IF;
END //
DELIMITER ;