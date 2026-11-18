# syntax=docker/dockerfile:1.7

ARG CTSMS_TAG=master
ARG CONFIG_TAG=master
ARG MASTER_DATA_TAG=master
ARG BULK_TAG=master

############################
# Build WAR + schema SQL
############################
FROM eclipse-temurin:21-jdk-jammy AS build

ARG CTSMS_TAG
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends git maven ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "${CTSMS_TAG}" https://github.com/phoenixctms/ctsms.git ctsms

WORKDIR /src/ctsms
RUN VERSION="$(grep -oP '<application.version>\K[^<]+' pom.xml)" \
 && COMMIT="$(git rev-parse --short HEAD)" \
 && UUID="$(cat /proc/sys/kernel/random/uuid)" \
 && sed -r -i "s/<application.version>([^<]+)<\\/application.version>/<application.version>\\1 [${COMMIT}]<\\/application.version>/" pom.xml \
 && sed -r -i "s/<application\\.uuid><\\/application.uuid>/<application.uuid>${UUID}<\\/application.uuid>/" pom.xml \
 && echo "${VERSION}" > /tmp/version.txt \
 && echo "${COMMIT}" > /tmp/commit.txt \
 && echo "${UUID}" > /tmp/uuid.txt \
 && mvn install -DskipTests --no-transfer-progress -c \
 && mvn -f core/pom.xml org.andromda.maven.plugins:andromdapp-maven-plugin:schema -Dtasks=create --no-transfer-progress -c \
 && mvn -f core/pom.xml org.andromda.maven.plugins:andromdapp-maven-plugin:schema -Dtasks=drop --no-transfer-progress -c \
 && test -f "web/target/ctsms-${VERSION}.war"

############################
# Jakarta EE migration for Tomcat 10
############################
FROM eclipse-temurin:21-jdk-jammy AS migrate

