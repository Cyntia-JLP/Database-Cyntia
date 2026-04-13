USE cyntia;

-- ───────────────────────────────────────────
-- 		      Usuarios por plan/rol
-- ───────────────────────────────────────────
CREATE USER 'cyntia_guest'@'%' IDENTIFIED BY 'guest_pass';
CREATE USER 'cyntia_demo'@'%' IDENTIFIED BY 'demo_pass';
CREATE USER 'cyntia_pro'@'%' IDENTIFIED BY 'pro_pass';
CREATE USER 'cyntia_enterprise'@'%' IDENTIFIED BY 'enterprise_pass';

-- ───────────────────────────────────────────
--           Solo estado de agentes
-- ───────────────────────────────────────────
CREATE VIEW vista_agentes_guest AS
SELECT 
    nombre_host,
    estado
FROM agentes;

-- ───────────────────────────────────────────
-- Alertas muy limitadas (sin datos sensibles)
-- ───────────────────────────────────────────
CREATE VIEW vista_alertas_guest AS
SELECT 
    id,
    titulo,
    severidad,
    estado,
    DATE(disparada_en) AS fecha
FROM alertas;

-- ───────────────────────────────────────────
--             Alertas limitadas
-- ───────────────────────────────────────────
CREATE VIEW vista_alertas_demo AS
SELECT 
    id,
    titulo,
    severidad,
    estado,
    disparada_en
FROM alertas;

-- ───────────────────────────────────────────
--        Agentes con algo más de info
-- ───────────────────────────────────────────
CREATE VIEW vista_agentes_demo AS
SELECT 
    nombre_host,
    estado,
    tipo_so
FROM agentes;

-- ───────────────────────────────────────────
--       Eventos limitados (sin log_raw)
-- ───────────────────────────────────────────
CREATE VIEW vista_eventos_pro AS
SELECT 
    id,
    agente_id,
    tipo_fuente,
    severidad,
    hora_evento
FROM eventos;

-- ───────────────────────────────────────────
--              Alertas completas
-- ───────────────────────────────────────────
CREATE VIEW vista_alertas_pro AS
SELECT *
FROM alertas;

-- ───────────────────────────────────────────
--             Eventos completos
-- ───────────────────────────────────────────
CREATE VIEW vista_eventos_enterprise AS
SELECT *
FROM eventos;

-- ───────────────────────────────────────────
--            Permisos para GUEST
-- ───────────────────────────────────────────
GRANT SELECT ON cyntia.vista_agentes_guest TO 'cyntia_guest'@'%';
GRANT SELECT ON cyntia.vista_alertas_guest TO 'cyntia_guest'@'%';

-- ───────────────────────────────────────────
--             Permisos para DEMO
-- ───────────────────────────────────────────
GRANT SELECT ON cyntia.vista_alertas_demo TO 'cyntia_demo'@'%';
GRANT SELECT ON cyntia.vista_agentes_demo TO 'cyntia_demo'@'%';

-- ───────────────────────────────────────────
--              Permisos para PRO
-- ───────────────────────────────────────────
GRANT SELECT ON cyntia.vista_alertas_pro TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.vista_eventos_pro TO 'cyntia_pro'@'%';

GRANT SELECT ON cyntia.agentes TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.reglas TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.inteligencia_amenazas TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.respuestas_incidente TO 'cyntia_pro'@'%';

SHOW GRANTS FOR 'cyntia_pro'@'%';

-- ───────────────────────────────────────────
--          Permisos para ENTERPRISE
-- ───────────────────────────────────────────
-- Acceso casi total (lectura)
GRANT SELECT ON cyntia.* TO 'cyntia_enterprise'@'%';

-- Opcional: permitir acciones
GRANT INSERT, UPDATE ON cyntia.alertas TO 'cyntia_enterprise'@'%';
GRANT INSERT, UPDATE ON cyntia.respuestas_incidente TO 'cyntia_enterprise'@'%';

-- Acceso al registro de actividad del cliente (sin datos sensibles internos)
GRANT SELECT ON cyntia.actividad_cliente TO 'cyntia_enterprise'@'%';

-- Aplicar cambios
FLUSH PRIVILEGES;