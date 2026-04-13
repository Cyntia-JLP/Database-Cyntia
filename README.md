# Introducción

En esta sección se explica qué es lo que se ha realizado y todo el proceso detrás de la creación de la Base de Datos. Toda la información está separada por secciones para su entendimiento. A continuación, se lista un índice con dichas secciones:

<details>
<summary>Base de datos</summary>

# Base de datos

En este apartado documentamos el diseño y la implementación de la base de datos que sustenta **Cyntia**, la plataforma SIEM (Security Information and Event Management) que hemos desarrollado como proyecto final de segundo curso del ciclo formativo de Administración de Sistemas Informáticos en Red (ASIR).

La base de datos ha sido diseñada en **MySQL** y su objetivo es centralizar toda la información relativa a organizaciones, usuarios, agentes de monitorización, eventos de seguridad, alertas, reglas de detección y auditoría del sistema. El diseño sigue un modelo relacional normalizado que garantiza la integridad referencial entre las distintas entidades del sistema.

***

### Objetivos del diseño

La base de datos de Cyntia cumple con los siguientes objetivos:

* Almacenar de forma segura y estructurada los datos de múltiples organizaciones, cada una con sus propios usuarios, agentes y configuraciones.
* Registrar en tiempo real los eventos de seguridad recibidos desde los agentes instalados en los equipos monitorizados.
* Facilitar la detección de amenazas mediante reglas configurables mapeadas al framework MITRE ATT\&CK.
* Proporcionar un sistema de alertas completo, con asignación automática a analistas y seguimiento del ciclo de vida de cada incidente.
* Mantener un registro de auditoría inmutable de todas las acciones realizadas en el sistema.
* Controlar el acceso a los datos según el plan contratado por cada organización, aplicando el principio de mínimo privilegio.

***

### Arquitectura multi-tenant

Lo primero que decidimos fue que Cyntia tenía que poder dar servicio a varias empresas desde una misma instalación, sin que los datos de una se mezclaran con los de otra. A esto se le llama arquitectura **multi-tenant**.

Para conseguirlo, creamos una tabla `organizaciones` que actúa como raíz de todo el sistema. Prácticamente todas las demás tablas tienen una columna `org_id` que referencia a esta tabla, lo que nos garantiza el aislamiento total entre organizaciones.

---

### Estructura general

La base de datos está organizada en seis bloques funcionales, cada uno agrupando las tablas relacionadas con una área específica del sistema:

| Bloque                          | Tablas principales                                                                      | Función                                        |
| ------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------- |
| 1 - Organización y usuarios     | `organizaciones`, `usuarios`, `sesiones_usuario`                                        | Gestión de cuentas y acceso al sistema         |
| 2 - Autenticación               | `tokens_verificacion_email`, `tokens_recuperacion_contrasena`                           | Flujos de verificación y recuperación          |
| 3 - Infraestructura y eventos   | `agentes`, `eventos`                                                                    | Recepción y almacenamiento de logs             |
| 4 - Detección y respuesta       | `reglas`, `alertas`, `alertas_eventos`, `respuestas_incidente`                          | Motor de detección y gestión de incidentes     |
| 5 - Inteligencia y cumplimiento | `inteligencia_amenazas`, `eventos_ioc`, `canales_notificacion`, `informes_cumplimiento` | IOCs, notificaciones e informes normativos     |
| 6 - Auditoría                   | `registros_auditoria`, `actividad_cliente`                                              | Trazabilidad de todas las acciones del sistema y registro de actividad visible para el cliente |

> *Tabla 1. Bloques funcionales de la base de datos y sus tablas principales.*

Además de las tablas, la base de datos incluye **funciones**, **procedimientos almacenados** y **triggers** que automatizan la lógica de negocio directamente en el motor de base de datos. Todo ello se detalla en las subpáginas siguientes.

---

### Tecnología utilizada

La base de datos se ha desarrollado e implementado utilizando **MySQL Workbench**, como herramienta de modelado visual, lo que nos ha permitido diseñar el esquema de entidad-relación de forma gráfica antes de generar el código SQL definitivo.

Para la gestión y las pruebas durante el desarrollo hemos utilizado también el cliente de línea de comandos de MySQL.

</details>

<details>
<summary>Tablas</summary>

# Tablas

### Introducción

A continuación describimos cada una de las tablas que componen la base de datos `cyntia`. Para facilitar la comprensión de las relaciones entre ellas, hemos creado un modelo entidad-relación en **MySQL Workbench** que mostramos al final de este apartado. Cada tabla se presenta con sus columnas, tipos de dato y la función que desempeña dentro del sistema.

***

### Bloque 1: organización y usuarios

Este bloque contiene las tres tablas que gestionan el acceso al sistema: las organizaciones clientes, sus usuarios y las sesiones activas de cada usuario.

#### Tabla organizaciones

Es la tabla raíz del sistema; todas las demás tablas dependen de ella directa o indirectamente a través de la clave foránea `org_id`.

<div align="center">

| Columna     | Tipo                              | Descripción                                                              |
| ----------- | --------------------------------- | ------------------------------------------------------------------------ |
| `id`        | `CHAR(36)`                        | Identificador único (UUID) de la organización                            |
| `nombre`    | `VARCHAR(255)`                    | Nombre de la organización                                                |
| `dominio`   | `VARCHAR(255)`                    | Dominio único de la organización                                         |
| `plan`      | `ENUM('core','pro','enterprise')` | Plan contratado, que determina los permisos de acceso a la base de datos |
| `activa`    | `TINYINT(1)`                      | Indica si la organización está activa (1) o desactivada (0)              |
| `creado_en` | `DATETIME`                        | Fecha y hora de creación del registro                                    |

</div>

> *Tabla 1.1. Estructura de la tabla `organizaciones`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2F1tu3drhe3H48EStylvKN%2Fimage.png?alt=media&#x26;token=25c75731-7276-43c1-99ca-09a5adffd0ea" alt=""><figcaption><p>Figura 1.1. Tabla organizaciones</p></figcaption></figure>
</div>

#### Tabla usuarios

Almacena las cuentas de acceso al sistema. Las contraseñas nunca se guardan en texto plano; siempre se almacena el hash resultante del proceso de cifrado realizado por la aplicación.

<div align="center">

| Columna               | Tipo                               | Descripción                                  |
| --------------------- | ---------------------------------- | -------------------------------------------- |
| `id`                  | `CHAR(36)`                         | Identificador único del usuario (UUID)       |
| `org_id`              | `CHAR(36)`                         | Clave foránea a `organizaciones`             |
| `email`               | `VARCHAR(255)`                     | Correo electrónico, único en todo el sistema |
| `hash_contrasena`     | `VARCHAR(255)`                     | Hash de la contraseña del usuario            |
| `nombre` / `apellido` | `VARCHAR(100)`                     | Nombre y apellido del usuario                |
| `rol`                 | `ENUM('admin','analyst','viewer')` | Rol del usuario dentro de su organización    |
| `activo`              | `TINYINT(1)`                       | Indica si la cuenta está activa              |
| `email_verificado`    | `TINYINT(1)`                       | Indica si el email ha sido verificado        |
| `ultimo_acceso`       | `DATETIME`                         | Fecha y hora del último inicio de sesión     |
| `creado_en`           | `DATETIME`                         | Fecha y hora de creación del registro        |

</div>

> *Tabla 1.2. Estructura de la tabla `usuarios`.*

