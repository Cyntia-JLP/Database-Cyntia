USE cyntia;

-- AUDITORÍAS

-- ───────────────────────────────────────────────────────────────────────────
-- 								  USUARIOS
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_usuario_insert
AFTER INSERT ON usuarios
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'crear_usuario',
'usuario',
NEW.id,
JSON_OBJECT(
  'email',    NEW.email,
  'nombre',   NEW.nombre,
  'apellido', NEW.apellido,
  'rol',      NEW.rol,
  'activo',   NEW.activo
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_usuario_update
AFTER UPDATE ON usuarios
FOR EACH ROW
BEGIN
DECLARE v_cambios JSON;

SET v_cambios = JSON_OBJECT(
  'email_anterior',    OLD.email,    'email_nuevo',    NEW.email,
  'nombre_anterior',   OLD.nombre,   'nombre_nuevo',   NEW.nombre,
  'apellido_anterior', OLD.apellido, 'apellido_nuevo', NEW.apellido,
  'rol_anterior',      OLD.rol,      'rol_nuevo',      NEW.rol,
  'activo_anterior',   OLD.activo,   'activo_nuevo',   NEW.activo
);

IF OLD.hash_contrasena != NEW.hash_contrasena THEN
  SET v_cambios = JSON_SET(v_cambios, '$.cambio_contrasena', TRUE);
END IF;

INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'modificar_usuario',
'usuario',
NEW.id,
v_cambios,
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_usuario_delete
BEFORE DELETE ON usuarios
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
OLD.org_id,
'eliminar_usuario',
'usuario',
OLD.id,
JSON_OBJECT(
  'email',    OLD.email,
  'nombre',   OLD.nombre,
  'apellido', OLD.apellido,
  'rol',      OLD.rol
),
NOW()
);
END //
DELIMITER ;

-- Propaga cada registro de auditoría interna a la tabla cliente, descartando los campos sensibles.
DELIMITER //
CREATE TRIGGER propagar_actividad_cliente
AFTER INSERT ON registros_auditoria
FOR EACH ROW
BEGIN
    -- Solo se propaga si el registro está asociado a una organización (algunos registros internos pueden tener org_id NULL)
    IF NEW.org_id IS NOT NULL THEN
        INSERT INTO actividad_cliente (id, org_id, accion, tipo_entidad, creado_en)
        VALUES (UUID(), NEW.org_id, NEW.accion, NEW.tipo_entidad, NEW.creado_en);
    END IF;
END //
DELIMITER ;

