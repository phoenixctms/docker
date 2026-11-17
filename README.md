# Docker environment for Phoenix CTMS

Try Phoenix CTMS in minutes with Docker Compose — no VirtualBox/.ova and no on-host Maven build.

This replaces the older Tomcat 8 / Postgres 12 evaluation compose with a current stack:

| Service | Image / role |
|---------|----------------|
| `db` | PostgreSQL 17 |
| `redis` | Redis 7, Signup sessions only (`--profile signup`) |
| `db-migrate` | Applies schema once |
| `ctsms` | Tomcat 10 + prebuilt Phoenix WAR + Perl bulk-processor (UI jobs). Container name `ctsms` |
| `db-init` | Loads master data and creates the `phoenix` login |
| `signup` | Optional Signup Dancer app (`--profile signup`) |

For production single-host Debian installs, keep using [`phoenixctms/install-debian`](https://github.com/phoenixctms/install-debian) / the OVA.

## Requirements

- Docker Engine or Docker Desktop (Windows/macOS/Linux)
- About 6–8 GB RAM recommended
- Port `8888` free on localhost (override with `CTSMS_HTTP_PORT`; bind address with `CTSMS_BIND_ADDRESS`)
- Port `3000` free when using the signup profile (override with `SIGNUP_HTTP_PORT`)

## Quick start (prebuilt images)

Once images are published to GHCR:

```bash
export CTSMS_IMAGE=ghcr.io/phoenixctms/ctsms:latest
docker compose pull
docker compose up -d
docker compose logs -f db-init
```

When init finishes it prints:

```text
URL: http://localhost:8888
Username: phoenix
Password: ...
```

Open http://localhost:8888 and log in. Credentials are also stored in the `credentials` volume (`/credentials/login.txt` inside `db-init` / `ctsms`).

Optional demo data (set on **first** start; enabling it later does not re-import because init runs once per data volumes):

```bash
DEMO_DATA=true docker compose up -d
```

To re-init from scratch after changing init options: `docker compose down -v` then `up` again.

## Build locally

```bash
docker compose build
docker compose up -d
docker compose logs -f db-init
```

Build args (optional):

```bash
CTSMS_TAG=master CONFIG_TAG=master MASTER_DATA_TAG=master BULK_TAG=master docker compose build
```

## Useful commands

```bash
# Follow the Java service logs
docker compose logs -f ctsms

# Stop (keep data)
docker compose down

# Reset everything (DB + uploads + credentials)
docker compose down -v
```

## Perl jobs (ECRF export, etc.)

UI/JobService Perl jobs run **inside the `ctsms` container** (same as install-debian): `/ctsms/bulk_processor/...`. No extra Compose profile is required for that.

## Optional Signup

UI Perl jobs do not need this profile. Signup is the long-running Dancer app:

```bash
docker compose --profile signup up -d
```

Open http://localhost:3000 (or `SIGNUP_HTTP_PORT`). There is no browser password. The start page is a site picker: choose My Department, then continue to the proband step.

Signup calls the app REST API as `my_department_signup_en`, `my_department_signup_de`, and `my_department_signup_es` (password equals the username). `config.cfg` in the container is pointed at Postgres, Redis, and `my_department_cron`. The cron password is the random value `db-init` writes to `/credentials/login.txt`. Signup waits until that seed has finished.

## Environment variables

See [`.env.example`](.env.example). Important ones:

| Variable | Default | Meaning |
|----------|---------|---------|
| `CTSMS_HTTP_PORT` | `8888` | Host port for the UI |
| `CTSMS_BIND_ADDRESS` | `127.0.0.1` | Host interface for the UI and Signup (`0.0.0.0` for LAN access) |
| `POSTGRES_PASSWORD` | `ctsms` | DB password |
| `JAVA_XMX` | `1536m` | Tomcat heap |
| `DEMO_DATA` | `false` | Load demo dataset on first init only |
| `PUBLIC_URL` | `http://localhost:8888` | Printed login URL and Signup link back to the UI |
| `SIGNUP_HTTP_PORT` | `3000` | Host port for Signup (`--profile signup`) |
| `CTSMS_IMAGE` | `phoenixctms/ctsms:latest` | Override the Java image (e.g. GHCR) |
| `SIGNUP_IMAGE` | `phoenixctms/signup:latest` | Override the Signup image (e.g. GHCR) |

## Architecture notes

- The WAR is built in a multi-stage Dockerfile (JDK 21 + Maven), migrated with jakartaee-migration for Tomcat 10, then copied into the runtime image. End users do **not** run Maven.
- Schema SQL is generated at image build time and applied by `db-migrate` on first start.
- Master-data load and user creation run once in `db-init` (skips when the `phoenix` user or init marker is already present). A later start still creates any missing `my_department_signup_{en,de,es}` user.
- Perl bulk-processor is installed in the `ctsms` image so JobService can exec `process.pl` locally.
- Redis starts only with `--profile signup`. The Java service does not connect to it. Signup uses it for Dancer sessions.

## License

LGPL-2.1 — see [LICENSE](LICENSE).