Los roles disponibles tienen el siguiente alcance dentro del sistema:

* **`admin`**: acceso total de gestión sobre la organización.
* **`analyst`**: puede visualizar y gestionar alertas e incidentes.
* **`viewer`**: acceso de solo lectura a los datos permitidos.

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FH9mzUFMHWTnKsk9pHSxq%2Fimage.png?alt=media&#x26;token=1302c93d-ab77-4b94-896b-3b2c3922e53f" alt=""><figcaption><p>Figura 1.2. Tabla usuarios</p></figcaption></figure>
</div>

#### Tabla sesiones\_usuario

Registra cada sesión activa de un usuario, lo que permite invalidarlas de forma remota en caso de brecha de seguridad. La relación con `usuarios` usa `ON DELETE CASCADE`, de modo que si se elimina un usuario, sus sesiones se eliminan automáticamente.

<div align="center">

| Columna          | Tipo           | Descripción                                   |
| ---------------- | -------------- | --------------------------------------------- |
| `id`             | `CHAR(36)`     | Identificador único de la sesión              |
| `usuario_id`     | `CHAR(36)`     | Clave foránea a `usuarios`                    |
| `hash_token`     | `VARCHAR(255)` | Token de sesión hasheado                      |
| `direccion_ip`   | `VARCHAR(45)`  | Dirección IP desde la que se inició la sesión |
| `agente_usuario` | `VARCHAR(500)` | Cadena User-Agent del navegador o cliente     |
| `expira_en`      | `DATETIME`     | Fecha y hora de caducidad del token           |
| `creado_en`      | `DATETIME`     | Fecha y hora de creación de la sesión         |

</div>

> *Tabla 1.3. Estructura de la tabla `sesiones_usuario`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FD2KWNbrpW57hO3Njmf1E%2Fimage.png?alt=media&#x26;token=364dee8e-5a13-4e45-bb38-b79283988d4c" alt=""><figcaption><p>Figura 1.3. Tabla sesiones_usuario</p></figcaption></figure>
</div>

***

### Bloque 2: autenticación

Este bloque contiene las tablas que gestionan los flujos de verificación de correo electrónico y recuperación de contraseña, ambos basados en tokens de un solo uso con caducidad.

#### Tabla tokens\_verificacion\_email

Almacena el token que se envía al usuario por correo electrónico en el momento del registro, para confirmar que la dirección es válida.

<div align="center">

| Columna      | Tipo       | Descripción                                                 |
| ------------ | ---------- | ----------------------------------------------------------- |
| `id`         | `CHAR(36)` | Identificador único del token                               |
| `usuario_id` | `CHAR(36)` | Clave foránea a `usuarios`                                  |
| `token`      | `CHAR(36)` | Token único enviado por email                               |
| `expira_en`  | `DATETIME` | Fecha y hora de caducidad                                   |
| `usado_en`   | `DATETIME` | Fecha y hora en que se utilizó (NULL si aún no se ha usado) |
| `creado_en`  | `DATETIME` | Fecha y hora de generación del token                        |

</div>

> *Tabla 1.4. Estructura de la tabla `tokens_verificacion_email`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2F3kWcQdqqjVJuggMNUAJH%2Fimage.png?alt=media&#x26;token=faf02c43-ecab-4521-8b02-683a7d897ad6" alt=""><figcaption><p>Figura 1.4. Tabla tokens_verificacion_email</p></figcaption></figure>
</div>

#### Tabla tokens\_recuperacion\_contrasena

Tiene una estructura idéntica a la anterior, pero su finalidad es el flujo de restablecimiento de contraseña. Al igual que en el caso anterior, el token solo puede usarse una vez.

> *Tabla 1.5. Estructura de la tabla `tokens_recuperacion_contrasena` (idéntica a `tokens_verificacion_email`).*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FZLocPo8RB7UmyqOMeghH%2Fimage.png?alt=media&#x26;token=b0400706-f7cd-42f6-ab89-8aa76c13844a" alt=""><figcaption><p>Figura 1.5. Tabla tokens_recuperacion_contrasena</p></figcaption></figure>
</div>

***

### Bloque 3: infraestructura y eventos

Este bloque es el núcleo operativo del SIEM: registra los equipos monitorizados y todos los eventos de seguridad que generan.

#### Tabla agentes

Cada fila representa un endpoint (servidor, PC o máquina virtual) que tiene instalado el agente de Cyntia y que envía logs al sistema central.

<div align="center">

| Columna                  | Tipo                                 | Descripción                                          |
| ------------------------ | ------------------------------------ | ---------------------------------------------------- |
| `id`                     | `CHAR(36)`                           | Identificador único del agente                       |
| `org_id`                 | `CHAR(36)`                           | Organización a la que pertenece el agente            |
| `nombre_host`            | `VARCHAR(255)`                       | Nombre del equipo                                    |
| `direccion_ip`           | `VARCHAR(45)`                        | Dirección IP del agente                              |
| `tipo_so` / `version_so` | `VARCHAR`                            | Sistema operativo y versión del mismo                |
| `version_agente`         | `VARCHAR(50)`                        | Versión del software agente instalado                |
| `estado`                 | `ENUM('online','offline','warning')` | Estado actual de conexión                            |
| `ultima_conexion`        | `DATETIME`                           | Última vez que el agente envió un latido al servidor |
| `creado_en`              | `DATETIME`                           | Fecha de registro del agente en el sistema           |

</div>

> *Tabla 1.6. Estructura de la tabla `agentes`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FNHhynyCaPx8kUNE56Xz7%2Fimage.png?alt=media&#x26;token=d6975c45-6ffa-42b5-a8ee-b140220b3a7a" alt=""><figcaption><p>Figura 1.6. Tabla agentes</p></figcaption></figure>
</div>

#### Tabla eventos

Es la tabla principal del SIEM y, potencialmente, la de mayor volumen de datos. Almacena cada log normalizado recibido de los agentes. Para optimizar las consultas más frecuentes, se han definido tres índices sobre las columnas `hora_evento`, `severidad` y `tactica_mitre`.

<div align="center">

| Columna              | Tipo          | Descripción                                      |
| -------------------- | ------------- | ------------------------------------------------ |
| `id`                 | `CHAR(36)`    | Identificador único del evento                   |
| `agente_id`          | `CHAR(36)`    | Agente que generó el evento                      |
| `tipo_fuente`        | `VARCHAR(50)` | Origen del log (syslog, Windows Event Log, etc.) |
| `log_raw`            | `TEXT`        | Contenido original del log sin procesar          |
| `datos_normalizados` | `JSON`        | Campos extraídos y normalizados del log          |
| `tactica_mitre`      | `VARCHAR(10)` | Táctica MITRE ATT\&CK asociada (ej. `TA0006`)    |
| `tecnica_mitre`      | `VARCHAR(10)` | Técnica MITRE ATT\&CK asociada (ej. `T1110`)     |
| `severidad`          | `TINYINT`     | Nivel de severidad numérico del 1 al 10          |
| `hora_evento`        | `DATETIME`    | Momento en que ocurrió el evento                 |
| `ingestado_en`       | `DATETIME`    | Momento en que fue recibido por el servidor      |

</div>

> *Tabla 1.7. Estructura de la tabla `eventos`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FUlp2I23vJVnDE7R3xvja%2Fimage.png?alt=media&#x26;token=0cb518e5-6ff3-43a5-8823-f1229d710846" alt=""><figcaption><p>Figura 1.7. Tabla eventos</p></figcaption></figure>
</div>

