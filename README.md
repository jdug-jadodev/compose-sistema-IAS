# Sistema IAS · Docker Compose

Entorno local para ejecutar el sistema de solicitudes de crédito completo: **PostgreSQL + backend Java + frontend Angular**.

Solo necesitas clonar **este repositorio** y configurar su `.env` una vez. Docker descarga el código del backend y del frontend desde GitHub, compila las aplicaciones y levanta los tres servicios.

## Contenido

- [Requisitos](#requisitos)
- [Primera instalación](#primera-instalación)
- [Arranques posteriores](#arranques-posteriores)
- [Direcciones de acceso](#direcciones-de-acceso)
- [Cómo funciona](#cómo-funciona)
  - [Arquitectura interna de Compose](#arquitectura-interna-de-compose)
  - [Flujo de construcción y arranque](#flujo-de-construcción-y-arranque)
  - [Recorrido de una petición](#recorrido-de-una-petición)
- [Variables de entorno](#variables-de-entorno)
  - [Distribución de la configuración](#distribución-de-la-configuración)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Base de datos y persistencia](#base-de-datos-y-persistencia)
- [Actualizar el sistema](#actualizar-el-sistema)
- [Comandos útiles](#comandos-útiles)
- [Problemas frecuentes](#problemas-frecuentes)

## Requisitos

- **Git**, para clonar este repositorio.
- **Docker Desktop** iniciado, configurado para utilizar contenedores Linux; o Docker Engine en Linux.
- **Docker Compose 2.30 o posterior**, disponible con `docker compose`.
- Conexión a Internet para obtener los repositorios, las imágenes y las dependencias durante la construcción.
- Puertos **5432**, **8080** y **4201** disponibles en el equipo. Se pueden cambiar en `.env`.

Java, Gradle, Node.js y npm se ejecutan dentro de las imágenes de construcción; no necesitas instalarlos en tu equipo.

Puedes comprobar Docker y Compose con:

```powershell
docker info
docker compose version
```

## Primera instalación

### 1. Clonar este repositorio

```powershell
git clone https://github.com/jdug-jadodev/compose-sistema-IAS.git
cd compose-sistema-IAS
```

No necesitas clonar manualmente `back-IAS` ni `front-IAS`.

### 2. Crear el archivo de configuración

En **Windows / PowerShell**:

```powershell
Copy-Item .env.example .env
```

En **Linux / macOS**:

```bash
cp .env.example .env
```

Este comando crea un `.env` con el mismo contenido que la plantilla. Hazlo solo en una instalación nueva, cuando todavía no tengas tu propio `.env`.

La plantilla incluye valores para levantar el entorno local. Puedes editar `.env` antes de arrancar para elegir las credenciales o cambiar los puertos.

### 3. Levantar todo

Desde la raíz de este repositorio:

```powershell
docker compose up -d
```

Docker se encarga de:

1. Obtener los repositorios del backend y del frontend desde GitHub.
2. Construir sus imágenes utilizando los Dockerfile de esos proyectos.
3. Iniciar PostgreSQL y, si el volumen está vacío, crear las tablas, los clientes de ejemplo y el usuario de aplicación.
4. Esperar a que PostgreSQL esté saludable e iniciar el backend.
5. Esperar a que el backend esté saludable e iniciar el frontend.

La primera construcción puede tardar varios minutos. Las siguientes aprovechan la caché de Docker.

### 4. Comprobar el estado y abrir la aplicación

```powershell
docker compose ps
```

Espera a que `postgres`, `backend` y `frontend` aparezcan como **`healthy`**. Después abre manualmente:

**[http://localhost:4201](http://localhost:4201)**

`-d` deja los servicios ejecutándose en segundo plano. Si prefieres que el comando también espere a que los tres estén saludables, utiliza:

```powershell
docker compose up -d --wait --wait-timeout 180
```

## Arranques posteriores

Con Docker iniciado y el `.env` ya creado, solo necesitas ejecutar:

```powershell
docker compose up -d
```

Las configuraciones y los datos de PostgreSQL se conservan. No vuelvas a copiar la plantilla sobre tu `.env` existente.

## Direcciones de acceso

Valores predeterminados de `.env.example`:

| Recurso | Dirección |
|---|---|
| Frontend | [http://localhost:4201](http://localhost:4201) |
| Backend / API | `http://localhost:8080` |
| Swagger | [http://localhost:8080/swagger-ui.html](http://localhost:8080/swagger-ui.html) |
| Salud del backend | `http://localhost:8080/actuator/health` |
| Salud del backend a través de Nginx | `http://localhost:4201/api/actuator/health` |
| PostgreSQL | Host `127.0.0.1`, puerto `5432` |

Los puertos se publican en `127.0.0.1`, para acceder desde el equipo donde corre Docker. El frontend utiliza **4201** para poder coexistir con un servidor Angular de desarrollo en **4200**.

## Cómo funciona

### Componentes

| Servicio de Compose | Tecnología | Origen |
|---|---|---|
| `postgres` | PostgreSQL 17 | Imagen `postgres:17-bookworm` y scripts locales de `db/init`. |
| `backend` | Java 21, Spring Boot y R2DBC | [back-IAS](https://github.com/jdug-jadodev/back-IAS). |
| `frontend` | Angular, servido por Nginx | [front-IAS](https://github.com/jdug-jadodev/front-IAS). |

Las URLs de GitHub se utilizan directamente como contextos de construcción de Docker. El código se obtiene dentro del proceso de construcción; no se crean copias de esos proyectos en las carpetas de tu equipo.

Los siguientes diagramas utilizan **Mermaid** y se visualizan directamente en GitHub. Los componentes del despliegue son tres servicios de Compose; toda la API del sistema reside en el backend Java.

### Arquitectura interna de Compose

Compose crea la red `creditos-local_default`, conecta los tres contenedores y publica sus puertos hacia el equipo anfitrión.

```mermaid
flowchart TB
    subgraph HOST["Equipo anfitrión"]
        BROWSER["Navegador<br/>Angular se ejecuta aquí"]
        API_CLIENT["Swagger / Postman"]
        DB_CLIENT["DBeaver / pgAdmin"]
        INIT["Carpeta db/init"]
        CHECKS["Carpeta db/checks"]
    end

    subgraph DOCKER["Docker · Proyecto creditos-local"]
        subgraph NETWORK["Red interna: creditos-local_default"]
            subgraph FRONT_CONTAINER["Contenedor: frontend"]
                NGINX["Nginx :80<br/>Sirve HTML, CSS y JavaScript de Angular<br/>Proxy de /api hacia el backend"]
            end
            subgraph BACK_CONTAINER["Contenedor: backend"]
                API["Spring Boot :8080<br/>API y reglas de crédito"]
                R2DBC["Spring Data R2DBC<br/>Acceso reactivo a PostgreSQL"]
            end
            subgraph DB_CONTAINER["Contenedor: postgres"]
                DB[("PostgreSQL :5432<br/>Base: DATABAE_IAS<br/>customers y credit_applications")]
                INIT_PATH["/docker-entrypoint-initdb.d"]
                CHECKS_PATH["/opt/creditos-checks"]
            end
        end
        DATA[("Volumen: creditos-local_postgres_data<br/>Montado en /var/lib/postgresql/data")]
    end

    BROWSER <-->|"127.0.0.1:4201 → frontend:80"| NGINX
    API_CLIENT <-->|"127.0.0.1:8080 → backend:8080"| API
    DB_CLIENT <-->|"127.0.0.1:5432 → postgres:5432"| DB
    NGINX <-->|"HTTP · http://backend:8080<br/>Quita el prefijo /api"| API
    API <--> R2DBC
    R2DBC <-->|"R2DBC · postgres:5432<br/>Usuario de aplicación: ias"| DB
    DB <-->|"Lectura y escritura persistente"| DATA
    INIT -.->|"Bind mount de solo lectura"| INIT_PATH
    CHECKS -.->|"Bind mount de solo lectura"| CHECKS_PATH
    INIT_PATH -.->|"Inicialización en un volumen vacío"| DB

    classDef service fill:#dbeafe,stroke:#2563eb,color:#172554;
    classDef database fill:#ede9fe,stroke:#7c3aed,color:#2e1065;
    classDef host fill:#fef3c7,stroke:#d97706,color:#78350f;
    class NGINX,API,R2DBC service;
    class DB,DATA database;
    class BROWSER,API_CLIENT,DB_CLIENT,INIT,CHECKS host;
```

Las flechas continuas representan comunicación o acceso a datos; las discontinuas muestran los montajes y la inicialización. Los puertos del diagrama corresponden a los valores predeterminados de `.env.example`.

Dentro de la red, `backend` y `postgres` se resuelven mediante el DNS de Docker. Los contenedores se comunican usando sus **puertos internos**, aunque cambies los puertos publicados en `.env`.

### Flujo de construcción y arranque

Este es el recorrido de `docker compose up -d`, desde la configuración local hasta la disponibilidad del sistema:

```mermaid
flowchart TD
    START["docker compose up -d"] --> CONFIG["Leer compose.yaml y .env"]
    CONFIG --> BUILD["Solicitar construcción<br/>pull_policy: build · caché de BuildKit"]

    BUILD --> BACK_SOURCE["GitHub: back-IAS<br/>Referencia BACKEND_REF"]
    BUILD --> FRONT_SOURCE["GitHub: front-IAS<br/>Referencia FRONTEND_REF"]
    BACK_SOURCE --> BACK_BUILD["Dockerfile del backend<br/>JDK 21 + Gradle → bootJar"]
    FRONT_SOURCE --> FRONT_BUILD["Dockerfile del frontend<br/>Node.js + npm ci → ng build"]
    BACK_BUILD --> BACK_IMAGE["Imagen de ejecución<br/>JRE 21 + aplicación Java"]
    FRONT_BUILD --> FRONT_IMAGE["Imagen de ejecución<br/>Nginx + archivos compilados de Angular"]
    BACK_IMAGE --> INFRA["Preparar red, volumen y contenedores"]
    FRONT_IMAGE --> INFRA

    INFRA --> PG_START["Iniciar PostgreSQL"]
    PG_START --> EMPTY{"¿El volumen está vacío?"}
    EMPTY -->|"Sí"| INIT_DB["Ejecutar db/init en orden<br/>Esquema → clientes → usuario y permisos"]
    EMPTY -->|"No"| EXISTING_DB["Utilizar la base y los datos existentes"]
    INIT_DB --> PG_HEALTH{"¿PostgreSQL está healthy?"}
    EXISTING_DB --> PG_HEALTH

    PG_HEALTH -->|"Sí"| BACK_START["Iniciar backend<br/>depends_on: postgres healthy"]
    PG_HEALTH -->|"No, tras los reintentos"| ERROR["Arranque incompleto<br/>Revisar docker compose logs"]
    BACK_START --> BACK_HEALTH{"¿Backend está healthy?"}
    BACK_HEALTH -->|"Sí"| FRONT_START["Iniciar frontend<br/>depends_on: backend healthy"]
    BACK_HEALTH -->|"No, tras los reintentos"| ERROR
    FRONT_START --> FRONT_HEALTH{"¿Frontend está healthy?"}
    FRONT_HEALTH -->|"Sí"| READY["Sistema disponible<br/>Abrir http://localhost:4201"]
    FRONT_HEALTH -->|"No, tras los reintentos"| ERROR

    classDef process fill:#dbeafe,stroke:#2563eb,color:#172554;
    classDef decision fill:#fef3c7,stroke:#d97706,color:#78350f;
    classDef success fill:#dcfce7,stroke:#16a34a,color:#14532d;
    classDef failure fill:#fee2e2,stroke:#dc2626,color:#7f1d1d;
    class CONFIG,BUILD,BACK_SOURCE,FRONT_SOURCE,BACK_BUILD,FRONT_BUILD,BACK_IMAGE,FRONT_IMAGE,INFRA,PG_START,INIT_DB,EXISTING_DB,BACK_START,FRONT_START process;
    class EMPTY,PG_HEALTH,BACK_HEALTH,FRONT_HEALTH decision;
    class READY success;
    class ERROR failure;
```

Las dos construcciones convergen antes del arranque; Docker puede ejecutar sus pasos secuencialmente o en paralelo. Los compiladores se utilizan durante la construcción y las imágenes finales contienen los componentes necesarios para ejecutar las aplicaciones.

Compose espera las dependencias saludables antes de iniciar cada aplicación. Con `up -d`, puede devolver el control una vez iniciado el frontend, mientras su healthcheck sigue comprobando la disponibilidad. Usa `--wait` para esperar también ese resultado.

### Recorrido de una petición

El ejemplo muestra cómo la interfaz consulta el historial y recibe datos reales de PostgreSQL:

```mermaid
sequenceDiagram
    actor Usuario
    participant Browser as Navegador / Angular
    participant Front as frontend / Nginx :80
    participant Back as backend / Spring Boot :8080
    participant Postgres as postgres / PostgreSQL :5432

    Usuario->>Browser: Abrir http://localhost:4201
    Browser->>Front: GET / por el puerto publicado 4201
    Front-->>Browser: HTML, CSS y JavaScript de Angular
    Note over Browser: Angular se inicia en el navegador

    Browser->>Front: GET /api/applications?page=0&size=20
    Note over Front: Quita /api y utiliza BACKEND_URL
    Front->>Back: GET http://backend:8080/applications?page=0&size=20
    Back->>Postgres: Consultar historial mediante R2DBC
    Postgres-->>Back: Filas y total de solicitudes
    Back-->>Front: HTTP 200 + JSON paginado
    Front-->>Browser: HTTP 200 + JSON paginado
    Browser-->>Usuario: Mostrar el historial de solicitudes
```

Para registrar una solicitud se utiliza el mismo recorrido con `POST /api/applications`: el backend evalúa los datos y registra el resultado en PostgreSQL antes de responder a la interfaz.

La interfaz y la API se consumen desde el mismo origen del navegador, por lo que este recorrido no necesita configurar CORS.

### Comprobaciones de salud

- **PostgreSQL:** verifica la conexión del usuario de aplicación y el acceso al esquema requerido.
- **Backend:** consulta `/actuator/health`.
- **Frontend:** comprueba tanto la página principal como el acceso a la salud del backend a través de Nginx.

Estas comprobaciones ordenan el arranque mediante `depends_on`. Si una dependencia deja de estar saludable después, Compose no detiene automáticamente los demás servicios. La política `restart: unless-stopped` reinicia los contenedores cuyos procesos terminan inesperadamente.

## Variables de entorno

### `.env.example` y `.env`

| Archivo | ¿Está en GitHub? | Función |
|---|---|---|
| `.env.example` | Sí | Plantilla con nombres de variables y valores de ejemplo para el entorno local. |
| `.env` | No; está excluido por `.gitignore`. | Configuración de tu instalación. |

Copiar `.env.example` a `.env` no recupera contraseñas de otra instalación: genera una configuración nueva a partir de los valores de la plantilla.

En una base nueva, PostgreSQL configura las credenciales indicadas y el script crea el usuario de aplicación. Compose entrega esas mismas credenciales al backend para que pueda conectarse.

### Variables disponibles

| Variable | Valor de la plantilla | Uso |
|---|---|---|
| `POSTGRES_DB` | `DATABAE_IAS` | Nombre de la base de datos; utiliza este nombre exactamente como aparece. |
| `POSTGRES_USER` | `postgres` | Usuario administrador de PostgreSQL. |
| `POSTGRES_PASSWORD` | `local-postgres-password` | Contraseña del administrador en una instalación nueva. |
| `APP_DB_USER` | `ias` | Usuario utilizado por el backend. |
| `APP_DB_PASSWORD` | `local-ias-password` | Contraseña del usuario de aplicación en una instalación nueva. |
| `POSTGRES_PORT` | `5432` | Puerto de PostgreSQL publicado en el equipo. |
| `BACKEND_PORT` | `8080` | Puerto del backend publicado en el equipo. |
| `FRONTEND_PORT` | `4201` | Puerto del frontend publicado en el equipo. |
| `BACKEND_REF` | `main` | Rama, etiqueta o commit completo del backend que Docker construirá. |
| `FRONTEND_REF` | `main` | Rama, etiqueta o commit completo del frontend que Docker construirá. |

### Configuración que recibe cada servicio

El backend recibe `DB_URL`, `DB_USER`, `DB_PASSWORD` y `SERVER_PORT`. La URL utiliza `postgres:5432` y las credenciales se toman de `APP_DB_USER` y `APP_DB_PASSWORD`.

El frontend recibe `BACKEND_URL=http://backend:8080` y `NGINX_ENVSUBST_FILTER=BACKEND_URL` para configurar el proxy de Nginx. No recibe las contraseñas de la base de datos.

Los `.env` de los repositorios del backend y frontend no participan en este despliegue. La configuración se centraliza aquí y se pasa explícitamente a cada contenedor.

### Distribución de la configuración

```mermaid
flowchart LR
    EXAMPLE[".env.example<br/>Plantilla incluida en GitHub"]
    ENV[".env<br/>Configuración local"]
    COMPOSE["Docker Compose<br/>Interpreta compose.yaml"]
    BUILD["Construcción desde GitHub<br/>BACKEND_REF y FRONTEND_REF"]
    PG["postgres<br/>POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD<br/>APP_DB_USER y APP_DB_PASSWORD"]
    BACK["backend<br/>DB_URL = postgres:5432 + POSTGRES_DB<br/>DB_USER = APP_DB_USER<br/>DB_PASSWORD = APP_DB_PASSWORD<br/>SERVER_PORT = 8080"]
    FRONT["frontend / Nginx<br/>BACKEND_URL = http://backend:8080<br/>NGINX_ENVSUBST_FILTER = BACKEND_URL"]
    PORTS["Puertos publicados en 127.0.0.1<br/>POSTGRES_PORT → 5432<br/>BACKEND_PORT → 8080<br/>FRONTEND_PORT → 80"]

    EXAMPLE -->|"Copiar una vez"| ENV
    ENV -->|"Variables para interpolar"| COMPOSE
    COMPOSE -->|"Contextos de construcción"| BUILD
    COMPOSE -->|"environment"| PG
    COMPOSE -->|"environment"| BACK
    COMPOSE -->|"environment"| FRONT
    COMPOSE -->|"ports"| PORTS

    classDef config fill:#fef3c7,stroke:#d97706,color:#78350f;
    classDef service fill:#dbeafe,stroke:#2563eb,color:#172554;
    class EXAMPLE,ENV,COMPOSE config;
    class BUILD,PG,BACK,FRONT,PORTS service;
```

Las variables de las referencias Git se usan al construir las imágenes. Las credenciales y la dirección del proxy se inyectan al ejecutar los contenedores. En una base nueva, los scripts crean el usuario con las mismas credenciales que recibirá el backend.

### Cambiar puertos

Si un puerto está ocupado, cambia su valor en `.env`, por ejemplo:

```dotenv
BACKEND_PORT=8081
FRONTEND_PORT=4202
```

Aplica la configuración con:

```powershell
docker compose up -d
```

En ese ejemplo accederías a la API en `http://localhost:8081` y a la interfaz en `http://localhost:4202`. Los puertos internos permanecen en `8080` y `80`; la comunicación entre servicios sigue funcionando.

## Estructura del repositorio

```text
compose-sistema-IAS/
├── README.md                       # Instalación, funcionamiento y estructura
├── SISTEMA_DOCKER.md                # Detalles técnicos de la integración
├── compose.yaml                    # Servicios, construcción, red y persistencia
├── .env.example                    # Plantilla de configuración compartida
├── .env                            # Configuración local; se crea al instalar
├── .gitignore                      # Excluye .env del control de versiones
└── db/
    ├── init/
    │   ├── 01_create_schema.sql     # Tablas, restricciones y referencias automáticas
    │   ├── 02_seed_customers.sql    # Clientes de ejemplo
    │   └── 03_create_app_user.sh    # Usuario de aplicación y permisos
    └── checks/
        └── .gitkeep                # Conserva esta carpeta en los clones de Git
```

`db/init` se monta en `/docker-entrypoint-initdb.d` dentro de PostgreSQL. En un volumen vacío, la imagen ejecuta los scripts en orden por nombre.

`db/checks` se monta en `/opt/creditos-checks`. Es una carpeta reservada para scripts de comprobación; actualmente no contiene comprobaciones ejecutables. `.gitkeep` permite incluirla en Git, ya que Compose exige que exista al montar el directorio.

Las aplicaciones se mantienen en sus propios repositorios. Este repositorio contiene su orquestación y la inicialización de PostgreSQL.

## Base de datos y persistencia

El esquema contiene:

- **`customers`:** clientes, estado y límite de aprobación.
- **`credit_applications`:** solicitudes procesadas, resultado, motivo de rechazo e información de idempotencia.
- Una secuencia y una función para generar referencias como `REF-001`.

En una instalación nueva se cargan estos clientes:

| Cliente | Estado | Límite de aprobación |
|---|---|---:|
| `CLI-1001` | `ELIGIBLE` | 10.000.000 |
| `CLI-1002` | `BLOCKED` | 8.000.000 |
| `CLI-2001` | `ELIGIBLE` | 15.000.000 |

Los datos se guardan en el volumen `postgres_data` del proyecto. `docker compose down` conserva ese volumen y los registros estarán disponibles al volver a levantar el sistema.

Los scripts de inicialización se ejecutan **solo cuando el volumen está vacío**. Editar `db/init` o actualizar el repositorio no aplica automáticamente cambios sobre una base existente; esos cambios requieren una migración.

Del mismo modo, modificar las contraseñas en `.env` no cambia las contraseñas de los usuarios ya creados en PostgreSQL. En una instalación existente, las credenciales del archivo y de la base deben mantenerse sincronizadas.

### Consultar la base con una interfaz gráfica

Puedes utilizar DBeaver o pgAdmin instalado en tu equipo:

| Campo | Valor |
|---|---|
| Host | `127.0.0.1` |
| Puerto | Valor de `POSTGRES_PORT` |
| Base de datos | Valor de `POSTGRES_DB` |
| Usuario | Valor de `POSTGRES_USER` o `APP_DB_USER` |
| Contraseña | La contraseña correspondiente en `.env` |

Las tablas están en el esquema `public`. El usuario de aplicación tiene los permisos necesarios para el backend: consulta de clientes, actualización de `customers.status`, consulta e inserción de solicitudes y acceso a las secuencias.

## Actualizar el sistema

Para descargar cambios de este repositorio y levantar el sistema actualizado:

```powershell
git pull
docker compose up -d
```

Los servicios del backend y frontend tienen `pull_policy: build`: cada `up` solicita construir sus imágenes a partir de las referencias configuradas y reutiliza la caché de las partes que no cambiaron.

Con `BACKEND_REF=main` y `FRONTEND_REF=main`, se toma el código publicado en esas ramas en el momento de construir. Los cambios de tus carpetas locales de desarrollo deben publicarse en la referencia correspondiente para aparecer en este despliegue.

Para fijar una versión concreta, configura una etiqueta o el hash completo de un commit en cada variable `*_REF` antes de ejecutar `up`.

El sistema conserva los datos de PostgreSQL al actualizar las aplicaciones. Si una nueva versión necesita cambios de esquema, aplica también sus migraciones.

## Comandos útiles

Ejecuta los comandos desde la raíz del repositorio.

| Acción | Comando |
|---|---|
| Levantar el sistema | `docker compose up -d` |
| Levantar y esperar a que esté saludable | `docker compose up -d --wait --wait-timeout 180` |
| Ver el estado | `docker compose ps` |
| Ver los últimos logs | `docker compose logs --tail 100` |
| Seguir los logs de las aplicaciones | `docker compose logs -f backend frontend` |
| Detener los contenedores | `docker compose stop` |
| Detener y eliminar contenedores y red, conservando los datos | `docker compose down` |
| Validar la configuración de Compose | `docker compose config --quiet` |

Para comprobar la conexión completa desde **PowerShell**:

```powershell
Invoke-RestMethod http://localhost:8080/actuator/health
Invoke-RestMethod http://localhost:4201/api/actuator/health
Invoke-RestMethod 'http://localhost:4201/api/applications?page=0&size=20'
```

Los dos primeros comandos deben devolver `status: UP`. El tercero consulta el historial a través de Nginx, el backend y PostgreSQL; en una instalación nueva, el historial estará vacío hasta registrar solicitudes.

## Problemas frecuentes

| Situación | Qué revisar |
|---|---|
| Docker no responde o indica que no puede conectar con el daemon. | Inicia Docker Desktop y comprueba `docker info`. |
| Hay variables vacías o la configuración no se resuelve. | Comprueba que `.env` exista en la raíz y tenga las variables de `.env.example`. |
| Un puerto está ocupado. | Cambia `POSTGRES_PORT`, `BACKEND_PORT` o `FRONTEND_PORT` en `.env` y ejecuta de nuevo `docker compose up -d`. |
| La primera ejecución tarda. | Está descargando y compilando los proyectos; espera a que termine la construcción. |
| Falla la descarga o la construcción. | Revisa la salida del comando y la conexión de Docker con GitHub, los registros de imágenes y los repositorios de dependencias. |
| PostgreSQL aparece como `unhealthy`. | Consulta `docker compose logs --tail 100 postgres`; revisa las credenciales, el esquema y los permisos de la base existente. |
| El backend aparece como `unhealthy`. | Consulta `docker compose logs --tail 100 backend` y comprueba el estado de PostgreSQL. |
| El frontend no abre o devuelve un error de proxy. | Comprueba `docker compose ps`, los logs de `frontend` y la salud del backend. |
| Cambiaste `db/init`, pero la base sigue igual. | El volumen ya estaba inicializado; aplica los cambios mediante una migración. |

Para más detalles sobre la construcción, las variables y el ciclo de vida de los servicios, consulta [SISTEMA_DOCKER.md](SISTEMA_DOCKER.md).
