#!/bin/bash
# Same step as install-debian upgrade.sh: bulk-processor Render/render.sh.
# Graphviz is installed here only. The published image does not keep it.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends libgraphviz-perl fonts-urw-base35
rm -rf /var/lib/apt/lists/*

/usr/local/bin/set-properties.sh

export CATALINA_BASE="${CATALINA_BASE:-/usr/local/tomcat}"
if [ ! -d "$CATALINA_BASE/webapps/ROOT/WEB-INF/lib" ]; then
  echo "Exploding ROOT.war for dbtool classpath..."
  mkdir -p "$CATALINA_BASE/webapps/ROOT"
  ( cd "$CATALINA_BASE/webapps/ROOT" && jar xf ../ROOT.war )
fi

dept="$(sed -n 's/^Department passphrase (my_department): //p' /credentials/login.txt | head -n 1 | tr -d '\r')"
if [ -z "$dept" ]; then
  echo "Department passphrase is missing from /credentials/login.txt" >&2
  exit 1
fi

perms="INVENTORY_VIEW_USER_DEPARTMENT,STAFF_DETAIL_IDENTITY,COURSE_VIEW_USER_DEPARTMENT,TRIAL_SIGNUP,PROBAND_SIGNUP,USER_ACTIVE_USER,INPUT_FIELD_VIEW,MASS_MAIL_SIGNUP,INVENTORY_NO_SEARCH,STAFF_NO_SEARCH,COURSE_NO_SEARCH,TRIAL_NO_SEARCH,PROBAND_NO_SEARCH,USER_NO_SEARCH,INPUT_FIELD_NO_SEARCH,MASS_MAIL_NO_SEARCH"
export PGPASSWORD="${PHOENIX_DBPASS:-ctsms}"
render_dir=/ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/Render

shopt -s nullglob
skip_cfgs=""
for cfg in "$render_dir"/config.cfg "$render_dir"/config_*.cfg; do
  case "$cfg" in
    *.debug.cfg) continue ;;
  esac
  sed -r -i 's|http://127\.0\.0\.1:8080/rest|http://ctsms:8080/rest|' "$cfg"
  user="$(sed -n 's/^ctsmsrestapi_username = //p' "$cfg" | head -n 1 | tr -d '\r')"
  case "$user" in
    my_department_signup_[a-z]*) ;;
    *)
      echo "Unexpected REST user '${user}' in ${cfg}" >&2
      exit 1
      ;;
  esac
  lang="${user#my_department_signup_}"
  count="$(psql -h "${PHOENIX_DBSERVER:-db}" -p "${PHOENIX_DBPORT:-5432}" -U "${PHOENIX_DBUSER:-ctsms}" -d "${PHOENIX_DBNAME:-ctsms}" -Atc \
    "SELECT COUNT(*) FROM users WHERE name = '${user}';")"
  if [ "${count:-0}" = "0" ]; then
    echo "Creating signup user ${user}..."
    log="$(mktemp)"
    if ! /ctsms/dbtool.sh -cu -dlk my_department -dp "$dept" \
      -u "$user" -p "$user" -ul "$lang" -pp "$perms" >"$log" 2>&1; then
      if grep -q 'invalid locale' "$log"; then
        echo "Skipping ${cfg}: locale ${lang} is not supported."
        skip_cfgs="${skip_cfgs} ${cfg}"
        cat "$log"
        continue
      fi
      cat "$log" >&2
      exit 1
    fi
    cat "$log"
  fi
done

cd "$render_dir"
render_script="$(mktemp)"
cp ./render.sh "$render_script"
for cfg in $skip_cfgs; do
  sed -i "/$(basename "$cfg")/d" "$render_script"
done
bash "$render_script"

missing=0
for cfg in "$render_dir"/config.cfg "$render_dir"/config_*.cfg; do
  case "$cfg" in
    *.debug.cfg) continue ;;
  esac
  case " ${skip_cfgs} " in
    *" ${cfg} "*) continue ;;
  esac
  settings="${cfg/config/settings}"
  png="$(sed -n 's/^trialstatustype_filename = //p' "$settings" | head -n 1 | tr -d '\r')"
  if [ -z "$png" ] || [ ! -s "$png" ]; then
    echo "Missing tooltip image for ${cfg}: ${png:-trialstatustype_filename}" >&2
    missing=1
  fi
done
if [ "$missing" != "0" ]; then
  exit 1
fi
count="$(find /ctsms/build/ctsms/web/src/main/webapp/resources/images/tooltips -name '*.png' -size +0c | wc -l)"
echo "Rendered ${count} tooltip images."