***

### Bloque 4: detección y respuesta

Este bloque implementa el motor de detección de amenazas: define las reglas que disparan alertas, gestiona el ciclo de vida de cada alerta y registra las acciones de respuesta tomadas.

#### Tabla reglas

Contiene las reglas de detección del motor SIEM. Cuando un evento satisface la condición definida en `condicion_query`, el sistema genera una alerta automáticamente. Las reglas con `org_id` igual a `NULL` son globales y están disponibles para todas las organizaciones.

<div align="center">

| Columna                           | Tipo                                    | Descripción                                            |
| --------------------------------- | --------------------------------------- | ------------------------------------------------------ |
| `id`                              | `CHAR(36)`                              | Identificador único de la regla                        |
| `org_id`                          | `CHAR(36)`                              | Organización propietaria (`NULL` = global)             |
| `nombre`                          | `VARCHAR(255)`                          | Nombre descriptivo de la regla                         |
| `descripcion`                     | `TEXT`                                  | Explicación detallada de qué detecta la regla          |
| `condicion_query`                 | `TEXT`                                  | Expresión lógica que evalúa el motor sobre los eventos |
| `tactica_mitre` / `tecnica_mitre` | `VARCHAR(10)`                           | Mapeo al framework MITRE ATT\&CK                       |
| `severidad`                       | `ENUM('baja','media','alta','critica')` | Nivel de gravedad de la regla                          |
| `activa`                          | `TINYINT(1)`                            | Indica si la regla está en uso                         |
| `creado_en`                       | `DATETIME`                              | Fecha de creación de la regla                          |

</div>

> *Tabla 1.8. Estructura de la tabla `reglas`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2Fj0KTQmmq8eJzwUSWqvwU%2Fimage.png?alt=media&#x26;token=181052d4-92fe-4768-ba95-4c312e233bc2" alt=""><figcaption><p>Figura 1.8. Tabla reglas</p></figcaption></figure>
</div>

#### Tabla alertas

Registra cada alerta generada cuando un evento satisface una regla. El ciclo de vida de una alerta pasa por los estados `abierta` → `en_progreso` → `resuelta` (o `falso_positivo`). La asignación a un analista puede hacerse manualmente o de forma automática mediante el procedimiento `crear_alerta`.

<div align="center">

| Columna        | Tipo                                                        | Descripción                                      |
| -------------- | ----------------------------------------------------------- | ------------------------------------------------ |
| `id`           | `CHAR(36)`                                                  | Identificador único de la alerta                 |
| `regla_id`     | `CHAR(36)`                                                  | Regla que disparó la alerta                      |
| `org_id`       | `CHAR(36)`                                                  | Organización afectada                            |
| `asignado_a`   | `CHAR(36)`                                                  | Usuario analista responsable                     |
| `severidad`    | `ENUM`                                                      | Nivel de gravedad                                |
| `estado`       | `ENUM('abierta','en_progreso','resuelta','falso_positivo')` | Estado actual de la alerta                       |
| `titulo`       | `VARCHAR(255)`                                              | Título descriptivo de la alerta                  |
| `descripcion`  | `TEXT`                                                      | Descripción detallada                            |
| `contexto`     | `JSON`                                                      | Datos adicionales de contexto                    |
| `disparada_en` | `DATETIME`                                                  | Momento en que se generó la alerta               |
| `resuelta_en`  | `DATETIME`                                                  | Momento en que se cerró (gestionado por trigger) |

</div>

> *Tabla 1.9. Estructura de la tabla `alertas`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FWFN8oRQJQdXoeyTQ0XCc%2Fimage.png?alt=media&#x26;token=cf0cc424-42f0-4217-8a88-848dbacf0c02" alt=""><figcaption><p>Figura 1.9. Tabla alertas</p></figcaption></figure>
</div>

#### Tabla alertas\_eventos

Es una tabla puente de relación N:M que vincula una alerta con uno o varios eventos que la originaron. El campo `es_evento_principal` permite marcar el evento más relevante de entre todos los asociados.

> *Tabla 1.10. Estructura de la tabla `alertas_eventos` (tabla de unión N:M entre `alertas` y `eventos`).*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FLXp8kMR8gARr0A4n0L1Z%2Fimage.png?alt=media&#x26;token=8dc9abe0-78a8-4ae3-8af1-7cceda3544ac" alt=""><figcaption><p>Figura 1.10. Tabla alertas_eventos</p></figcaption></figure>
</div>

#### Tabla respuestas\_incidente

Registra las acciones tomadas ante una alerta, ya sean automáticas (ejecutadas por el motor) o manuales (realizadas por un analista). Los tipos de acción disponibles son: `bloquear_ip`, `aislar_host`, `notificar_email`, `notificar_slack` y `ejecutar_script`.

> *Tabla 1.11. Estructura de la tabla `respuestas_incidente`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2F48j0adtbcan6wNuDMZUR%2Fimage.png?alt=media&#x26;token=576084bf-7009-4c0e-ab7e-a3a2a2d9c38f" alt=""><figcaption><p>Figura 1.11. Tabla respuestas_incidente</p></figcaption></figure>
</div>

***

### Bloque 5: inteligencia y cumplimiento

Este bloque gestiona los indicadores de compromiso (IOC), los canales de notificación y la generación de informes normativos.

#### Tabla inteligencia\_amenazas

Almacena indicadores de compromiso (IOCs) obtenidos de fuentes externas como MISP o VirusTotal. Los tipos de IOC soportados son: `ip`, `dominio`, `hash_md5`, `hash_sha256`, `url` y `email`. El campo `confianza` indica en una escala del 0 al 100 la fiabilidad del indicador.

> *Tabla 1.12. Estructura de la tabla `inteligencia_amenazas`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2F8YHhRHmy2PycW3F2PtB0%2Fimage.png?alt=media&#x26;token=f71cb86b-0064-49e0-b1b9-9a0a56c259e8" alt=""><figcaption><p>Figura 1.12. Tabla inteligencia_amenazas</p></figcaption></figure>
</div>

#### Tabla eventos\_ioc

Tabla de unión N:M que registra qué IOCs han coincidido con qué eventos. El campo `campo_coincidencia` especifica en qué atributo del evento se ha encontrado la coincidencia.

*Tabla 1.13. Estructura de la tabla `eventos_ioc` (tabla de unión N:M entre `eventos` e `inteligencia_amenazas`).*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2F3zGnsAdBH1pFNnJ1zVNx%2Fimage.png?alt=media&#x26;token=70360cd2-a152-405d-94c2-6129576f9ccb" alt=""><figcaption><p>Figura 1.13. Tabla eventos_ioc</p></figcaption></figure>
</div>

#### Tabla canales\_notificacion

Almacena los canales de notificación configurados por cada organización. Los tipos disponibles son `email`, `slack`, `webhook` y `telegram`. La configuración específica de cada canal (tokens, URLs, destinatarios) se almacena en formato JSON en el campo `configuracion`.

> *Tabla 1.14. Estructura de la tabla `canales_notificacion`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FXXRCGxaE0wgz0HZMuDgt%2Fimage.png?alt=media&#x26;token=2d431729-35af-4488-bad5-8e0332ccf5c5" alt=""><figcaption><p>Figura 1.14. Tabla canales_notificacion</p></figcaption></figure>
</div>

#### Tabla informes\_cumplimiento