-- ───────────────────────────────────────────────────────────────────────────
-- 									AGENTES
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_agente_insert
AFTER INSERT ON agentes
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'registrar_agente',
'agente',
NEW.id,
JSON_OBJECT(
  'nombre_host',   NEW.nombre_host,
  'direccion_ip',  NEW.direccion_ip,
  'tipo_so',       NEW.tipo_so,
  'version_so',    NEW.version_so,
  'estado',        NEW.estado
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_agente_update
AFTER UPDATE ON agentes
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'modificar_agente',
'agente',
NEW.id,
JSON_OBJECT(
  'nombre_host_anterior', OLD.nombre_host, 'nombre_host_nuevo', NEW.nombre_host,
  'direccion_ip_anterior', OLD.direccion_ip, 'direccion_ip_nueva', NEW.direccion_ip,
  'estado_anterior',      OLD.estado,      'estado_nuevo',       NEW.estado,
  'version_so_anterior',  OLD.version_so,  'version_so_nueva',   NEW.version_so
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_agente_delete
BEFORE DELETE ON agentes
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
OLD.org_id,
'eliminar_agente',
'agente',
OLD.id,
JSON_OBJECT(
  'nombre_host',  OLD.nombre_host,
  'direccion_ip', OLD.direccion_ip,
  'tipo_so',      OLD.tipo_so,
  'estado',       OLD.estado
),
NOW()
);
END //
DELIMITER ;


-- ───────────────────────────────────────────────────────────────────────────
-- 								   REGLAS
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_regla_insert
AFTER INSERT ON reglas
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'crear_regla',
'regla',
NEW.id,
JSON_OBJECT(
  'nombre',         NEW.nombre,
  'severidad',      NEW.severidad,
  'tactica_mitre',  NEW.tactica_mitre,
  'tecnica_mitre',  NEW.tecnica_mitre,
  'activa',         NEW.activa
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_regla_update
AFTER UPDATE ON reglas
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'modificar_regla',
'regla',
NEW.id,
JSON_OBJECT(
  'nombre_anterior',           OLD.nombre,           'nombre_nuevo',           NEW.nombre,
  'condicion_query_anterior',  OLD.condicion_query,  'condicion_query_nueva',  NEW.condicion_query,
  'severidad_anterior',        OLD.severidad,        'severidad_nueva',        NEW.severidad,
  'tactica_mitre_anterior',    OLD.tactica_mitre,    'tactica_mitre_nueva',    NEW.tactica_mitre,
  'tecnica_mitre_anterior',    OLD.tecnica_mitre,    'tecnica_mitre_nueva',    NEW.tecnica_mitre,
  'activa_anterior',           OLD.activa,           'activa_nueva',           NEW.activa
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_regla_delete
BEFORE DELETE ON reglas
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
OLD.org_id,
'eliminar_regla',
'regla',
OLD.id,
JSON_OBJECT(
  'nombre',           OLD.nombre,
  'condicion_query',  OLD.condicion_query,
  'severidad',        OLD.severidad,
  'tactica_mitre',    OLD.tactica_mitre,
  'activa',           OLD.activa
),
NOW()
);
END //
DELIMITER ;

-- ───────────────────────────────────────────────────────────────────────────
-- 					   	   INFORMES DE CUMPLIMIENTO
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_informe_insert
AFTER INSERT ON informes_cumplimiento
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'generar_informe',
'informe_cumplimiento',
NEW.id,
JSON_OBJECT(
  'tipo_informe',   NEW.tipo_informe,
  'periodo_inicio', NEW.periodo_inicio,
  'periodo_fin',    NEW.periodo_fin,
  'estado',         NEW.estado,
  'generado_por',   NEW.generado_por
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_informe_update
AFTER UPDATE ON informes_cumplimiento
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'modificar_informe',
'informe_cumplimiento',
NEW.id,
JSON_OBJECT(
  'estado_anterior',       OLD.estado,       'estado_nuevo',       NEW.estado,
  'ruta_fichero_anterior', OLD.ruta_fichero, 'ruta_fichero_nueva', NEW.ruta_fichero
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_informe_delete
BEFORE DELETE ON informes_cumplimiento
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
OLD.org_id,
'eliminar_informe',
'informe_cumplimiento',
OLD.id,
JSON_OBJECT(
  'tipo_informe',   OLD.tipo_informe,
  'periodo_inicio', OLD.periodo_inicio,
  'periodo_fin',    OLD.periodo_fin,
  'estado',         OLD.estado
),
NOW()
);
END //
DELIMITER ;

-- ───────────────────────────────────────────────────────────────────────────
-- 					       INTELIGENCIA AMENAZAS
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_inteligencia_insert
AFTER INSERT ON inteligencia_amenazas
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'crear_inteligencia',
'inteligencia_amenazas',
NEW.id,
JSON_OBJECT(
  'tipo_ioc',    NEW.tipo_ioc,
  'valor',       NEW.valor,
  'confianza',   NEW.confianza,
  'fuente',      NEW.fuente,
  'valido_hasta',NEW.valido_hasta
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_inteligencia_update
AFTER UPDATE ON inteligencia_amenazas
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
NEW.org_id,
'modificar_inteligencia',
'inteligencia_amenazas',
NEW.id,
JSON_OBJECT(
  'tipo_ioc_anterior',    OLD.tipo_ioc,    'tipo_ioc_nuevo',    NEW.tipo_ioc,
  'valor_anterior',       OLD.valor,       'valor_nuevo',       NEW.valor,
  'confianza_anterior',   OLD.confianza,   'confianza_nueva',   NEW.confianza,
  'fuente_anterior',      OLD.fuente,      'fuente_nueva',      NEW.fuente,
  'valido_hasta_anterior',OLD.valido_hasta,'valido_hasta_nueva',NEW.valido_hasta
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_inteligencia_delete
BEFORE DELETE ON inteligencia_amenazas
FOR EACH ROW
BEGIN
INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
OLD.org_id,
'eliminar_inteligencia',
'inteligencia_amenazas',
OLD.id,
JSON_OBJECT(
  'tipo_ioc',    OLD.tipo_ioc,
  'valor',       OLD.valor,
  'confianza',   OLD.confianza,
  'fuente',      OLD.fuente,
  'valido_hasta',OLD.valido_hasta
),
NOW()
);
END //
DELIMITER ;

-- ───────────────────────────────────────────────────────────────────────────
-- 								   EVENTOS
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_evento_insert
AFTER INSERT ON eventos
FOR EACH ROW
BEGIN
DECLARE v_org_id CHAR(36);
SELECT org_id INTO v_org_id FROM agentes WHERE id = NEW.agente_id LIMIT 1;

INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
v_org_id,
'ingestar_evento',
'evento',
NEW.id,
JSON_OBJECT(
  'agente_id',    NEW.agente_id,
  'tipo_fuente',  NEW.tipo_fuente,
  'severidad',    NEW.severidad,
  'tactica_mitre',NEW.tactica_mitre,
  'tecnica_mitre',NEW.tecnica_mitre,
  'hora_evento',  NEW.hora_evento
),
NOW()
);
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_evento_delete
BEFORE DELETE ON eventos
FOR EACH ROW
BEGIN
DECLARE v_org_id CHAR(36);
SELECT org_id INTO v_org_id FROM agentes WHERE id = OLD.agente_id LIMIT 1;

INSERT INTO registros_auditoria
(id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
VALUES (
UUID(),
@usuario_actual,
v_org_id,
'eliminar_evento',
'evento',
OLD.id,
JSON_OBJECT(
  'agente_id',   OLD.agente_id,
  'tipo_fuente', OLD.tipo_fuente,
  'severidad',   OLD.severidad,
  'hora_evento', OLD.hora_evento
),
NOW()
);
END //
DELIMITER ;

-- ---------------------------------------------------------------------------------------
-- 1. La aplicación establece quién está operando
SET @usuario_actual = 'uuid-del-usuario-logueado';

-- 2. Se ejecuta la operación normal (el trigger se dispara solo)
UPDATE reglas SET activa = 0 WHERE id = 'uuid-de-la-regla';

-- Establecer el usuario de sesión
SET @usuario_actual = (SELECT id FROM usuarios WHERE email = 'admin@demo.cyntia.local');

-- Realizar una operación de prueba
UPDATE reglas SET activa = 0 WHERE nombre = 'Puerto sospechoso';

-- Verificar que usuario_id se ha rellenado
SELECT usuario_id, accion, tipo_entidad, cambios
FROM registros_auditoria
ORDER BY creado_en DESC
LIMIT 3;