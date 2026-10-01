# Sistema IAS con Docker Compose

Este proyecto levanta PostgreSQL, el backend Java y el frontend Angular con Nginx. Docker descarga los dos repositorios desde GitHub y construye sus imágenes; no necesitas clonar los proyectos hermanos ni instalar Java, Gradle, Node.js o npm en tu equipo.

## Iniciar

Requisitos: Docker Desktop iniciado con contenedores Linux, Docker Compose 2.30 o posterior y conexión a Internet para descargar el código, las imágenes y las dependencias.

Desde la carpeta `compose-sistema-IAS`:

```powershell
docker compose up -d
```

La construcción ocurre antes del arranque y puede tardar varios minutos la primera vez. Compose espera a que PostgreSQL esté saludable para iniciar el backend, y a que el backend esté saludable para iniciar el frontend. Con `-d`, el comando puede terminar antes de que el frontend pase su propia comprobación de salud.

Consulta el estado:

```powershell
docker compose ps
```

Cuando los tres servicios estén `healthy`, abre manualmente **http://localhost:4201**. Si necesitas que el comando espere hasta que todos estén saludables, puedes usar:

```powershell
docker compose up -d --wait --wait-timeout 180
```

El tiempo de espera corresponde al arranque, después de la construcción de las imágenes.

## Direcciones y puertos

| Servicio | Dirección desde el equipo | Dirección dentro de la red de Compose |
|---|---|---|
| Frontend | `http://localhost:4201` | `http://frontend:80` |
| Backend | `http://localhost:8080` | `http://backend:8080` |
| Swagger | `http://localhost:8080/swagger-ui.html` | — |
| Salud de la API | `http://localhost:8080/actuator/health` | `http://backend:8080/actuator/health` |
| PostgreSQL | `localhost:5432` | `postgres:5432` |

Los puertos publicados se enlazan a `127.0.0.1`. El frontend utiliza `4201` para coexistir con el servidor Angular de desarrollo que utiliza `4200`.

El navegador llama a `/api/...` en el mismo origen del frontend. Nginx elimina el prefijo `/api` y reenvía la petición al backend. Por ejemplo:

```text
http://localhost:4201/api/applications
                  ↓
http://backend:8080/applications
                  ↓
postgres:5432
```

No se necesita configurar CORS para estas llamadas desde el frontend.

## Configuración central: `.env`

Compose lee el `.env` de esta carpeta para interpolar `compose.yaml`. La sección `environment` de cada servicio pasa sus variables al contenedor explícitamente.

Si ya tienes un `.env`, conserva las credenciales existentes. Para una instalación nueva, crea el archivo a partir del ejemplo antes del primer arranque:

```powershell
Copy-Item .env.example .env
```

| Variable | Uso |
|---|---|
| `POSTGRES_DB` | Nombre de la base; actualmente `DATABAE_IAS`. |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | Credenciales de administración e inicialización de PostgreSQL. |
| `APP_DB_USER` / `APP_DB_PASSWORD` | Credenciales del usuario de aplicación, utilizadas por el backend y la comprobación de salud de la BD. |
| `POSTGRES_PORT` | Puerto publicado de PostgreSQL; por defecto `5432`. |
| `BACKEND_PORT` | Puerto publicado del backend; por defecto `8080`. |
| `FRONTEND_PORT` | Puerto publicado del frontend; por defecto `4201`. |
| `BACKEND_REF` | Rama, etiqueta o commit completo del backend; por defecto `main`. |
| `FRONTEND_REF` | Rama, etiqueta o commit completo del frontend; por defecto `main`. |

El backend recibe:

```text
DB_URL=r2dbc:postgresql://postgres:5432/<POSTGRES_DB>
DB_USER=<APP_DB_USER>
DB_PASSWORD=<APP_DB_PASSWORD>
SERVER_PORT=8080
```

El frontend recibe únicamente la configuración del proxy:

```text
BACKEND_URL=http://backend:8080
NGINX_ENVSUBST_FILTER=BACKEND_URL
```