Registra los informes normativos generados por el sistema para cada organización. Los marcos normativos soportados son PCI-DSS, ISO 27001 y el Esquema Nacional de Seguridad (ENS). La ruta al fichero generado se guarda en `ruta_fichero` una vez completado el proceso.

> *Tabla 1.15. Estructura de la tabla `informes_cumplimiento`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FHcoJrQZEYBtKiZzNatlM%2Fimage.png?alt=media&#x26;token=1c2eab96-1d1b-41f5-90d7-2b1e351d82d3" alt=""><figcaption><p>Figura 1.15. Tabla informes_cumplimiento</p></figcaption></figure>
</div>

***

### Bloque 6: auditoría

Este bloque contiene la tabla de trazabilidad del sistema, diseñada para ser inmutable: ninguna acción realizada en Cyntia puede modificarse una vez registrada.

#### Tabla registros\_auditoria

Registra todas las acciones realizadas por los usuarios en el sistema. La tupla (`accion`, `tipo_entidad`, `entidad_id`) identifica qué se hizo y sobre qué objeto. El campo `cambios` almacena en JSON los valores anteriores y posteriores a la modificación.

<div align="center">

| Columna        | Tipo           | Descripción                                 |
| -------------- | -------------- | ------------------------------------------- |
| `id`           | `CHAR(36)`     | Identificador único del registro            |
| `usuario_id`   | `CHAR(36)`     | Usuario que realizó la acción               |
| `org_id`       | `CHAR(36)`     | Organización en la que ocurrió la acción    |
| `accion`       | `VARCHAR(100)` | Nombre de la acción realizada               |
| `tipo_entidad` | `VARCHAR(50)`  | Tipo de entidad afectada (p. ej., `alerta`) |
| `entidad_id`   | `CHAR(36)`     | Identificador de la entidad afectada        |
| `cambios`      | `JSON`         | Valores anteriores y nuevos                 |
| `direccion_ip` | `VARCHAR(45)`  | IP desde la que se realizó la acción        |
| `creado_en`    | `DATETIME`     | Fecha y hora del registro                   |

</div>

> *Tabla 1.16. Estructura de la tabla `registros_auditoria`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FthKhhVxI70kyGb2VImcD%2Fimage.png?alt=media&#x26;token=ebed5543-07c4-4b8d-ac22-ce6210a21cff" alt=""><figcaption><p>Figura 1.16. Tabla registros_auditoria</p></figcaption></figure>
</div>

#### Tabla actividad_cliente

Es la tabla que permite a los clientes conocer qué operaciones se han realizado en su organización. Se rellena automáticamente mediante el trigger `propagar_actividad_cliente` cada vez que se inserta un registro en `registros_auditoria`, descartando los campos sensibles.

<div align="center">

| Columna | Tipo | Descripción |
| :-- | :-- | :-- |
| `id` | `CHAR(36)` | Identificador único del registro |
| `org_id` | `CHAR(36)` | Organización a la que pertenece el registro |
| `accion` | `VARCHAR(100)` | Nombre de la operación realizada |
| `tipo_entidad` | `VARCHAR(50)` | Tipo de objeto afectado |
| `creado_en` | `DATETIME` | Fecha y hora del registro |

</div>

> *Tabla 1.17. Estructura de la tabla `actividad_cliente`.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2Fq6Xe968Jv2NH9dsNmWda%2Fimage.png?alt=media&#x26;token=c3fb8435-ce71-498c-b4b0-17583655fa9a" alt=""><figcaption><p>Figura 1.17. Tabla actividad_cliente</p></figcaption></figure>
</div>

***

### Modelo entidad-relación

Para visualizar de forma clara cómo se relacionan todas las tablas entre sí, hemos generado el modelo entidad-relación utilizando la herramienta **MySQL Workbench** (menú *Database → Reverse Engineer*). El modelo refleja todas las claves primarias, foráneas y las cardinalidades de las relaciones.

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FAmNcUswG6VzSx4G07Nr1%2Fmodelo.png?alt=media&#x26;token=6ae31f24-f1da-4652-b4f3-a88b442f6e64" alt=""><figcaption><p><em>Figura 1.1. Modelo entidad-relación de la base de datos generado con MySQL Workbench. Se pueden observar las seis áreas funcionales y las relaciones de clave foránea entre las tablas.</em></p></figcaption></figure>
</div>
</details>


<details>
  <summary>Consultas avanzadas</summary>

# Consultas avanzadas

### Introducción

Más allá de las operaciones CRUD básicas, la base de datos de Cyntia incorpora lógica de negocio directamente en el motor MySQL mediante tres elementos: **funciones** (`FUNCTION`), **procedimientos almacenados** (`PROCEDURE`) y **disparadores** (`TRIGGER`). Esta aproximación nos permite centralizar la lógica crítica del sistema en la propia base de datos, independientemente de la capa de aplicación que la consuma.

A continuación explicamos cada uno de estos elementos, su propósito y el código que los implementa.

***

### Funciones

Las funciones son rutinas que reciben parámetros, realizan un cálculo y devuelven un único valor. Las hemos marcado como `DETERMINISTIC` porque, dados los mismos parámetros de entrada, siempre producen el mismo resultado.

#### Función `agente_activo`

Esta función recibe el identificador de un agente y un número de minutos, y devuelve `1` (verdadero) si ese agente ha enviado un latido (*heartbeat*) al servidor en los últimos N minutos, o `0` (falso) en caso contrario. Es útil para detectar agentes que han dejado de comunicarse con el servidor central.

```sql
CREATE FUNCTION agente_activo(id_agente CHAR(36), minutos INT)
RETURNS TINYINT(1)
DETERMINISTIC
BEGIN
  DECLARE ultima DATETIME;
  SELECT ultima_conexion INTO ultima FROM agentes WHERE id = id_agente;
  RETURN ultima >= DATE_SUB(NOW(), INTERVAL minutos MINUTE);
END;
```

Un ejemplo de uso sería el siguiente, que devuelve todos los agentes junto con su estado y si han estado activos en los últimos 5 minutos:

```sql
SELECT nombre_host, estado, agente_activo(id, 5) AS activo_hace_5min
FROM agentes;
```

<div align="center">
<figure><picture><source srcset="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2F7GnHzDPttWOKAzz9aFtx%2FCaptura%20de%20pantalla%202026-04-07%20193155.png?alt=media&#x26;token=ebded9a3-05fd-4c79-8025-63c5aa6c7c26" media="(prefers-color-scheme: dark)"><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2F7GnHzDPttWOKAzz9aFtx%2FCaptura%20de%20pantalla%202026-04-07%20193155.png?alt=media&#x26;token=ebded9a3-05fd-4c79-8025-63c5aa6c7c26" alt=""></picture><figcaption><p><em>Figura 2.1. Resultado de la consulta que utiliza la función <code>agente_activo</code>, donde la columna <code>activo_hace_5min</code> indica si cada agente ha enviado un latido en los últimos cinco minutos.</em></p></figcaption></figure>
</div>

#### Función `contar_alertas_abiertas`

Recibe el identificador de una organización y devuelve el número entero de alertas que tienen el estado `abierta` en ese momento. Esta función permite, con una sola llamada, conocer la carga de trabajo pendiente de cada organización.

```sql
CREATE FUNCTION contar_alertas_abiertas(id_org CHAR(36))
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE total INT;
  SELECT COUNT(*) INTO total FROM alertas
  WHERE org_id = id_org AND estado = 'abierta';
  RETURN total;
END;
```

