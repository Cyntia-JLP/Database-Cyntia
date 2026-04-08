USE cyntia;

-- ────────────────────────────────────────────
-- 				   AUDITORÍAS
-- ────────────────────────────────────────────

-- ────────────────────────────────────────────
-- 1. ORGANIZACIONES
-- ────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_organizacion_insert
AFTER INSERT ON organizaciones
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.id,
    'crear_organizacion',
    'organizacion',
    NEW.id,
    JSON_OBJECT(
      'nombre',  NEW.nombre,
      'dominio', NEW.dominio,
      'plan',    NEW.plan,
      'activa',  NEW.activa
    ),
    NOW()
  );
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_organizacion_update
AFTER UPDATE ON organizaciones
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.id,
    'modificar_organizacion',
    'organizacion',
    NEW.id,
    JSON_OBJECT(
      'nombre_anterior',  OLD.nombre,  'nombre_nuevo',  NEW.nombre,
      'dominio_anterior', OLD.dominio, 'dominio_nuevo', NEW.dominio,
      'plan_anterior',    OLD.plan,    'plan_nuevo',    NEW.plan,
      'activa_anterior',  OLD.activa,  'activa_nueva',  NEW.activa
    ),
    NOW()
  );
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_organizacion_delete
BEFORE DELETE ON organizaciones
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    OLD.id,
    'eliminar_organizacion',
    'organizacion',
    OLD.id,
    JSON_OBJECT(
      'nombre',  OLD.nombre,
      'dominio', OLD.dominio,
      'plan',    OLD.plan
    ),
    NOW()
  );
END //
DELIMITER ;


