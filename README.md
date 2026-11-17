# Docker environment for Phoenix CTMS

Try Phoenix CTMS in minutes with Docker Compose — no VirtualBox/.ova and no on-host Maven build.

This replaces the older Tomcat 8 / Postgres 12 evaluation compose with a current stack:

| Service | Image / role |
|---------|----------------|
| `db` | PostgreSQL 17 |
| `redis` | Redis 7, Signup sessions only (starts when `PHOENIX_SIGNUP` is true) |
| `db-migrate` | Applies schema once |
| `ctsms` | Tomcat 10 + prebuilt Phoenix WAR + Perl bulk-processor (UI jobs). Container name `ctsms` |
| `db-init` | Loads master data and creates the `phoenix` login |
| `signup` | Signup Dancer app (starts when `PHOENIX_SIGNUP` is true) |

For production single-host Debian installs, keep using [`phoenixctms/install-debian`](https://github.com/phoenixctms/install-debian) / the OVA.

## Requirements

- Docker Engine (Linux) or Docker Desktop (Windows/macOS)
- On Windows, [WSL2](https://learn.microsoft.com/windows/wsl/install). Docker Desktop runs on it. The bash installer runs inside WSL; the PowerShell installer runs in Windows and uses that same WSL2 backend.
- About 6–8 GB RAM recommended
- Port `8888` free on localhost (override with `PHOENIX_CTSMS_HTTP_PORT`; bind address with `PHOENIX_CTSMS_BIND_ADDRESS`)
- Port `3000` free for Signup (override with `PHOENIX_SIGNUP_HTTP_PORT`). Set `PHOENIX_SIGNUP=false` to skip Signup and Redis.

## Quick start (prebuilt images)

No git checkout. The installer downloads this repository and starts the published images. On Windows, install WSL2 first.

Linux, macOS, or the default WSL distro. A fresh Debian WSL has no `curl`; the command installs it with your sudo password, then runs the installer:

```bash
if ! command -v curl >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y curl ca-certificates; fi && curl -fsSL https://raw.githubusercontent.com/phoenixctms/docker/master/install.sh | bash
```

The installer runs as that user. If the Docker socket refuses the user, it adds them to the `docker` group and continues.

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/phoenixctms/docker/master/install.ps1 | iex
```

Files land in `~/phoenixctms` (`%USERPROFILE%\phoenixctms` on Windows). Set `PHOENIX_HOME` to use another directory. An existing `.env` in that directory is left in place.

When init finishes it prints the credential tail, then the Signup URL:

```text
Phoenix CTMS initial setup complete.
URL: http://localhost:8888
Username: phoenix
Password: ...
Department passphrase (my_department): ...
Cron user password (my_department_cron): ...
Signup service user (en): my_department_signup_en / my_department_signup_en
Signup service user (de): my_department_signup_de / my_department_signup_de
Signup service user (es): my_department_signup_es / my_department_signup_es
Init finished. Credentials written to /credentials/login.txt
Signup: http://localhost:3000
```

Open http://localhost:8888 and log in. The same text is stored in the `credentials` volume (`/credentials/login.txt` inside `db-init` / `ctsms`). Signup is omitted when `PHOENIX_SIGNUP=false`.

Optional demo data (set on **first** start; enabling it later does not re-import because init runs once per data volumes):

```bash
PHOENIX_DEMO_DATA=true docker compose up -d
```

To re-init from scratch after changing init options: `docker compose --profile signup down -v` then start again. `--profile signup` also removes the Signup and Redis volumes when that profile is not active in `.env`.

From that directory later:

```bash
docker compose pull
docker compose up -d --no-build db redis db-migrate ctsms
docker compose up -d --no-build --no-deps db-init
init_id="$(docker compose ps -aq db-init | head -n 1)"
docker wait "$init_id" >/dev/null
docker logs "$init_id" 2>&1 | sed -n '/Phoenix CTMS initial setup complete\./,$p'
docker compose up -d --no-build signup
```

## Build locally

The installer downloads the Dockerfiles too, so this works in the install directory without git:

`docker compose up -d` waits for `db-init` and does not show its log. Build, then start the dependencies, wait, and print the credential tail:

```bash
docker compose build
docker compose up -d db redis db-migrate ctsms
docker compose up -d --no-deps db-init
init_id="$(docker compose ps -aq db-init | head -n 1)"
docker wait "$init_id" >/dev/null
docker logs "$init_id" 2>&1 | sed -n '/Phoenix CTMS initial setup complete\./,$p'
docker compose up -d signup
```

Build args (optional):

```bash
PHOENIX_CTSMS_TAG=master PHOENIX_CONFIG_TAG=master PHOENIX_MASTER_DATA_TAG=master PHOENIX_BULK_TAG=master docker compose build
```

## Useful commands

```bash
# Follow the Java service logs
docker compose logs -f ctsms

# Stop (keep data)
docker compose down

# Reset everything (DB + uploads + credentials, including Signup)
docker compose --profile signup down -v
```

## Perl jobs (ECRF export, etc.)

UI/JobService Perl jobs run **inside the `ctsms` container** (same as install-debian): `/ctsms/bulk_processor/...`. No extra Compose profile is required for that.

## Signup

UI Perl jobs do not need Signup. Signup is the long-running Dancer app, started by default with Redis.

Open http://localhost:3000 (or `PHOENIX_SIGNUP_HTTP_PORT`). There is no browser password. The start page is a site picker: choose My Department, then continue to the proband step.

Set `PHOENIX_SIGNUP=false` and remove the `COMPOSE_PROFILES=signup` line from `.env` to leave Signup and Redis stopped. The installer keeps that line matched to `PHOENIX_SIGNUP`.

Signup calls the ctsms REST API as `my_department_signup_en`, `my_department_signup_de`, and `my_department_signup_es` (password equals the username). `config.cfg` in the container is pointed at Redis and `my_department_cron`. The cron password is the random value `db-init` writes to `/credentials/login.txt`. Signup waits until that init has finished.

## Environment variables

See [`.env.example`](.env.example). Important ones:

| Variable | Default | Meaning |
|----------|---------|---------|
| `PHOENIX_CTSMS_HTTP_PORT` | `8888` | Host port for the UI |
| `PHOENIX_CTSMS_BIND_ADDRESS` | `127.0.0.1` | Host interface for the UI and Signup (`0.0.0.0` for LAN access) |
| `PHOENIX_POSTGRES_PASSWORD` | `ctsms` | DB password |
| `PHOENIX_JAVA_XMX` | `1536m` | Tomcat heap |
| `PHOENIX_DEMO_DATA` | `false` | Load demo dataset on first init only |
| `PHOENIX_TITLE_DATA` | `false` | Load titles on first init only |
| `PHOENIX_BANK_DATA` | `false` | Load the German bank directory on first init only |
| `PHOENIX_POSTAL_DATA` | `false` | Load countries, postal codes, and streets on first init only |
| `PHOENIX_ICD_DATA` | `false` | Load ICD-10 and Alpha-ID on first init only |
| `PHOENIX_OPS_DATA` | `false` | Load OPS on first init only |
| `PHOENIX_ASP_DATA` | `false` | Load the ASP register on first init only |
| `PHOENIX_PUBLIC_URL` | `http://localhost:8888` | Printed login URL and Signup link back to the UI |
| `PHOENIX_SIGNUP` | `true` | Start Signup and Redis with `docker compose up` |
| `PHOENIX_SIGNUP_HTTP_PORT` | `3000` | Host port for Signup |
| `PHOENIX_CTSMS_IMAGE` | `phoenixctms/ctsms:latest` | Override the Java image (e.g. GHCR) |
| `PHOENIX_SIGNUP_IMAGE` | `phoenixctms/signup:latest` | Override the Signup image (e.g. GHCR) |

## Architecture notes

- The WAR is built in a multi-stage Dockerfile (JDK 21 + Maven), migrated with jakartaee-migration for Tomcat 10, then copied into the runtime image. End users do **not** run Maven.
- State-diagram tooltip PNGs (English and German) are rendered by bulk-processor `render.sh` in the image publish job, after init, and stored in that WAR. Graphviz, gnuplot, ImageMagick, and Ghostscript are not installed in the runtime images.
- Schema SQL is generated at image build time and applied by `db-migrate` on first start.
- Master-data load and user creation run once in `db-init` (skips when the `phoenix` user or init marker is already present). A later start still creates any missing `my_department_signup_{en,de,es}` user.
- Perl bulk-processor is installed in the `ctsms` image so JobService can exec `process.pl` locally.
- Redis starts with Signup when `PHOENIX_SIGNUP` is true. The Java service does not connect to it. Signup uses it for Dancer sessions.

## License

LGPL-2.1 — see [LICENSE](LICENSE).
