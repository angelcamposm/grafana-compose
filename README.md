# Docker Compose Project Skeleton

Plantilla base (*skeleton*) genérica y limpia para iniciar nuevos proyectos con **Docker Compose** siguiendo la Compose Specification moderna, buenas prácticas de seguridad, gestión multi-entorno y validación automática en CI.

No incluye servicios de ejemplo activos: parte de un `services: {}` limpio con extensiones reutilizables (`x-*`), redes segmentadas y overlays listos para desarrollo y producción.

## Estructura del proyecto

```text
.
├── .github/
│   └── workflows/
│       └── ci.yaml          # Validación automática (yamllint, docker compose config y Makefile)
├── config/                  # Archivos de configuración montados como solo lectura (:ro)
├── docker/                  # Dockerfiles y entrypoints de imágenes personalizadas
├── scripts/                 # Scripts auxiliares (backups, inicialización, migraciones)
├── .dockerignore            # Exclusiones para contextos de build limpios y seguros
├── .editorconfig            # Formato unificado (UTF-8, LF, tabs en Makefile)
├── .env.example             # Plantilla documentada de variables de entorno
├── .gitattributes           # Normalización de finales de línea LF para Linux/Windows
├── .gitignore               # Exclusión de secretos, .env y datos locales
├── .yamllint.yaml           # Reglas de linting para archivos YAML
├── compose.override.yaml    # Overlay de desarrollo (cargado automáticamente por docker compose)
├── compose.prod.yaml        # Overlay explícito de producción
├── compose.yaml             # Definición base: anclas x-*, servicios, redes y volúmenes
├── LICENSE.md               # Licencia MIT
└── Makefile                 # Comandos estándar para operar y validar el stack
```

## Requisitos previos

- **Docker Engine** y **Docker Compose v2** (`docker compose`)
- **GNU Make** (opcional; en Windows disponible mediante WSL o Git Bash)
- **yamllint** (opcional para ejecutar linting YAML en local)

## Inicio rápido (Quickstart)

1. **Crea tu nuevo proyecto** a partir de este skeleton y genera tu archivo `.env`:
   ```bash
   make init
   ```
   *(Sin `make`: `cp .env.example .env`)*

2. **Edita `.env`** y establece al menos `COMPOSE_PROJECT_NAME` con el nombre de tu proyecto.

3. **Añade tus servicios en `compose.yaml`** reutilizando las anclas `x-*`:
   ```yaml
   services:
     api:
       <<: *default-service
       image: mi-org/mi-api:1.2.3
       deploy:
         resources: *default-resources
       healthcheck:
         <<: *default-healthcheck
         test: ["CMD", "curl", "-fsS", "http://localhost:8080/health"]
       networks:
         - frontend
         - backend
   ```

4. **Valida la configuración** antes de levantar contenedores:
   ```bash
   make validate
   ```

5. **Levanta el stack**:
   - En **desarrollo** (`compose.yaml` + `compose.override.yaml`):
     ```bash
     make up
     ```
   - En **producción** (`compose.yaml` + `compose.prod.yaml`):
     ```bash
     make up ENV=prod
     ```

## Comandos del `Makefile`

Ejecuta `make` o `make help` para ver todos los targets disponibles. Todos los comandos operativos admiten `ENV=dev|prod` (por defecto `dev`), `ENV_FILE=<ruta>` (por defecto `.env`) y `SERVICE=<nombre>` cuando aplica.

| Comando | Descripción |
| --- | --- |
| `make help` | Muestra la ayuda y los targets disponibles |
| `make init` | Crea `.env` desde `.env.example` si no existe |
| `make up` | Levanta el stack en segundo plano (`--remove-orphans`) |
| `make up-build` | Construye imágenes y levanta el stack |
| `make down` | Detiene y elimina contenedores y redes |
| `make restart` | Reinicia todos los servicios o el indicado en `SERVICE` |
| `make pull` | Descarga las últimas imágenes configuradas |
| `make ps` | Muestra el estado y los healthchecks de los contenedores |
| `make logs` | Sigue los logs en tiempo real (`-f --tail=100`) |
| `make config` | Imprime la configuración Compose resuelta para el entorno activo |
| `make validate` | Valida `compose.yaml`, dev y prod con `docker compose config --quiet` |
| `make lint` | Ejecuta `yamllint` (si está instalado) y `validate` |
| `make clean` | Detiene y elimina contenedores, redes **y volúmenes** (`down -v`) |

