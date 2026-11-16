# Docker environment for Phoenix CTMS

Try Phoenix CTMS in minutes with Docker Compose — no VirtualBox/.ova and no on-host Maven build.

This replaces the older Tomcat 8 / Postgres 12 evaluation compose with a current stack:

| Service | Image / role |
|---------|----------------|
| `db` | PostgreSQL 17 |
| `redis` | Redis 7 (for optional bulk-processor) |
| `db-migrate` | Applies schema once |
| `app` | Tomcat 10 + prebuilt Phoenix WAR |
| `db-seed` | Loads master data and creates the `phoenix` login |
| `bulk` | Optional Perl bulk-processor (`--profile bulk`) |

For production single-host Debian installs, keep using [`phoenixctms/install-debian`](https://github.com/phoenixctms/install-debian) / the OVA.

## Requirements

- Docker Engine or Docker Desktop (Windows/macOS/Linux)
- About 6–8 GB RAM recommended
- Port `8888` free (override with `PHOENIX_HTTP_PORT`)

## Quick start (prebuilt images)

Once images are published to GHCR:

```bash
export PHOENIX_IMAGE=ghcr.io/phoenixctms/phoenixctms-app:latest
docker compose pull
docker compose up -d
docker compose logs -f db-seed
```

When seed finishes it prints:

```text
URL: http://localhost:8888
Username: phoenix
Password: ...
```

Open http://localhost:8888 and log in. Credentials are also stored in the `credentials` volume (`/credentials/login.txt` inside `db-seed` / `app`).

Optional demo data:

```bash
SEED_DEMO_DATA=true docker compose up -d
```

## Build locally

```bash
docker compose build
docker compose up -d
docker compose logs -f db-seed
```

Build args (optional):

```bash
CTSMS_TAG=master CONFIG_TAG=master MASTER_DATA_TAG=master docker compose build
```

## Useful commands

```bash
# Follow app logs
docker compose logs -f app

# Stop (keep data)
docker compose down

# Reset everything (DB + uploads + credentials)
docker compose down -v
```

## Optional bulk-processor

```bash
docker compose --profile bulk up -d
```

The Perl environment is included; wiring Signup/ETL REST passwords against the seeded cron user is still evolving — treat this profile as experimental.

## Environment variables

See [`.env.example`](.env.example). Important ones:

| Variable | Default | Meaning |
|----------|---------|---------|
| `PHOENIX_HTTP_PORT` | `8888` | Host port for the UI |
| `POSTGRES_PASSWORD` | `ctsms` | DB password |
| `JAVA_XMX` | `1536m` | Tomcat heap |
| `SEED_DEMO_DATA` | `false` | Load demo dataset during seed |
| `PUBLIC_URL` | `http://localhost:8888` | Printed login URL |
| `PHOENIX_IMAGE` | `phoenixctms/app:latest` | Override image (e.g. GHCR) |

## Architecture notes

- The WAR is built in a multi-stage Dockerfile (JDK 21 + Maven), migrated with jakartaee-migration for Tomcat 10, then copied into the runtime image. End users do **not** run Maven.
- Schema SQL is generated at image build time and applied by `db-migrate` on first start.
- Master-data load and user creation run once in `db-seed` (marker file under `/ctsms/external_files`).
- Redis is not required by the Java UI today; it is present for bulk-processor / Signup.

## License

LGPL-2.1 — see [LICENSE](LICENSE).
