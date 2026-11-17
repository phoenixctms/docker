#!/bin/bash
set -euo pipefail

: "${PHOENIX_DBSERVER:=db}"
: "${PHOENIX_DBPORT:=5432}"
: "${PHOENIX_DBUSER:=ctsms}"
: "${PHOENIX_DBNAME:=ctsms}"
: "${PHOENIX_DBPASS:=ctsms}"
: "${PHOENIX_DEFAULT_LOCALE:=en}"
: "${PHOENIX_DEMO_DATA:=false}"
: "${PHOENIX_PUBLIC_URL:=http://localhost:8888}"
: "${PHOENIX_APP_HTTP:=http://ctsms:8080}"

MARKER=/ctsms/external_files/.phoenix_seeded
CRED_FILE=/credentials/login.txt

export PGPASSWORD="$PHOENIX_DBPASS"

/usr/local/bin/set-properties.sh

# dbtool needs exploded WAR jars from the running app container's webapps —
# this seed container has its own CATALINA_BASE. Point it at a local explode
# of ROOT.war shipped in this image.
export CATALINA_BASE=/usr/local/tomcat
if [ ! -d "$CATALINA_BASE/webapps/ROOT/WEB-INF/lib" ]; then
  echo "Exploding ROOT.war for dbtool classpath..."
  mkdir -p "$CATALINA_BASE/webapps/ROOT"
  cd "$CATALINA_BASE/webapps/ROOT"
  jar xf ../ROOT.war
fi

phoenix_user_exists() {
  local count
  count="$(psql -h "$PHOENIX_DBSERVER" -p "$PHOENIX_DBPORT" -U "$PHOENIX_DBUSER" -d "$PHOENIX_DBNAME" -Atc \
    "SELECT COUNT(*) FROM users WHERE name = 'phoenix';" 2>/dev/null || echo 0)"
  [ "${count:-0}" != "0" ]
}

print_credentials_if_present() {
  if [ -f "$CRED_FILE" ]; then
    cat "$CRED_FILE"
  else
    echo "Seed already completed (phoenix user present)."
    echo "URL: ${PHOENIX_PUBLIC_URL}"
    echo "Username: phoenix"
    echo "Password: (see credentials volume /credentials/login.txt from the original seed)"
  fi
}

run_dbtool() {
  /ctsms/dbtool.sh "$@"
}

signup_user_count() {
  local name="$1" count
  count="$(psql -h "$PHOENIX_DBSERVER" -p "$PHOENIX_DBPORT" -U "$PHOENIX_DBUSER" -d "$PHOENIX_DBNAME" -Atc \
    "SELECT COUNT(*) FROM users WHERE name = '${name}';" 2>/dev/null || echo 0)"
  printf '%s' "${count:-0}"
}

ensure_signup_users() {
  local dept_pass="$1"
  local lang name count
  local perms="INVENTORY_VIEW_USER_DEPARTMENT,STAFF_DETAIL_IDENTITY,COURSE_VIEW_USER_DEPARTMENT,TRIAL_SIGNUP,PROBAND_SIGNUP,USER_ACTIVE_USER,INPUT_FIELD_VIEW,MASS_MAIL_SIGNUP,INVENTORY_NO_SEARCH,STAFF_NO_SEARCH,COURSE_NO_SEARCH,TRIAL_NO_SEARCH,PROBAND_NO_SEARCH,USER_NO_SEARCH,INPUT_FIELD_NO_SEARCH,MASS_MAIL_NO_SEARCH"
  for lang in en de es; do
    name="my_department_signup_${lang}"
    count="$(signup_user_count "$name")"
    if [ "$count" = "0" ]; then
      if [ -z "$dept_pass" ]; then
        echo "Signup user ${name} is missing and the department passphrase is not in ${CRED_FILE}." >&2
        return 1
      fi
      echo "Creating signup user ${name}..."
      run_dbtool -cu -dlk my_department -dp "$dept_pass" \
        -u "$name" -p "$name" -ul "$lang" \
        -pp "$perms"
    fi
  done
}