### Comandos equivalentes sin `make`

```bash
# Validar base, desarrollo y producción
docker compose --env-file .env.example -f compose.yaml config --quiet
docker compose --env-file .env.example -f compose.yaml -f compose.override.yaml config --quiet
docker compose --env-file .env.example -f compose.yaml -f compose.prod.yaml config --quiet

# Levantar en desarrollo (carga compose.override.yaml automáticamente)
docker compose up -d --remove-orphans

# Levantar en producción (omite compose.override.yaml)
docker compose -f compose.yaml -f compose.prod.yaml up -d --remove-orphans
```

## Gestión de entornos

- **`compose.yaml`**: define la base común a todos los entornos (anclas `x-*`, servicios, redes y volúmenes).
- **`compose.override.yaml`**: ajustes exclusivos de desarrollo local (puertos ligados a `127.0.0.1`, bind mounts de código fuente, `build:` local, `restart: "no"`). Docker Compose lo fusiona automáticamente cuando no se pasan flags `-f`.
- **`compose.prod.yaml`**: ajustes de producción (`restart: always`, `read_only: true`, `tmpfs`, políticas de despliegue). Al invocar `-f compose.yaml -f compose.prod.yaml`, `compose.override.yaml` no se aplica.
- **`.env`**: configuración local fuera de Git. Mantén siempre `.env.example` sincronizado sin credenciales reales.

> **Nota sobre anclas YAML:** las anclas (`&...` / `*...`) solo son válidas dentro del mismo archivo YAML. Por ello cada overlay (`compose.override.yaml` y `compose.prod.yaml`) declara sus propias anclas de conveniencia.

## Convenciones y buenas prácticas incluidas

- **Sin `version:` obsoleto:** utiliza la Compose Specification moderna con `name:` parametrizado por `COMPOSE_PROJECT_NAME`.
- **Endurecimiento de seguridad (`*default-security`):** aplica `no-new-privileges:true` y `cap_drop: [ALL]` por defecto. Añade capacidades específicas con `cap_add` solo cuando un servicio lo requiera estrictamente.
- **Rotación de logs (`*default-logging`):** driver `json-file` con `max-size` y `max-file` acotados para evitar llenar el disco del host.
- **Gestión limpia de procesos:** `init: true` y `stop_grace_period: 30s` en `*default-service`.
- **Límites de recursos (`*default-resources`):** plantilla de `limits` y `reservations` configurables desde `.env`.
- **Healthchecks (`*default-healthcheck`):** tiempos base reutilizables para orquestar dependencias con `depends_on` y `condition: service_healthy`.
- **Segmentación de redes:**
  - `frontend`: red bridge para servicios expuestos o con salida externa.
  - `backend`: red bridge marcada con `internal: true` para aislar bases de datos, colas y servicios internos.
- **Etiquetas de imagen fijas:** evita `:latest`; fija versiones explícitas o digests SHA-256.
- **Configuraciones en solo lectura:** monta archivos desde `config/` con `:ro` (por ejemplo, `./config/app.conf:/etc/app/app.conf:ro`).
- **Finales de línea `LF`:** garantizados mediante `.editorconfig` y `.gitattributes` para evitar errores al trabajar desde Windows.

## Validación y CI

El workflow [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml) se ejecuta automáticamente en cada `push` a `main` y en cada `pull_request`, verificando:

1. Estilo y sintaxis YAML con `yamllint` (`.yamllint.yaml`).
2. Validez de `compose.yaml`, del overlay de desarrollo y del overlay de producción con `docker compose config --quiet`.
3. Sintaxis y targets principales del `Makefile`.

## Licencia

Distribuido bajo la licencia MIT. Consulta [LICENSE.md](LICENSE.md) para más detalles.
