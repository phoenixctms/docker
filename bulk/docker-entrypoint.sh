#!/bin/bash
set -euo pipefail

: "${DBSERVER:=db}"
: "${DBPORT:=5432}"
: "${DBUSER:=ctsms}"
: "${DBNAME:=ctsms}"
: "${DBPASS:=ctsms}"
: "${REDIS_HOST:=redis}"
: "${REDIS_PORT:=6379}"

# Prefer cpanm site_perl over apt so upgraded modules win; keep apt for Date::Manip etc.
_site="$(perl -MConfig -e 'print join q{:}, grep { length } @Config{qw(sitearchexp sitelibexp)}')"
export PERL5LIB="${_site}:/usr/share/perl5${PERL5LIB:+:$PERL5LIB}"

echo "bulk-processor container ready (DB=${DBSERVER}:${DBPORT}/${DBNAME}, Redis=${REDIS_HOST}:${REDIS_PORT})."
echo "Exec into this container to run Signup/ETL scripts; full auto-wiring of REST passwords is still evolving."

exec "$@"
