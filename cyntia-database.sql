CREATE DATABASE cyntia;
USE cyntia;


-- ─── BLOQUE 1: Organización y usuarios ───────────────────────


-- Tabla raíz del sistema, todas las demás tablas dependen de esta
CREATE TABLE organizaciones (
    id          CHAR(36)        PRIMARY KEY,
    nombre      VARCHAR(255)    NOT NULL,
    dominio     VARCHAR(255)    NOT NULL UNIQUE,
    plan        ENUM('core', 'pro', 'enterprise') NOT NULL DEFAULT 'core',
    activa      TINYINT(1)      NOT NULL DEFAULT 1,
    creado_en   DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Cuentas de acceso al sistema, la contraseña se guarda siempre hasheada
CREATE TABLE usuarios (
    id                  CHAR(36)        PRIMARY KEY,
    org_id              CHAR(36)        NOT NULL,
    email               VARCHAR(255)    NOT NULL UNIQUE,
    hash_contrasena     VARCHAR(255)    NOT NULL,
    nombre              VARCHAR(100)    NOT NULL,
    apellido            VARCHAR(100)    NOT NULL,
    rol                 ENUM('admin', 'analyst', 'viewer') NOT NULL DEFAULT 'viewer',
    activo              TINYINT(1)      NOT NULL DEFAULT 1,
    email_verificado    TINYINT(1)      NOT NULL DEFAULT 0,
    ultimo_acceso       DATETIME,
    creado_en           DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_id) REFERENCES organizaciones(id) ON DELETE CASCADE
);


-- Registro de sesiones activas, permite cerrarlas remotamente si hay una brecha
CREATE TABLE sesiones_usuario (
    id              CHAR(36)        PRIMARY KEY,
    usuario_id      CHAR(36)        NOT NULL,
    hash_token      VARCHAR(255)    NOT NULL,
    direccion_ip    VARCHAR(45),
    agente_usuario  VARCHAR(500),
    expira_en       DATETIME        NOT NULL,
    creado_en       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);


-- ─── BLOQUE 2: Autenticación ─────────────────────────────────


-- Token que se envía por email al registrarse para verificar la cuenta
CREATE TABLE tokens_verificacion_email (
    id          CHAR(36)    PRIMARY KEY,
    usuario_id  CHAR(36)    NOT NULL,
    token       CHAR(36)    NOT NULL UNIQUE,
    expira_en   DATETIME    NOT NULL,
    usado_en    DATETIME,
    creado_en   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);


-- Token de un solo uso para el flujo de recuperación de contraseña
CREATE TABLE tokens_recuperacion_contrasena (
    id          CHAR(36)    PRIMARY KEY,
    usuario_id  CHAR(36)    NOT NULL,
    token       CHAR(36)    NOT NULL UNIQUE,
    expira_en   DATETIME    NOT NULL,
    usado_en    DATETIME,
    creado_en   DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE
);


-- ─── BLOQUE 3: Infraestructura y eventos ─────────────────────


-- Cada endpoint con un agente instalado (servidor, PC, máquina virtual)
CREATE TABLE agentes (
    id              CHAR(36)        PRIMARY KEY,
    org_id          CHAR(36)        NOT NULL,
    nombre_host     VARCHAR(255)    NOT NULL,
    direccion_ip    VARCHAR(45)     NOT NULL,
    tipo_so         VARCHAR(50),
    version_so      VARCHAR(100),
    version_agente  VARCHAR(50),
    estado          ENUM('online', 'offline', 'warning') NOT NULL DEFAULT 'offline',
    ultima_conexion DATETIME,
    creado_en       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_id) REFERENCES organizaciones(id) ON DELETE CASCADE
);


-- Tabla principal del SIEM, almacena cada log recibido de los agentes
CREATE TABLE eventos (
    id                  CHAR(36)    PRIMARY KEY,
    agente_id           CHAR(36)    NOT NULL,
    tipo_fuente         VARCHAR(50),
    log_raw             TEXT,
    datos_normalizados  JSON,
    tactica_mitre       VARCHAR(10),
    tecnica_mitre       VARCHAR(10),
    severidad           TINYINT     NOT NULL DEFAULT 1,
    hora_evento         DATETIME    NOT NULL,
    ingestado_en        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (agente_id) REFERENCES agentes(id) ON DELETE CASCADE,
    INDEX idx_eventos_hora      (hora_evento),
    INDEX idx_eventos_severidad (severidad),
    INDEX idx_eventos_tactica   (tactica_mitre)
);