Podemos utilizarla para listar todas las organizaciones con su número de alertas pendientes:

```sql
SELECT nombre, contar_alertas_abiertas(id) AS alertas_abiertas
FROM organizaciones;
```

#### Función `nivel_riesgo`

Traduce la severidad numérica de un evento (de 1 a 10) a una cadena de texto descriptiva, según la siguiente escala:

<div align="center">

| Rango de severidad | Texto devuelto |
| ------------------ | -------------- |
| 1 – 3              | `Informativo`  |
| 4 – 5              | `Bajo`         |
| 6 – 7              | `Medio`        |
| 8 – 9              | `Alto`         |
| 10                 | `Critico`      |

</div>

> *Tabla 2.1. Correspondencia entre el valor numérico de severidad y el nivel de riesgo textual devuelto por la función `nivel_riesgo`.*

```sql
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
END;
```

***

### Procedimientos almacenados

Los procedimientos, a diferencia de las funciones, no devuelven un valor directamente sino que ejecutan una secuencia de operaciones, pudiendo utilizar parámetros de salida (`OUT`) para comunicar resultados al llamador.

#### Procedimiento `crear_alerta`

Este procedimiento centraliza la creación de nuevas alertas. Cuando se llama, realiza automáticamente dos operaciones:

1. Busca el analista activo de la organización que tiene menos alertas abiertas asignadas en ese momento, aplicando así un **balanceo de carga** entre el equipo de analistas.
2. Inserta la nueva alerta en la tabla `alertas` con todos los datos proporcionados y la asigna a ese analista.

El parámetro de salida `p_mensaje` devuelve una confirmación con el identificador del analista asignado.

```sql
CREATE PROCEDURE crear_alerta(
  IN p_regla_id   CHAR(36),
  IN p_org_id     CHAR(36),
  IN p_titulo     VARCHAR(255),
  IN p_severidad  ENUM('baja','media','alta','critica'),
  OUT p_mensaje   VARCHAR(100)
)
BEGIN
  DECLARE analista_id CHAR(36);
  DECLARE nuevo_id    CHAR(36);

  -- Busca el analista con menos carga de trabajo
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

  SET p_mensaje = CONCAT('Alerta creada y asignada al analista: ',
                         IFNULL(analista_id, 'sin asignar'));
END;
```

Un ejemplo de llamada al procedimiento para crear una alerta de fuerza bruta SSH sería:

```sql
CALL crear_alerta(
  (SELECT id FROM reglas WHERE nombre = 'Fuerza bruta SSH'),
  (SELECT id FROM organizaciones WHERE dominio = 'demo.cyntia.local'),
  'SSH Brute Force - 192.168.1.45 -> srv-main',
  'alta',
  @mensaje
);
SELECT @mensaje;
```

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FWSqEcW6jTSkRhWCg4UPx%2Fimage.png?alt=media&#x26;token=8ca028c1-959a-4919-94dd-8a53dd80bd52" alt=""><figcaption><p><em>Figura 2.2. Resultado de la llamada al procedimiento <code>crear_alerta</code>. El mensaje de salida confirma que la alerta ha sido registrada y muestra el identificador del analista al que ha sido asignada automáticamente.</em></p></figcaption></figure>
</div>

#### Procedimiento `limpiar_falsos_positivos`

Este procedimiento permite cerrar en bloque todas las alertas marcadas como `falso_positivo` de una organización, pasándolas al estado `resuelta` y registrando la fecha de cierre. El parámetro de salida indica cuántas alertas han sido procesadas.

```sql
CREATE PROCEDURE limpiar_falsos_positivos(
  IN  p_org_id  CHAR(36),
  OUT p_mensaje VARCHAR(100)
)
BEGIN
  DECLARE total INT;

  SELECT COUNT(*) INTO total FROM alertas
  WHERE org_id = p_org_id AND estado = 'falso_positivo';

  UPDATE alertas SET estado = 'resuelta', resuelta_en = NOW()
  WHERE org_id = p_org_id AND estado = 'falso_positivo';

  SET p_mensaje = CONCAT(total, ' alertas cerradas correctamente.');
END;
```

***

### Triggers

Los triggers son rutinas que se ejecutan automáticamente antes (`BEFORE`) o después (`AFTER`) de una operación de inserción, actualización o eliminación sobre una tabla. Hemos implementado tres triggers para automatizar tareas de auditoría y validación.

#### Trigger `auditoria_cambio_alerta`

Se ejecuta **después** de cada actualización sobre la tabla `alertas`. Si el campo `estado` ha cambiado, inserta automáticamente un registro en la tabla `registros_auditoria` con el estado anterior y el nuevo, usando `JSON_OBJECT` para estructurar los cambios.

```sql
CREATE TRIGGER auditoria_cambio_alerta
AFTER UPDATE ON alertas
FOR EACH ROW
BEGIN
  IF OLD.estado != NEW.estado THEN
    INSERT INTO registros_auditoria
      (id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
    VALUES (
      UUID(), NEW.org_id, 'cambio_estado_alerta', 'alerta', NEW.id,
      JSON_OBJECT('estado_anterior', OLD.estado, 'estado_nuevo', NEW.estado),
      NOW()
    );
  END IF;
END;
```

Este trigger garantiza que cualquier cambio en el ciclo de vida de una alerta quede registrado de forma inmutable en el log de auditoría, sin necesidad de que la aplicación lo haga explícitamente.

#### Trigger `validar_ip_agente`

Se ejecuta **antes** de insertar un nuevo agente. Comprueba si ya existe otro agente con la misma dirección IP dentro de la misma organización, y en ese caso lanza un error con `SIGNAL SQLSTATE '45000'`, impidiendo la inserción duplicada.

```sql
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
END;
```

#### Trigger `fecha_resolucion_alerta`

Se ejecuta **antes** de cada actualización sobre `alertas`. Si el nuevo estado es `resuelta` o `falso_positivo` y el campo `resuelta_en` todavía está a `NULL`, asigna automáticamente la fecha y hora actual a ese campo. Esto evita que la aplicación tenga que gestionar este detalle manualmente.

```sql
CREATE TRIGGER fecha_resolucion_alerta
BEFORE UPDATE ON alertas
FOR EACH ROW
BEGIN
  IF NEW.estado IN ('resuelta', 'falso_positivo') AND OLD.resuelta_en IS NULL THEN
    SET NEW.resuelta_en = NOW();
  END IF;
END;
```

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FuiVc0aN7l2fS2sJZ34Hk%2Fimage.png?alt=media&#x26;token=702ee090-e62c-49ce-a0dc-3716499ba3c5" alt=""><figcaption><p><em>Figura 2.3. Resumen de los tres triggers implementados en la base de datos Cyntia, indicando la tabla afectada, el momento de ejecución y la acción que los activa.</em></p></figcaption></figure>
</div>

</details>

<details>
<summary>Permisos de usuarios</summary>

# Permisos de usuario

### Introducción

La gestión del acceso a los datos es una parte fundamental de cualquier sistema de seguridad. En Cyntia hemos aplicado el principio de mínimo privilegio. Es decir, cada usuario de la base de datos solo puede ver y modificar exactamente aquello que su plan o rol le permite. Para ello hemos definido cuatro usuarios MySQL, uno por cada nivel de acceso del sistema, y hemos utilizado vistas (`VIEW`) como capa de abstracción que filtra los datos sensibles antes de que cada usuario los consulte.

***

### Tipos de usuario

