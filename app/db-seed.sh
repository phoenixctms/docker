#!/bin/bash
set -euo pipefail

: "${DBSERVER:=db}"
: "${DBPORT:=5432}"
: "${DBUSER:=ctsms}"
: "${DBNAME:=ctsms}"
: "${DBPASS:=ctsms}"
: "${DEFAULT_LOCALE:=en}"
: "${SEED_DEMO_DATA:=false}"
: "${PUBLIC_URL:=http://localhost:8888}"

MARKER=/ctsms/external_files/.phoenix_seeded
CRED_FILE=/credentials/login.txt

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

if [ -f "$MARKER" ]; then
  echo "Seed already completed previously."
  if [ -f "$CRED_FILE" ]; then
    cat "$CRED_FILE"
  fi
  exit 0
fi

echo "Waiting for application HTTP..."
for i in $(seq 1 90); do
  if curl -fsS "http://app:8080/" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done
curl -fsS "http://app:8080/" >/dev/null

run_dbtool() {
  /ctsms/dbtool.sh "$@"
}

echo "Loading master data via dbtool..."
run_dbtool -i -f
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

DEPARTMENT_PASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 32)"
USER_PASSWORD="$(tr -dc 'a-z' </dev/urandom | head -c 3)"
CRON_PASSWORD="$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 8)"

run_dbtool -cd -dlk my_department -dp "$DEPARTMENT_PASSWORD"
run_dbtool -cu -dlk my_department -dp "$DEPARTMENT_PASSWORD" -u "phoenix" -p "$USER_PASSWORD" \
  -pp "INVENTORY_MASTER_ALL_DEPARTMENTS,STAFF_MASTER_ALL_DEPARTMENTS,COURSE_MASTER_ALL_DEPARTMENTS,TRIAL_MASTER_ALL_DEPARTMENTS,PROBAND_MASTER_ALL_DEPARTMENTS,USER_ALL_DEPARTMENTS,INPUT_FIELD_MASTER,MASS_MAIL_MASTER_ALL_DEPARTMENTS,INVENTORY_MASTER_SEARCH,STAFF_MASTER_SEARCH,COURSE_MASTER_SEARCH,TRIAL_MASTER_SEARCH,PROBAND_MASTER_SEARCH,USER_MASTER_SEARCH,INPUT_FIELD_MASTER_SEARCH,MASS_MAIL_MASTER_SEARCH"

# Signup users for common locales (eval convenience)
for lang in en de; do
  run_dbtool -cu -dlk my_department -dp "$DEPARTMENT_PASSWORD" \
    -u "my_department_signup_${lang}" -p "my_department_signup_${lang}" -ul "$lang" \
    -pp "INVENTORY_VIEW_USER_DEPARTMENT,STAFF_DETAIL_IDENTITY,COURSE_VIEW_USER_DEPARTMENT,TRIAL_SIGNUP,PROBAND_SIGNUP,USER_ACTIVE_USER,INPUT_FIELD_VIEW,MASS_MAIL_SIGNUP,INVENTORY_NO_SEARCH,STAFF_NO_SEARCH,COURSE_NO_SEARCH,TRIAL_NO_SEARCH,PROBAND_NO_SEARCH,USER_NO_SEARCH,INPUT_FIELD_NO_SEARCH,MASS_MAIL_NO_SEARCH"
done

run_dbtool -cu -dlk my_department -dp "$DEPARTMENT_PASSWORD" -u "my_department_cron" -p "$CRON_PASSWORD" \
  -pp "INVENTORY_MASTER_ALL_DEPARTMENTS,STAFF_MASTER_ALL_DEPARTMENTS,COURSE_MASTER_ALL_DEPARTMENTS,TRIAL_MASTER_ALL_DEPARTMENTS,PROBAND_MASTER_ALL_DEPARTMENTS,USER_ALL_DEPARTMENTS,INPUT_FIELD_MASTER,MASS_MAIL_MASTER_ALL_DEPARTMENTS,INVENTORY_MASTER_SEARCH,STAFF_MASTER_SEARCH,COURSE_MASTER_SEARCH,TRIAL_MASTER_SEARCH,PROBAND_MASTER_SEARCH,USER_MASTER_SEARCH,INPUT_FIELD_MASTER_SEARCH,MASS_MAIL_MASTER_SEARCH"

if [ "$SEED_DEMO_DATA" = "true" ] || [ "$SEED_DEMO_DATA" = "1" ]; then
  echo "Loading demo data..."
  run_dbtool --load_demo_data || run_dbtool -ldd -f || true
fi

mkdir -p "$(dirname "$CRED_FILE")" "$(dirname "$MARKER")"
{
  echo "Phoenix CTMS initial setup complete."
  echo "URL: ${PUBLIC_URL}"
  echo "Username: phoenix"
  echo "Password: ${USER_PASSWORD}"
  echo "Department passphrase (my_department): ${DEPARTMENT_PASSWORD}"
  echo "Cron user password (my_department_cron): ${CRON_PASSWORD}"
} | tee "$CRED_FILE"

touch "$MARKER"
echo "Seed finished. Credentials written to ${CRED_FILE}"