Cambiar un puerto publicado no cambia el puerto interno. Por ejemplo, con `BACKEND_PORT=8081`, el navegador y Postman acceden a `localhost:8081`, pero Nginx sigue usando `backend:8080`.

Los `.env` locales de `back-IAS` y `front-IAS` no participan en este despliegue. Los repositorios los excluyen de Git y del contexto de sus imágenes. Las credenciales se proporcionan en tiempo de ejecución, no al compilar Angular o Java.

Cambiar las contraseñas en `.env` no modifica automáticamente los usuarios de una base ya inicializada. Para una base existente, sincroniza también las credenciales en PostgreSQL antes de recrear los servicios afectados.

## Descarga y actualización del código

Los contextos de construcción son:

```text
https://github.com/jdug-jadodev/back-IAS.git#<BACKEND_REF>
https://github.com/jdug-jadodev/front-IAS.git#<FRONTEND_REF>
```

Ambos repositorios son públicos. Docker BuildKit obtiene el código y utiliza el Dockerfile de cada repositorio. Las carpetas locales `../back-IAS` y `../front-IAS` no se montan ni se modifican; los cambios locales sin publicar no aparecen en los contenedores.

`pull_policy: build` solicita construir ambas imágenes al ejecutar `docker compose up -d`. BuildKit resuelve la referencia de Git y reutiliza la caché para las partes que no cambiaron. Con `main`, se toma el código publicado en esa rama en el momento de construir. Para fijar una versión reproducible, configura un commit completo en cada variable `*_REF`.

Después de publicar cambios en las referencias configuradas, ejecuta de nuevo:

```powershell
docker compose up -d
```

Compose recrea los contenedores cuyas imágenes o configuración cambiaron. Las dependencias tienen `restart: true` para reiniciar los servicios dependientes cuando Compose actualiza su dependencia, incluido Nginx cuando se reemplaza el backend.

Estas construcciones compilan el código de producción. No ejecutan las suites de pruebas de los repositorios.

## Base de datos y persistencia

Los datos se almacenan en el volumen `postgres_data`. Los scripts de `db/init` se ejecutan automáticamente cuando PostgreSQL inicializa un volumen vacío.

El esquema requerido por el backend incluye `idempotency_key`, `next_application_reference()` y `credit_applications_reference_seq`. La comprobación de salud de PostgreSQL verifica el acceso del usuario de aplicación a las tablas y a la secuencia de referencias antes de iniciar el backend.

Editar `db/init` no aplica cambios sobre un volumen ya inicializado. Para una base anterior, aplica las migraciones necesarias conservando sus datos. El arranque no elimina ni reinicializa el volumen.

## Comprobaciones y diagnóstico

```powershell
docker compose ps
docker compose logs --tail 100 backend frontend
Invoke-RestMethod http://localhost:8080/actuator/health
Invoke-RestMethod http://localhost:4201/api/actuator/health
Invoke-RestMethod 'http://localhost:4201/api/applications?page=0&size=20'
```

Las dos comprobaciones de salud HTTP deben devolver `status: UP`. La consulta de solicitudes comprueba el recorrido navegador → Nginx → backend → PostgreSQL sin crear registros.

Si un puerto publicado está ocupado, cambia su variable en `.env` y ejecuta de nuevo `docker compose up -d`. Si falla una construcción, revisa su salida: GitHub, los registros de imágenes y los repositorios de dependencias deben ser accesibles desde Docker Desktop.

Las dependencias de salud ordenan el arranque inicial; no detienen automáticamente todos los servicios si una dependencia pasa a estar no saludable más tarde. Los healthchecks permiten detectar esa situación y `restart: unless-stopped` reinicia los procesos que terminan inesperadamente.

## Detener

```powershell
docker compose down
```

Este comando elimina los contenedores y la red del proyecto, conservando el volumen de PostgreSQL. Puedes volver a levantar el sistema con `docker compose up -d`.