-- ─── BLOQUE 4: Detección y respuesta ─────────────────────────


-- Reglas de detección del motor SIEM, mapeadas a MITRE ATT&CK
CREATE TABLE reglas (
    id              CHAR(36)        PRIMARY KEY,
    org_id          CHAR(36),
    nombre          VARCHAR(255)    NOT NULL,
    descripcion     TEXT,
    condicion_query TEXT            NOT NULL,
    tactica_mitre   VARCHAR(10),
    tecnica_mitre   VARCHAR(10),
    severidad       ENUM('baja', 'media', 'alta', 'critica') NOT NULL DEFAULT 'media',
    activa          TINYINT(1)      NOT NULL DEFAULT 1,
    creado_en       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_id) REFERENCES organizaciones(id) ON DELETE CASCADE
);


-- Alerta generada cuando un evento satisface una regla de detección
CREATE TABLE alertas (
    id              CHAR(36)    PRIMARY KEY,
    regla_id        CHAR(36),
    org_id          CHAR(36)    NOT NULL,
    asignado_a      CHAR(36),
    severidad       ENUM('baja', 'media', 'alta', 'critica') NOT NULL DEFAULT 'media',
    estado          ENUM('abierta', 'en_progreso', 'resuelta', 'falso_positivo') NOT NULL DEFAULT 'abierta',
    titulo          VARCHAR(255)    NOT NULL,
    descripcion     TEXT,
    contexto        JSON,
    disparada_en    DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resuelta_en     DATETIME,
    FOREIGN KEY (regla_id)   REFERENCES reglas(id)          ON DELETE SET NULL,
    FOREIGN KEY (org_id)     REFERENCES organizaciones(id)   ON DELETE CASCADE,
    FOREIGN KEY (asignado_a) REFERENCES usuarios(id)         ON DELETE SET NULL,
    INDEX idx_alertas_estado    (estado),
    INDEX idx_alertas_severidad (severidad)
);


-- Tabla puente N:M para correlacionar una alerta con múltiples eventos
CREATE TABLE alertas_eventos (
    alerta_id           CHAR(36)    NOT NULL,
    evento_id           CHAR(36)    NOT NULL,
    es_evento_principal TINYINT(1)  NOT NULL DEFAULT 0,
    vinculado_en        DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (alerta_id, evento_id),
    FOREIGN KEY (alerta_id) REFERENCES alertas(id) ON DELETE CASCADE,
    FOREIGN KEY (evento_id) REFERENCES eventos(id) ON DELETE CASCADE
);


-- Acciones tomadas ante una alerta, automáticas o manuales
CREATE TABLE respuestas_incidente (
    id              CHAR(36)    PRIMARY KEY,
    alerta_id       CHAR(36)    NOT NULL,
    tipo_accion     ENUM('bloquear_ip', 'aislar_host', 'notificar_email', 'notificar_slack', 'ejecutar_script') NOT NULL,
    parametros      JSON,
    estado          ENUM('pendiente', 'ejecutada', 'fallida') NOT NULL DEFAULT 'pendiente',
    resultado       TEXT,
    es_automatica   TINYINT(1)  NOT NULL DEFAULT 0,
    ejecutada_en    DATETIME,
    FOREIGN KEY (alerta_id) REFERENCES alertas(id) ON DELETE CASCADE
);


-- ─── BLOQUE 5: Inteligencia y cumplimiento ────────────────────


-- IOCs: IPs maliciosas, dominios, hashes, URLs de fuentes como MISP o VirusTotal
CREATE TABLE inteligencia_amenazas (
    id              CHAR(36)        PRIMARY KEY,
    org_id          CHAR(36)        NOT NULL,
    tipo_ioc        ENUM('ip', 'dominio', 'hash_md5', 'hash_sha256', 'url', 'email') NOT NULL,
    valor           VARCHAR(512)    NOT NULL,
    confianza       TINYINT         NOT NULL DEFAULT 50,
    fuente          VARCHAR(100),
    descripcion     TEXT,
    valido_hasta    DATETIME,
    creado_en       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_id) REFERENCES organizaciones(id) ON DELETE CASCADE,
    INDEX idx_ioc_tipo_valor (tipo_ioc, valor(100)),
    INDEX idx_ioc_valido     (valido_hasta)
);