-- ───────────────────────────────────────────────────────────────────────────
-- 2. AGENTES
--    (validar_ip_agente ya existe como BEFORE INSERT; aquí solo se audita)
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_agente_insert
AFTER INSERT ON agentes
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.org_id,
    'registrar_agente',
    'agente',
    NEW.id,
    JSON_OBJECT(
      'nombre_host',  NEW.nombre_host,
      'direccion_ip', NEW.direccion_ip,
      'tipo_so',      NEW.tipo_so,
      'version_so',   NEW.version_so,
      'estado',       NEW.estado
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
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.org_id,
    'modificar_agente',
    'agente',
    NEW.id,
    JSON_OBJECT(
      'nombre_host_anterior',  OLD.nombre_host,  'nombre_host_nuevo',  NEW.nombre_host,
      'direccion_ip_anterior', OLD.direccion_ip, 'direccion_ip_nueva', NEW.direccion_ip,
      'estado_anterior',       OLD.estado,       'estado_nuevo',       NEW.estado,
      'version_so_anterior',   OLD.version_so,   'version_so_nueva',   NEW.version_so
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
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
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
-- 3. USUARIOS
--    NOTA: hash_contrasena NUNCA se almacena en la auditoría;
--          solo se registra si el campo fue modificado.
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_usuario_insert
AFTER INSERT ON usuarios
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
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

  -- Registrar cambio de contraseña sin exponer el hash
  IF OLD.hash_contrasena != NEW.hash_contrasena THEN
    SET v_cambios = JSON_SET(v_cambios, '$.cambio_contrasena', TRUE);
  END IF;

  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
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
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
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


-- ───────────────────────────────────────────────────────────────────────────
-- 4. REGLAS
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_regla_insert
AFTER INSERT ON reglas
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.org_id,
    'crear_regla',
    'regla',
    NEW.id,
    JSON_OBJECT(
      'nombre',        NEW.nombre,
      'severidad',     NEW.severidad,
      'tactica_mitre', NEW.tactica_mitre,
      'tecnica_mitre', NEW.tecnica_mitre,
      'activa',        NEW.activa
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
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.org_id,
    'modificar_regla',
    'regla',
    NEW.id,
    JSON_OBJECT(
      'nombre_anterior',          OLD.nombre,          'nombre_nuevo',          NEW.nombre,
      'condicion_query_anterior', OLD.condicion_query, 'condicion_query_nueva', NEW.condicion_query,
      'severidad_anterior',       OLD.severidad,       'severidad_nueva',       NEW.severidad,
      'tactica_mitre_anterior',   OLD.tactica_mitre,   'tactica_mitre_nueva',   NEW.tactica_mitre,
      'tecnica_mitre_anterior',   OLD.tecnica_mitre,   'tecnica_mitre_nueva',   NEW.tecnica_mitre,
      'activa_anterior',          OLD.activa,          'activa_nueva',          NEW.activa
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
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
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
-- 5. ALERTAS
--    UPDATE de estado → ya cubierto por 'auditoria_cambio_alerta'
--    Solo se añaden INSERT y DELETE
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_alerta_insert
AFTER INSERT ON alertas
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.org_id,
    'crear_alerta',
    'alerta',
    NEW.id,
    JSON_OBJECT(
      'titulo',      NEW.titulo,
      'severidad',   NEW.severidad,
      'estado',      NEW.estado,
      'regla_id',    NEW.regla_id,
      'asignado_a',  NEW.asignado_a
    ),
    NOW()
  );
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_alerta_delete
BEFORE DELETE ON alertas
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    OLD.org_id,
    'eliminar_alerta',
    'alerta',
    OLD.id,
    JSON_OBJECT(
      'titulo',    OLD.titulo'severidad', OLD.severidad,
      'estado',    OLD.estado,
      'regla_id',  OLD.regla_id
    ),
    NOW()
  );
END //
DELIMITER ;


-- ───────────────────────────────────────────────────────────────────────────
-- 6. EVENTOS
--    Los eventos son telemetría inmutable; no se audita UPDATE.
--    El org_id se obtiene mediante subquery a agentes.
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_evento_insert
AFTER INSERT ON eventos
FOR EACH ROW
BEGIN
  DECLARE v_org_id CHAR(36);
  SELECT org_id INTO v_org_id FROM agentes WHERE id = NEW.agente_id LIMIT 1;

  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    v_org_id,
    'ingestar_evento',
    'evento',
    NEW.id,
    JSON_OBJECT(
      'agente_id',     NEW.agente_id,
      'tipo_fuente',   NEW.tipo_fuente,
      'severidad',     NEW.severidad,
      'tactica_mitre', NEW.tactica_mitre,
      'tecnica_mitre', NEW.tecnica_mitre,
      'hora_evento',   NEW.hora_evento
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
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
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


-- ───────────────────────────────────────────────────────────────────────────
-- 7. INFORMES DE CUMPLIMIENTO
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_informe_insert
AFTER INSERT ON informes_cumplimiento
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.org_id,
    'generar_informe',
    'informe_cumplimiento',
    NEW.id,
    JSON_OBJECT(
      'tipo_informe',    NEW.tipo_informe,
      'periodo_inicio',  NEW.periodo_inicio,
      'periodo_fin',     NEW.periodo_fin,
      'estado',          NEW.estado,
      'generado_por',    NEW.generado_por
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
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.org_id,
    'modificar_informe',
    'informe_cumplimiento',
    NEW.id,
    JSON_OBJECT(
      'estado_anterior',       OLD.estado,       'estado_nuevo',       NEW.estado,
      'ruta_fichero_anterior', OLD.ruta_fichero,  'ruta_fichero_nueva', NEW.ruta_fichero
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
    (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
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
-- 8. SESIONES DE USUARIO
--    Se audita apertura (INSERT) y cierre (DELETE) de sesión.
--    El org_id se obtiene mediante subquery a usuarios.
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_sesion_insert
AFTER INSERT ON sesiones_usuario
FOR EACH ROW
BEGIN
  DECLARE v_org_id CHAR(36);
  SELECT org_id INTO v_org_id FROM usuarios WHERE id = NEW.usuario_id LIMIT 1;

  INSERT INTO registros_auditoria
    (id, usuario_id, org_id, accion, tipo_entidad, entidad_id, direccion_ip, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.usuario_id,
    v_org_id,
    'iniciar_sesion',
    'sesion_usuario',
    NEW.id,
    NEW.direccion_ip,
    JSON_OBJECT(
      'agente_usuario', NEW.agente_usuario,
      'expira_en',      NEW.expira_en
    ),
    NOW()
  );
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_sesion_delete
BEFORE DELETE ON sesiones_usuario
FOR EACH ROW
BEGIN
  DECLARE v_org_id CHAR(36);
  SELECT org_id INTO v_org_id FROM usuarios WHERE id = OLD.usuario_id LIMIT 1;

  INSERT INTO registros_auditoria
    (id, usuario_id, org_id, accion, tipo_entidad, entidad_id, direccion_ip, cambios, creado_en)
  VALUES (
    UUID(),
    OLD.usuario_id,
    v_org_id,
    'cerrar_sesion',
    'sesion_usuario',
    OLD.id,
    OLD.direccion_ip,
    JSON_OBJECT(
      'agente_usuario', OLD.agente_usuario,
      'expira_en',      OLD.expira_en
    ),
    NOW()
  );
END //
DELIMITER ;


-- ───────────────────────────────────────────────────────────────────────────
-- 9. TOKENS DE VERIFICACIÓN DE EMAIL
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_token_verificacion_insert
AFTER INSERT ON tokens_verificacion_email
FOR EACH ROW
BEGIN
  DECLARE v_org_id CHAR(36);
  SELECT org_id INTO v_org_id FROM usuarios WHERE id = NEW.usuario_id LIMIT 1;

  INSERT INTO registros_auditoria
    (id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.usuario_id,
    v_org_id,
    'generar_token_verificacion',
    'token_verificacion_email',
    NEW.id,
    JSON_OBJECT(
      'expira_en', NEW.expira_en
    ),
    NOW()
  );
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_token_verificacion_update
AFTER UPDATE ON tokens_verificacion_email
FOR EACH ROW
BEGIN
  DECLARE v_org_id CHAR(36);

  -- Solo auditar cuando el token pasa a usado
  IF OLD.usado_en IS NULL AND NEW.usado_en IS NOT NULL THEN
    SELECT org_id INTO v_org_id FROM usuarios WHERE id = NEW.usuario_id LIMIT 1;

    INSERT INTO registros_auditoria
      (id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
    VALUES (
      UUID(),
      NEW.usuario_id,
      v_org_id,
      'usar_token_verificacion',
      'token_verificacion_email',
      NEW.id,
      JSON_OBJECT(
        'usado_en', NEW.usado_en
      ),
      NOW()
    );
  END IF;
END //
DELIMITER ;


-- ───────────────────────────────────────────────────────────────────────────
-- 10. TOKENS DE RECUPERACIÓN DE CONTRASEÑA
-- ───────────────────────────────────────────────────────────────────────────

DELIMITER //
CREATE TRIGGER auditoria_token_recuperacion_insert
AFTER INSERT ON tokens_recuperacion_contrasena
FOR EACH ROW
BEGIN
  DECLARE v_org_id CHAR(36);
  SELECT org_id INTO v_org_id FROM usuarios WHERE id = NEW.usuario_id LIMIT 1;

  INSERT INTO registros_auditoria
    (id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(),
    NEW.usuario_id,
    v_org_id,
    'solicitar_recuperacion_contrasena',
    'token_recuperacion_contrasena',
    NEW.id,
    JSON_OBJECT(
      'expira_en', NEW.expira_en
    ),
    NOW()
  );
END //
DELIMITER ;

DELIMITER //
CREATE TRIGGER auditoria_token_recuperacion_update
AFTER UPDATE ON tokens_recuperacion_contrasena
FOR EACH ROW
BEGIN
  DECLARE v_org_id CHAR(36);

  -- Solo auditar cuando el token pasa a usado (contraseña efectivamente cambiada)
  IF OLD.usado_en IS NULL AND NEW.usado_en IS NOT NULL THEN
    SELECT org_id INTO v_org_id FROM usuarios WHERE id = NEW.usuario_id LIMIT 1;

    INSERT INTO registros_auditoria
      (id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
    VALUES (
      UUID(),
      NEW.usuario_id,
      v_org_id,
      'completar_recuperacion_contrasena',
      'token_recuperacion_contrasena',
      NEW.id,
      JSON_OBJECT(
        'usado_en', NEW.usado_en
      ),
      NOW()
    );
  END IF;
END //
DELIMITER ;