Los cuatro usuarios creados en MySQL corresponden a los cuatro planes de suscripción de la plataforma Cyntia:

<div align="center">

| Usuario MySQL       | Plan       | Descripción general                                                                     |
| ------------------- | ---------- | --------------------------------------------------------------------------------------- |
| `cyntia_guest`      | Invitado   | Acceso mínimo de lectura; solo puede ver información básica y no sensible               |
| `cyntia_demo`       | Demo       | Acceso limitado pensado para entornos de prueba o evaluación                            |
| `cyntia_pro`        | Pro        | Acceso amplio a datos operativos; pensado para equipos de seguridad activos             |
| `cyntia_enterprise` | Enterprise | Acceso casi total, incluyendo escritura en alertas y respuestas, y lectura de auditoría |

</div>

> *Tabla 3.1. Resumen de los cuatro tipos de usuario de base de datos y el plan al que corresponden.*

La creación de los usuarios en MySQL se realiza de la siguiente manera:

```sql
CREATE USER 'cyntia_guest'@'%'      IDENTIFIED BY 'guest_pass';
CREATE USER 'cyntia_demo'@'%'       IDENTIFIED BY 'demo_pass';
CREATE USER 'cyntia_pro'@'%'        IDENTIFIED BY 'pro_pass';
CREATE USER 'cyntia_enterprise'@'%' IDENTIFIED BY 'enterprise_pass';
```

El modificador `'%'` indica que el usuario puede conectarse desde cualquier dirección IP.

***

### Vistas creadas por usuario

En lugar de otorgar acceso directo a las tablas base, hemos creado **vistas específicas** para cada nivel que exponen únicamente las columnas autorizadas. A continuación describimos cada una.

#### Vistas del usuario `cyntia_guest`

El usuario invitado solo tiene acceso a dos vistas muy limitadas, diseñadas para mostrar información de estado sin revelar ningún dato sensible.

**`vista_agentes_guest`** - muestra únicamente el nombre del host y su estado de conexión, sin exponer la IP ni el sistema operativo del equipo.

```sql
CREATE VIEW vista_agentes_guest AS
SELECT nombre_host, estado
FROM agentes;
```

**`vista_alertas_guest`** - muestra el identificador, el título, el nivel de severidad, el estado y la fecha de la alerta (truncada al día, sin hora exacta), ocultando la descripción, el contexto JSON y cualquier dato del analista asignado.

```sql
CREATE VIEW vista_alertas_guest AS
SELECT id, titulo, severidad, estado, DATE(disparada_en) AS fecha
FROM alertas;
```

#### Vistas del usuario `cyntia_demo`

El usuario de demo tiene acceso a versiones ligeramente más detalladas de las mismas vistas, pensadas para mostrar las capacidades del producto durante una evaluación.

**`vista_alertas_demo`** - incluye la hora exacta de disparo de la alerta (no solo la fecha), lo que permite apreciar la velocidad de detección del sistema.

```sql
CREATE VIEW vista_alertas_demo AS
SELECT id, titulo, severidad, estado, disparada_en
FROM alertas;
```

**`vista_agentes_demo`** - añade el tipo de sistema operativo respecto a la vista del nivel guest.

```sql
CREATE VIEW vista_agentes_demo AS
SELECT nombre_host, estado, tipo_so
FROM agentes;
```

#### Vistas del usuario `cyntia_pro`

El plan pro tiene acceso a datos completos de alertas y a una vista de eventos parcial que excluye el campo `log_raw`, que puede contener información sensible del sistema.

**`vista_eventos_pro`** - expone los metadatos del evento (identificador, agente, tipo de fuente, severidad y hora) pero no el contenido bruto del log.

```sql
CREATE VIEW vista_eventos_pro AS
SELECT id, agente_id, tipo_fuente, severidad, hora_evento
FROM eventos;
```

**`vista_alertas_pro`** - acceso completo a la tabla de alertas, equivalente a `SELECT *`.

```sql
CREATE VIEW vista_alertas_pro AS
SELECT * FROM alertas;
```

#### Vista del usuario `cyntia_enterprise`

**`vista_eventos_enterprise`** - acceso completo a la tabla de eventos, incluyendo el campo `log_raw` con el log original sin procesar y los `datos_normalizados` en JSON.

```sql
CREATE VIEW vista_eventos_enterprise AS
SELECT * FROM eventos;
```

***

### Concesión de permisos

Una vez creadas las vistas, asignamos los permisos con la instrucción `GRANT`. Mostramos a continuación los privilegios de cada usuario de forma ordenada.

#### Permisos de `cyntia_guest`

El usuario invitado solo puede hacer `SELECT` sobre sus dos vistas. No tiene acceso a ninguna tabla base.

```sql
GRANT SELECT ON cyntia.vista_agentes_guest TO 'cyntia_guest'@'%';
GRANT SELECT ON cyntia.vista_alertas_guest TO 'cyntia_guest'@'%';
```

#### Permisos de `cyntia_demo`

El usuario demo solo puede hacer `SELECT` sobre sus dos vistas.

```sql
GRANT SELECT ON cyntia.vista_alertas_demo TO 'cyntia_demo'@'%';
GRANT SELECT ON cyntia.vista_agentes_demo TO 'cyntia_demo'@'%';
```

#### Permisos de `cyntia_pro`

Además del acceso a sus vistas, el usuario pro tiene acceso de lectura directa sobre cuatro tablas base: `agentes`, `reglas`, `inteligencia_amenazas` y `respuestas_incidente`.

```sql
GRANT SELECT ON cyntia.vista_alertas_pro    TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.vista_eventos_pro    TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.agentes              TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.reglas               TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.inteligencia_amenazas TO 'cyntia_pro'@'%';
GRANT SELECT ON cyntia.respuestas_incidente TO 'cyntia_pro'@'%';
```

#### Permisos de `cyntia_enterprise`

El usuario enterprise dispone del nivel de acceso más elevado. Tiene permiso de `SELECT` sobre toda la base de datos (`cyntia.*`), permiso de `INSERT` y `UPDATE` sobre las tablas `alertas` y `respuestas_incidente`, y acceso de lectura a la tabla `actividad_cliente`.

```sql
-- Lectura de toda la base de datos
GRANT SELECT ON cyntia.* TO 'cyntia_enterprise'@'%';

-- Escritura en alertas y respuestas
GRANT INSERT, UPDATE ON cyntia.alertas              TO 'cyntia_enterprise'@'%';
GRANT INSERT, UPDATE ON cyntia.respuestas_incidente TO 'cyntia_enterprise'@'%';

-- Acceso al registro de actividad del cliente (sin datos sensibles internos)
GRANT SELECT ON cyntia.actividad_cliente TO 'cyntia_enterprise'@'%';
```

Finalmente, aplicamos los cambios de privilegios con:

```sql
FLUSH PRIVILEGES;
```

***

### Resumen comparativo de permisos

La siguiente tabla resume de forma visual qué puede hacer cada tipo de usuario con cada recurso de la base de datos.

<div align="center">