-- Tabla puente N:M para registrar qué IOCs coinciden con qué eventos
CREATE TABLE eventos_ioc (
    evento_id           CHAR(36)        NOT NULL,
    ioc_id              CHAR(36)        NOT NULL,
    campo_coincidencia  VARCHAR(100),
    detectado_en        DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (evento_id, ioc_id),
    FOREIGN KEY (evento_id) REFERENCES eventos(id)               ON DELETE CASCADE,
    FOREIGN KEY (ioc_id)    REFERENCES inteligencia_amenazas(id) ON DELETE CASCADE
);


-- Canales de notificación configurados por cada organización
CREATE TABLE canales_notificacion (
    id              CHAR(36)    PRIMARY KEY,
    org_id          CHAR(36)    NOT NULL,
    tipo_canal      ENUM('email', 'slack', 'webhook', 'telegram') NOT NULL,
    configuracion   JSON,
    activo          TINYINT(1)  NOT NULL DEFAULT 1,
    creado_en       DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_id) REFERENCES organizaciones(id) ON DELETE CASCADE
);


-- Informes de cumplimiento normativo generados: PCI-DSS, ISO 27001, ENS
CREATE TABLE informes_cumplimiento (
    id              CHAR(36)    PRIMARY KEY,
    org_id          CHAR(36)    NOT NULL,
    generado_por    CHAR(36),
    tipo_informe    ENUM('pci_dss', 'iso_27001', 'ens') NOT NULL,
    periodo_inicio  DATE        NOT NULL,
    periodo_fin     DATE        NOT NULL,
    estado          ENUM('generando', 'completado', 'error') NOT NULL DEFAULT 'generando',
    ruta_fichero    VARCHAR(500),
    generado_en     DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_id)       REFERENCES organizaciones(id) ON DELETE CASCADE,
    FOREIGN KEY (generado_por) REFERENCES usuarios(id)       ON DELETE SET NULL
);


-- ─── BLOQUE 6: Auditoría ─────────────────────────────────────


-- Historial inmutable de todas las acciones realizadas en el sistema
CREATE TABLE registros_auditoria (
    id              CHAR(36)        PRIMARY KEY,
    usuario_id      CHAR(36),
    org_id          CHAR(36),
    accion          VARCHAR(100)    NOT NULL,
    tipo_entidad    VARCHAR(50),
    entidad_id      CHAR(36),
    cambios         JSON,
    direccion_ip    VARCHAR(45),
    creado_en       DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id)       ON DELETE SET NULL,
    FOREIGN KEY (org_id)     REFERENCES organizaciones(id) ON DELETE SET NULL,
    INDEX idx_auditoria_usuario (usuario_id),
    INDEX idx_auditoria_fecha   (creado_en)
);


-- ─── DATOS INICIALES ─────────────────────────────────────────


-- Organización de prueba
INSERT INTO organizaciones (id, nombre, dominio, plan) VALUES
(UUID(), 'Cyntia Demo', 'demo.cyntia.local', 'pro');

-- Usuario administrador por defecto (contraseña: hasheada en la aplicación)
INSERT INTO usuarios (id, org_id, email, hash_contrasena, nombre, apellido, rol, email_verificado)
VALUES (UUID(), (SELECT id FROM organizaciones WHERE dominio = 'demo.cyntia.local'), 'admin@demo.cyntia.local', 'hash_aqui', 'Admin', 'Cyntia', 'admin', 1);

-- Reglas de detección base del sistema (org_id NULL = disponibles para todos)
INSERT INTO reglas (id, org_id, nombre, descripcion, condicion_query, tactica_mitre, tecnica_mitre, severidad) VALUES
(UUID(), NULL, 'Fuerza bruta SSH',        'Más de 10 fallos de login SSH en 60 segundos desde la misma IP', 'failed_login_count > 10 AND interval < 60', 'TA0006', 'T1110', 'alta'),
(UUID(), NULL, 'Escalada de privilegios', 'Uso de sudo o su por un usuario sin permisos previos',           'event_type = "privilege_escalation"',       'TA0004', 'T1548', 'critica'),
(UUID(), NULL, 'Puerto sospechoso',       'Apertura de un puerto no autorizado en la configuración',        'event_type = "port_open"',                  'TA0011', 'T1571', 'media');


-- ─── FUNCIONES ───────────────────────────────────────────────


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