COPY --from=build /src/ctsms/web/target /wars
COPY --from=build /tmp/version.txt /tmp/version.txt

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates tar \
 && rm -rf /var/lib/apt/lists/* \
 && VERSION="$(cat /tmp/version.txt)" \
 && curl -fsSL -o /tmp/jakartaee-migration.tgz \
      https://raw.githubusercontent.com/phoenixctms/install-debian/master/tomcat/jakartaee-migration-1.0.8-bin.tar.gz \
 && mkdir -p /opt \
 && tar -xzf /tmp/jakartaee-migration.tgz -C /opt \
 && /opt/jakartaee-migration-1.0.8/bin/migrate.sh \
      "/wars/ctsms-${VERSION}.war" \
      "/wars/ROOT.war"

############################
# Runtime: Tomcat 10 + config
############################
FROM tomcat:10.1-jre21-temurin-jammy

ARG CONFIG_TAG
ARG MASTER_DATA_TAG
ARG BULK_TAG
ENV DEBIAN_FRONTEND=noninteractive \
    CTSMS_PROPERTIES=/ctsms/properties \
    CTSMS_JAVA=/ctsms/java \
    CATALINA_HOME=/usr/local/tomcat \
    CATALINA_BASE=/usr/local/tomcat

USER root
# JobService runs perl ETL scripts in this container (same layout as install-debian).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl ca-certificates postgresql-client bash coreutils unzip zip \
      perl \
      libarchive-zip-perl \
      libconfig-any-perl \
      libdata-dump-perl \
      libdata-dumper-concise-perl \
      libdata-uuid-perl \
      libdata-validate-ip-perl \
      libdate-calc-perl \
      libdate-manip-perl \
      libdatetime-format-iso8601-perl \
      libdatetime-format-strptime-perl \
      libdatetime-perl \
      libdatetime-timezone-perl \
      libdbd-csv-perl \
      libdbd-mysql-perl \
      libdbd-sqlite3-perl \
      libdbd-pg-perl \
      libdigest-md5-perl \
      libemail-mime-attachment-stripper-perl \
      libemail-mime-perl \
      libgearman-client-perl \
      libhtml-parser-perl \
      libintl-perl \
      libio-compress-perl \
      libio-socket-ssl-perl \
      libjson-xs-perl \
      libjson-perl \
      liblog-log4perl-perl \
      libmail-imapclient-perl \
      libmime-lite-perl \
      libmime-tools-perl \
      libnet-address-ip-local-perl \
      libnet-smtp-ssl-perl \
      libole-storage-lite-perl \
      libphp-serialization-perl \
      libexcel-writer-xlsx-perl \
      libspreadsheet-parseexcel-perl \
      libspreadsheet-parsexlsx-perl \
      libstring-mkpasswd-perl \
      libtext-csv-xs-perl \
      libtie-ixhash-perl \
      libtime-warp-perl \
      liburi-find-perl \
      libuuid-perl \
      libwww-perl \
      libxml-dumper-perl \
      libxml-libxml-perl \
      libyaml-libyaml-perl \
      libyaml-perl \
      libyaml-tiny-perl \
      libtemplate-perl \
      libdancer-perl \
      libplack-perl \
      libredis-perl \
      libgd-perl \
      libsys-cpuaffinity-perl \
      build-essential \
      cpanminus \
 && cpanm --notest Dancer::Plugin::I18N \
 && cpanm --notest Dancer::Session::Redis \
 && cpanm --notest DateTime::Format::Excel \
 && cpanm --notest Tie::IxHash \
 && rm -rf /root/.cpanm \
 && apt-get purge -y build-essential cpanminus \
 && apt-get autoremove -y --purge \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf "${CATALINA_BASE}/webapps/*" \
 && mkdir -p /ctsms/external_files /ctsms/master_data /ctsms/db /credentials /ctsms/bulk_processor/output

# Application WAR
COPY --from=migrate /wars/ROOT.war ${CATALINA_BASE}/webapps/ROOT.war
COPY --from=build /tmp/version.txt /ctsms/VERSION
COPY --from=build /tmp/commit.txt /ctsms/COMMIT
COPY --from=build /tmp/uuid.txt /ctsms/UUID

# Schema SQL from build
COPY --from=build /src/ctsms/core/db/schema-create.sql /ctsms/db/schema-create.sql
COPY --from=build /src/ctsms/core/db/index-create.sql /ctsms/db/index-create.sql
COPY --from=build /src/ctsms/core/db/schema-set-version.sql /ctsms/db/schema-set-version.sql

# Config + master data + bulk-processor + helper scripts
# Order matches install-debian: config-default first (job cfg overlays), then bulk-processor code.
RUN curl -fsSL -o /tmp/config.tar.gz \
      "https://github.com/phoenixctms/config-default/archive/${CONFIG_TAG}.tar.gz" \
 && tar -xzf /tmp/config.tar.gz -C /ctsms --strip-components 1 \
 && rm -f /tmp/config.tar.gz \
 && curl -fsSL -o /tmp/master-data.tar.gz \
      "https://api.github.com/repos/phoenixctms/master-data/tarball/${MASTER_DATA_TAG}" \
 && tar -xzf /tmp/master-data.tar.gz -C /ctsms/master_data --strip-components 1 \
 && rm -f /tmp/master-data.tar.gz \
 && curl -fsSL -o /tmp/bulk-processor.tar.gz \
      "https://github.com/phoenixctms/bulk-processor/archive/${BULK_TAG}.tar.gz" \
 && tar -xzf /tmp/bulk-processor.tar.gz -C /ctsms/bulk_processor --strip-components 1 \
 && rm -f /tmp/bulk-processor.tar.gz \
 && perl /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/minify.pl \
      --folder=/ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup \
 && mkdir -p /ctsms/bulk_processor/output \
 && chmod -R 755 /ctsms/bulk_processor \
 && chmod -R 777 /ctsms/bulk_processor/output \
 && test -f /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/ETL/EcrfExporter/process.pl \
 && curl -fsSL -o /ctsms/dbtool.sh \
      https://raw.githubusercontent.com/phoenixctms/install-debian/master/dbtool.sh \
 && curl -fsSL -o /ctsms/clearcache.sh \
      https://raw.githubusercontent.com/phoenixctms/install-debian/master/clearcache.sh \
 && curl -fsSL -o /ctsms/ecrfdataexport.sh \
      https://raw.githubusercontent.com/phoenixctms/install-debian/master/ecrfdataexport.sh \
 && curl -fsSL -o /ctsms/ecrfdataimport.sh \
      https://raw.githubusercontent.com/phoenixctms/install-debian/master/ecrfdataimport.sh \
 && curl -fsSL -o /ctsms/inquirydataexport.sh \
      https://raw.githubusercontent.com/phoenixctms/install-debian/master/inquirydataexport.sh \
 && curl -fsSL -o /ctsms/inquirydataimport.sh \
      https://raw.githubusercontent.com/phoenixctms/install-debian/master/inquirydataimport.sh \
 && sed -r -i 's|-Xms[^ ]+|-Xms512m|' /ctsms/dbtool.sh \
 && sed -r -i 's|-Xmx[^ ]+|-Xmx1536m|' /ctsms/dbtool.sh \
 && sed -r -i 's|-Xss[^ ]+|-Xss256k|' /ctsms/dbtool.sh \
 && grep -q -- '-XX:-UseBASE64Intrinsics' /ctsms/dbtool.sh || sed -i 's/-Djava.awt.headless=true/-Djava.awt.headless=true -XX:-UseBASE64Intrinsics/' /ctsms/dbtool.sh \
 && chmod 755 /ctsms/dbtool.sh /ctsms/clearcache.sh /ctsms/ecrfdata*.sh /ctsms/inquirydata*.sh \
 && chmod 775 /ctsms /ctsms/external_files

# Tomcat JVM defaults (overridable via JAVA_OPTS / entrypoint)
ENV JAVA_OPTS="-server -Djava.awt.headless=true --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.sql/java.sql=ALL-UNNAMED -XX:-UseBASE64Intrinsics -Xms512m -Xmx1536m -Xss512k -XX:+UseParallelGC -XX:MaxGCPauseMillis=1500 -XX:GCTimeRatio=9 -XX:ReservedCodeCacheSize=256m"

COPY set-properties.sh /usr/local/bin/set-properties.sh
COPY db-migrate.sh /usr/local/bin/db-migrate.sh
COPY db-init.sh /usr/local/bin/db-init.sh
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/*.sh

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["catalina.sh", "run"]