| Recurso                    |  guest |  demo  |   pro  |        enterprise        |
| -------------------------- | :----: | :----: | :----: | :----------------------: |
| `vista_agentes_guest`      | SELECT |    —   |    —   |          SELECT          |
| `vista_alertas_guest`      | SELECT |    —   |    —   |          SELECT          |
| `vista_agentes_demo`       |    —   | SELECT |    —   |          SELECT          |
| `vista_alertas_demo`       |    —   | SELECT |    —   |          SELECT          |
| `vista_eventos_pro`        |    —   |    —   | SELECT |          SELECT          |
| `vista_alertas_pro`        |    —   |    —   | SELECT |          SELECT          |
| `vista_eventos_enterprise` |    —   |    —   |    —   |          SELECT          |
| `agentes` (tabla base)     |    —   |    —   | SELECT |          SELECT          |
| `reglas`                   |    —   |    —   | SELECT |          SELECT          |
| `inteligencia_amenazas`    |    —   |    —   | SELECT |          SELECT          |
| `respuestas_incidente`     |    —   |    —   | SELECT | SELECT + INSERT + UPDATE |
| `alertas` (tabla base)     |    —   |    —   |    —   | SELECT + INSERT + UPDATE |
| `actividad_cliente`      |    —   |    —   |    —   |          SELECT          |

</div>

> *Tabla 3.2. Matriz de permisos por tipo de usuario. El símbolo «—» indica que el usuario no tiene acceso al recurso correspondiente.*

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FvSKGNK6nH1HoKigHdyj1%2Fimage.png?alt=media&#x26;token=f282e9af-8012-4c7c-9ed9-66998ff8a060" alt=""><figcaption><p><em>Figura 3.1. Resultado del comando <code>SHOW GRANTS</code> para el usuario <code>cyntia_pro</code>, que confirma que los privilegios han sido asignados correctamente según la política de mínimo privilegio definida.</em></p></figcaption></figure>
</div>

</details>

<details>
<summary>Auditorías</summary>

# Auditorías

En esta página describimos el diseño e implementación de las auditorías de la base de datos Cyntia mediante triggers de MySQL. Partiendo del análisis previo del modelo entidad-relación, identificamos las seis tablas que requieren cobertura de auditoría:&#x20;

* `usuarios`
* `agentes`
* `reglas`
* `informes_cumplimiento`
* `inteligencia_amenazas`
* `eventos`

Creamos un total de diecisiete triggers que registran automáticamente en `registros_auditoria` cada operación relevante de inserción, modificación o borrado. Entre las decisiones de diseño más destacadas se encuentran la protección del hash de contraseña en la tabla `usuarios`, el tratamiento de los eventos como registros inmutables y la cobertura de los indicadores de compromiso almacenados en `inteligencia_amenazas`. El resultado es una capa de trazabilidad que permite responder en todo momento a qué dato cambió y cuándo lo hizo.

Todo el código generado se encuentra en el fichero `auditorias.sql` .

***

## 1. Auditorías implementadas

Las seis tablas que requieren auditoría son las que aparecen agrupadas bajo rectángulos morados en el diagrama del proyecto. Para cada una detallamos qué triggers se han creado y el razonamiento detrás de cada decisión.

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FAmNcUswG6VzSx4G07Nr1%2Fmodelo.png?alt=media&#x26;token=6ae31f24-f1da-4652-b4f3-a88b442f6e64" alt=""><figcaption><p>Figura 4.1. Diagrama del proyecto con dichas tablas señaladas con un rectángulo morado</p></figcaption></figure>
</div>

### 1.1. Tabla usuarios

La gestión de cuentas de usuario es uno de los puntos más sensibles del sistema. Desde el punto de vista del cumplimiento normativo, el RGPD exige poder demostrar la evolución de los accesos y permisos a lo largo del tiempo (Parlamento Europeo y Consejo de la Unión Europea, 2016). Un alta no autorizada, un cambio de rol o una baja encubierta son situaciones que deben quedar documentadas sin excepción.

Hemos creado los triggers:

* `auditoria_usuario_insert`
* `auditoria_usuario_update`
* `auditoria_usuario_delete`

El que requirió más cuidado fue el de `UPDATE`, porque la tabla almacena el campo `hash_contrasena`. Escribir ese valor en `registros_auditoria` supondría un riesgo de seguridad grave, ya que comprometería las cuentas si alguien accediera sin autorización a la tabla de auditoría. Para resolverlo, el trigger detecta si el hash cambió y, de ser así, añade únicamente la clave `cambio_contrasena: true` al JSON, sin exponer el valor del campo.

```sql
-- Fragmento de auditoria_usuario_update
IF OLD.hash_contrasena != NEW.hash_contrasena THEN
  SET v_cambios = JSON_SET(v_cambios, '$.cambio_contrasena', TRUE);
END IF;
```

> *Fragmento de código 1. Detección del cambio de contraseña en el trigger de `usuarios`. La función `JSON_SET` inserta la nueva clave en el objeto JSON ya construido sin sobrescribir el resto de campos.*

### 1.2 Tabla agentes

Los agentes son los procesos instalados en los equipos monitorizados que envían telemetría a la plataforma. Controlar sus altas, modificaciones y bajas es esencial: si se elimina un agente sin autorización, el sistema deja de monitorizar ese equipo de forma silenciosa. Del mismo modo, un cambio no autorizado en la `direccion_ip` o en el campo `estado` podría indicar una reconfiguración maliciosa.

Hemos creado los triggers:

* `auditoria_agente_insert`
* `auditoria_agente_update`
* `auditoria_agente_delete`

El trigger `auditoria_agente_insert` es `AFTER INSERT` y no interfiere con el preexistente `validar_ip_agente`, que actúa en la fase `BEFORE INSERT` y solo realiza una comprobación de duplicados sin registrar nada en auditoría.

Por otro lado, en el trigger de `UPDATE` registramos los campos:

* `nombre_host`
* `direccion_ip`
* `estado`
* `version_so`

Estos son los más relevantes desde el punto de vista operativo y de seguridad.

```sql
DELIMITER //
CREATE TRIGGER auditoria_agente_update
AFTER UPDATE ON agentes
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(), @usuario_actual, NEW.org_id, 'modificar_agente', 'agente', NEW.id,
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
```

> *Fragmento de código 2. Trigger `auditoria_agente_update`. El patrón de claves `_anterior` / `_nuevo` permite comparar el estado del registro antes y después de la operación sin necesidad de consultas adicionales.*

### 1.3 Tabla reglas

Las reglas definen qué condiciones deben cumplir los eventos para generar una alerta. Una modificación no autorizada, como desactivar una regla o alterar su condición de detección, podría permitir que ataques reales pasen desapercibidos, comprometiendo toda la utilidad de la plataforma.

Hemos creado los triggers:

* `auditoria_regla_insert`
* `auditoria_regla_update`
* `auditoria_regla_delete`

En el trigger de `UPDATE` incluimos el campo `condicion_query` a pesar de ser de tipo `TEXT` y potencialmente extenso, porque es el campo más crítico de la tabla: cualquier alteración en la lógica de detección debe quedar documentada con el máximo detalle posible. También registramos los campos de clasificación MITRE ATT\&CK (`tactica_mitre` y `tecnica_mitre`), ya que su modificación implicaría un cambio en la categorización de las amenazas detectadas.

### 1.4 Tabla informes\_cumplimiento

Los informes de cumplimiento documentan el estado de seguridad de una organización durante un período determinado y pueden tener valor legal o contractual. Si un informe desapareciera o fuera modificado sin dejar rastro, sería imposible demostrar su existencia o integridad ante una auditoría externa.

Hemos creado los triggers:

* `auditoria_informe_insert`
* `auditoria_informe_update`
* `auditoria_informe_delete`