department_passphrase_from_credentials() {
  if [ ! -f "$CRED_FILE" ]; then
    printf ''
    return 0
  fi
  sed -n 's/^Department passphrase (my_department): //p' "$CRED_FILE" | head -n 1 | tr -d '\r'
}

append_signup_credentials() {
  local lang name
  [ -f "$CRED_FILE" ] || return 0
  for lang in en de es; do
    name="my_department_signup_${lang}"
    if ! grep -q "^Signup service user (${lang}):" "$CRED_FILE"; then
      echo "Signup service user (${lang}): ${name} / ${name}" >> "$CRED_FILE"
    fi
  done
}

if [ -f "$MARKER" ] || phoenix_user_exists; then
  echo "Seed already completed previously."
  print_credentials_if_present
  ensure_signup_users "$(department_passphrase_from_credentials)"
  append_signup_credentials
  exit 0
fi

echo "Waiting for application HTTP..."
for i in $(seq 1 90); do
  if curl -fsS "${PHOENIX_APP_HTTP}/" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done
curl -fsS "${PHOENIX_APP_HTTP}/" >/dev/null

clear_app_caches() {
  echo "Clearing application caches on app..."
  curl -fsS -X POST "${PHOENIX_APP_HTTP}/rest/tools/clearresourcebundlecache" >/dev/null || true
  curl -fsS -X POST "${PHOENIX_APP_HTTP}/rest/tools/clearhibernatecache" >/dev/null || true
  curl -fsS -X POST "${PHOENIX_APP_HTTP}/rest/tools/cleanjavaclasses" >/dev/null || true
}

echo "Loading master data via dbtool..."
# Skip forced re-init when production tables were already populated (partial re-run).
CRITERION_COUNT="$(psql -h "$PHOENIX_DBSERVER" -p "$PHOENIX_DBPORT" -U "$PHOENIX_DBUSER" -d "$PHOENIX_DBNAME" -Atc \
  "SELECT COUNT(*) FROM criterion_restriction;" 2>/dev/null || echo 0)"
if [ "${CRITERION_COUNT:-0}" = "0" ]; then
  run_dbtool -i -f
else
  echo "Production init rows already present; skipping dbtool -i -f."
fi

run_dbtool -icp /ctsms/master_data/criterion_property_definitions.csv
run_dbtool -ipd /ctsms/master_data/permission_definitions.csv
run_dbtool -imi /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -ims /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -imc /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -imt /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -imp /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -immm /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -imifi /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -imifv /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -imsi /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -impi /ctsms/master_data/mime.types -e ISO-8859-1
run_dbtool -imjf /ctsms/master_data/mime.types -e ISO-8859-1
if /ctsms/dbtool.sh -h 2>&1 | grep -q -- '-imcc'; then
  run_dbtool -imcc /ctsms/master_data/mime.types -e ISO-8859-1 || true
fi

run_dbtool -it /ctsms/master_data/titles.csv -e ISO-8859-1
run_dbtool -ib /ctsms/master_data/kiverzeichnis_gesamt_de_1347893202433.csv -e ISO-8859-1
run_dbtool -ic /ctsms/master_data/countries.txt -e ISO-8859-1
run_dbtool -iz /ctsms/master_data/streetnames.csv -e utf-8
run_dbtool -is /ctsms/master_data/streetnames.csv -e utf-8

run_dbtool -iis /ctsms/master_data/icd10gm2012syst_claml_20110923.xml -sl de
run_dbtool -iai /ctsms/master_data/icd10gm2012_alphaid_edv_ascii_20110930.txt -e ISO-8859-1 -isr icd10gm2012syst_claml_20110923
run_dbtool -ios /ctsms/master_data/ops2012syst_claml_20111103.xml -sl de
run_dbtool -ioc /ctsms/master_data/ops2011alpha_edv_ascii_20111031.txt -osr ops2012syst_claml_20111103
run_dbtool -ia /ctsms/master_data/asp_register_20240316.xls -e Cp1252

