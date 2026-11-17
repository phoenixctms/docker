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

# Published tooltip images are English and German only.
cfgs=("$render_dir/config.cfg" "$render_dir/config_de.cfg")
for cfg in "${cfgs[@]}"; do
  if [ ! -f "$cfg" ]; then
    echo "Missing render config: ${cfg}" >&2
    exit 1
  fi
  sed -r -i 's|http://127\.0\.0\.1:8080/rest|http://ctsms:8080/rest|' "$cfg"
  user="$(sed -n 's/^ctsmsrestapi_username = //p' "$cfg" | head -n 1 | tr -d '\r')"
  case "$user" in
    my_department_signup_en|my_department_signup_de) ;;
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
    /ctsms/dbtool.sh -cu -dlk my_department -dp "$dept" \
      -u "$user" -p "$user" -ul "$lang" -pp "$perms"
  fi
done

cd "$render_dir"
render_script="$(mktemp)"
grep -E -- '--config=config\.cfg |--config=config_de\.cfg ' ./render.sh > "$render_script"
bash "$render_script"

missing=0
for cfg in "${cfgs[@]}"; do
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