El trigger de `UPDATE` registra específicamente los cambios en el campo `estado` y en `ruta_fichero`, que son los únicos que deberían modificarse legítimamente una vez generado el informe.

### 1.5 Tabla inteligencia\_amenazas

Esta tabla almacena indicadores de compromiso (IoC, del inglés *Indicators of Compromise*): valores como direcciones IP maliciosas, dominios sospechosos o hashes de ficheros conocidos como dañinos. La integridad de estos datos es crítica, ya que el sistema los utiliza para correlacionar eventos y generar alertas. Una modificación o borrado no autorizado de un IoC podría hacer que amenazas conocidas no fueran detectadas.

Hemos creado los triggers:

* `auditoria_inteligencia_insert`
* `auditoria_inteligencia_update`
* `auditoria_inteligencia_delete`

En el trigger de `UPDATE` prestamos especial atención al campo `valor`, que contiene el propio indicador de compromiso. También al campo `confianza`, cuya alteración cambiaría el peso que el sistema asigna a ese indicador.

```sql
DELIMITER //
CREATE TRIGGER auditoria_inteligencia_update
AFTER UPDATE ON inteligencia_amenazas
FOR EACH ROW
BEGIN
  INSERT INTO registros_auditoria
    (id, usuario_id, org_id, accion, tipo_entidad, entidad_id, cambios, creado_en)
  VALUES (
    UUID(), @usuario_actual, NEW.org_id, 'modificar_inteligencia', 'inteligencia_amenazas', NEW.id,
    JSON_OBJECT(
      'tipo_ioc_anterior',     OLD.tipo_ioc,     'tipo_ioc_nuevo',     NEW.tipo_ioc,
      'valor_anterior',        OLD.valor,        'valor_nuevo',        NEW.valor,
      'confianza_anterior',    OLD.confianza,    'confianza_nueva',    NEW.confianza,
      'fuente_anterior',       OLD.fuente,       'fuente_nueva',       NEW.fuente,
      'valido_hasta_anterior', OLD.valido_hasta, 'valido_hasta_nueva', NEW.valido_hasta
    ),
    NOW()
  );
END //
DELIMITER ;
```

> *Fragmento de código 3. Trigger `auditoria_inteligencia_update`. Se registran los campos operativamente más relevantes del indicador de compromiso, incluyendo su fecha de validez y el usuario de sesión responsable del cambio.*

### 1.6 Tabla eventos

Los eventos una vez ingestados no deberían modificarse, ya que cualquier alteración comprometería su integridad como evidencia en un posible análisis forense. Por este motivo no hemos creado un trigger de `UPDATE` para esta tabla.

Sí hemos creado:

* `auditoria_evento_insert`
* `auditoria_evento_delete`

Este último es especialmente relevante: en un SIEM, el borrado de eventos podría ser indicio de manipulación de evidencias y debería permitir rastrear exactamente qué se eliminó y cuándo.

Dado que la tabla `eventos` no contiene directamente el campo `org_id`, lo obtenemos mediante subconsulta a la tabla `agentes`. Añadimos `LIMIT 1` como salvaguarda ante posibles inconsistencias de datos.

```sql
DECLARE v_org_id CHAR(36);
SELECT org_id INTO v_org_id FROM agentes WHERE id = NEW.agente_id LIMIT 1;
```

> *Fragmento de código 4. Resolución del `org_id` en el trigger de `eventos`. Como la tabla no dispone de ese campo, se obtiene a través de la relación con `agentes`.*

Una vez ejecutado el script, conviene verificar que los triggers se han registrado correctamente y que generan entradas coherentes en `registros_auditoria`.

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2FJul7UrkrQMQAqXuNZthQ%2Fimage.png?alt=media&#x26;token=2bbd98f8-aedf-43b2-8a00-6cc33bee4bf4" alt=""><figcaption><p><em>Figura 2. Registros generados en <code>registros_auditoria</code> tras operaciones de prueba. El campo <code>cambios</code> almacena en formato JSON los valores anteriores y nuevos de cada campo modificado.</em></p></figcaption></figure>
</div>

<div align="center">
<figure><img src="https://2869191102-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FJ3HzhRDH8YbQSO5p2xjr%2Fuploads%2Fh21egtqCTgUuPsjryiUr%2Fimage.png?alt=media&#x26;token=817020b4-a266-4737-8e1d-0b462ed918b6" alt=""><figcaption><p><em>Figura 3. Triggers de auditoría visibles en el panel de navegación bajo la tabla <code>usuarios</code>.</em></p></figcaption></figure>
</div>

***

### 2. Revisión y mejoras del script

Durante la revisión del código identificamos un aspecto que requerían corrección. Ninguno de los cambios altera el comportamiento de los triggers existentes.

#### 2.2 Separación entre auditoría interna y actividad de cliente

La tabla `registros_auditoria` contiene información que no debe exponerse a los clientes: el identificador del operador interno, la dirección IP desde la que actuó y el JSON completo con todos los cambios. Sin embargo, tiene sentido que un cliente pueda consultar qué tipo de operaciones se han realizado en su organización y cuándo.

Para resolver esto sin modificar ningún trigger existente, hemos añadido dos objetos nuevos al final del archivo.

El primero es la tabla `actividad_cliente`, que almacena únicamente los campos no sensibles: 
* `org_id`
* `accion`
* `tipo_entidad`
* `creado_en`

El segundo es el trigger `propagar_actividad_cliente`, que se dispara automáticamente después de cada inserción en `registros_auditoria` y copia esos cuatro campos a la nueva tabla, ignorando los registros sin `org_id` asignado:

```sql
DELIMITER //
CREATE TRIGGER propagar_actividad_cliente
AFTER INSERT ON registros_auditoria
FOR EACH ROW
BEGIN
    IF NEW.org_id IS NOT NULL THEN
        INSERT INTO actividad_cliente (id, org_id, accion, tipo_entidad, creado_en)
        VALUES (UUID(), NEW.org_id, NEW.accion, NEW.tipo_entidad, NEW.creado_en);
    END IF;
END //
DELIMITER ;
```

> *Fragmento de código 5. Trigger `propagar_actividad_cliente`. La condición `IF NEW.org_id IS NOT NULL` filtra los registros de auditoría interna que no están asociados a ninguna organización de cliente.*

***

## Conclusiones

Hemos creado diecisiete triggers de auditoría distribuidos en las seis tablas que el modelo entidad-relación del proyecto identifica como críticas. Las decisiones de diseño más relevantes que tomamos son las siguientes:

* Todos los triggers de borrado son `BEFORE DELETE` para poder capturar los valores de `OLD` antes de que desaparezcan de la base de datos.
* El hash de contraseña no se almacena nunca en la auditoría de `usuarios`; en su lugar se registra únicamente un indicador booleano de que el campo fue modificado.
* No existe trigger de `UPDATE` para `eventos`, ya que los registros de telemetría son inmutables y su modificación comprometería la integridad forense.
* El `org_id` de `eventos` se resuelve mediante subconsulta a `agentes`, al no estar disponible directamente en esa tabla.
* Todos los triggers leen la variable de sesión `@usuario_actual` para rellenar el campo `usuario_id`, con `NULL` como valor por defecto si la variable no está definida.
* La tabla `registros_auditoria` es de uso exclusivo interno, es decir, los clientes acceden a la actividad de su organización a través de `actividad_cliente`, que se rellena automáticamente mediante el trigger `propagar_actividad_cliente` sin modificar ninguno de los diecisiete triggers originales.

</details>