# tr gets SIGPIPE when head exits; that status is expected under pipefail.
rand_string() {
  local charset="$1" len="$2" out
  out="$(LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$len" || true)"
  if [ "${#out}" -ne "$len" ]; then
    echo "failed to generate ${len}-character random string" >&2
    exit 1
  fi
  printf '%s' "$out"
}
DEPARTMENT_PASSWORD="$(rand_string 'a-zA-Z0-9' 32)"
USER_PASSWORD="$(rand_string 'a-zA-Z0-9' 16)"
CRON_PASSWORD="$(rand_string 'a-zA-Z0-9' 16)"

run_dbtool -cd -dlk my_department -dp "$DEPARTMENT_PASSWORD"
run_dbtool -cu -dlk my_department -dp "$DEPARTMENT_PASSWORD" -u "phoenix" -p "$USER_PASSWORD" \
  -pp "INVENTORY_MASTER_ALL_DEPARTMENTS,STAFF_MASTER_ALL_DEPARTMENTS,COURSE_MASTER_ALL_DEPARTMENTS,TRIAL_MASTER_ALL_DEPARTMENTS,PROBAND_MASTER_ALL_DEPARTMENTS,USER_ALL_DEPARTMENTS,INPUT_FIELD_MASTER,MASS_MAIL_MASTER_ALL_DEPARTMENTS,INVENTORY_MASTER_SEARCH,STAFF_MASTER_SEARCH,COURSE_MASTER_SEARCH,TRIAL_MASTER_SEARCH,PROBAND_MASTER_SEARCH,USER_MASTER_SEARCH,INPUT_FIELD_MASTER_SEARCH,MASS_MAIL_MASTER_SEARCH"

# Signup service users for every language in config-default settings.yml.
ensure_signup_users "$DEPARTMENT_PASSWORD"

run_dbtool -cu -dlk my_department -dp "$DEPARTMENT_PASSWORD" -u "my_department_cron" -p "$CRON_PASSWORD" \
  -pp "INVENTORY_MASTER_ALL_DEPARTMENTS,STAFF_MASTER_ALL_DEPARTMENTS,COURSE_MASTER_ALL_DEPARTMENTS,TRIAL_MASTER_ALL_DEPARTMENTS,PROBAND_MASTER_ALL_DEPARTMENTS,USER_ALL_DEPARTMENTS,INPUT_FIELD_MASTER,MASS_MAIL_MASTER_ALL_DEPARTMENTS,INVENTORY_MASTER_SEARCH,STAFF_MASTER_SEARCH,COURSE_MASTER_SEARCH,TRIAL_MASTER_SEARCH,PROBAND_MASTER_SEARCH,USER_MASTER_SEARCH,INPUT_FIELD_MASTER_SEARCH,MASS_MAIL_MASTER_SEARCH"

if [ "$PHOENIX_DEMO_DATA" = "true" ] || [ "$PHOENIX_DEMO_DATA" = "1" ]; then
  echo "Loading demo data..."
  run_dbtool --load_demo_data || run_dbtool -ldd -f || true
fi

clear_app_caches

mkdir -p "$(dirname "$CRED_FILE")" "$(dirname "$MARKER")"
{
  echo "Phoenix CTMS initial setup complete."
  echo "URL: ${PHOENIX_PUBLIC_URL}"
  echo "Username: phoenix"
  echo "Password: ${USER_PASSWORD}"
  echo "Department passphrase (my_department): ${DEPARTMENT_PASSWORD}"
  echo "Cron user password (my_department_cron): ${CRON_PASSWORD}"
  echo "Signup service user (en): my_department_signup_en / my_department_signup_en"
  echo "Signup service user (de): my_department_signup_de / my_department_signup_de"
  echo "Signup service user (es): my_department_signup_es / my_department_signup_es"
} | tee "$CRED_FILE"

touch "$MARKER"
echo "Seed finished. Credentials written to ${CRED_FILE}"
