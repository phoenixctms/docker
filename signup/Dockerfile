# Optional Signup Dancer app for Compose profile "signup".
# Use Debian system perl so apt lib*-perl packages are on @INC (matches install-debian).
ARG BULK_TAG=master
ARG CONFIG_TAG=master

FROM debian:bookworm-slim

ARG BULK_TAG
ARG CONFIG_TAG
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
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
    libmarpa-r2-perl \
    libmime-lite-perl \
    libmime-tools-perl \
    libnet-address-ip-local-perl \
    libnet-smtp-ssl-perl \
    libole-storage-lite-perl \
    libphp-serialization-perl \
    libexcel-writer-xlsx-perl \
    libspreadsheet-parseexcel-perl \
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
    libyaml-tiny-perl \
    libtemplate-perl \
    libdancer-perl \
    libplack-perl \
    libredis-perl \
    libgd-perl \
    libsys-cpuaffinity-perl \
    libtest-utf8-perl \
    libmoosex-hasdefaults-perl \
    gnuplot \
    imagemagick \
    ghostscript \
    build-essential \
    cpanminus \
    curl \
    ca-certificates \
    default-jre-headless \
 && rm -rf /var/lib/apt/lists/* \
 && cpanm --notest Dancer::Plugin::I18N \
 && cpanm --notest Dancer::Session::Redis \
 && cpanm --notest DateTime::Format::Excel \
 && cpanm --notest Spreadsheet::Reader::Format \
 && cpanm --notest Spreadsheet::Reader::ExcelXML \
 && cpanm --notest Tie::IxHash

# config-default first (Signup cfg/yml/i18n), then bulk-processor code on top.
RUN mkdir -p /ctsms \
 && curl -fsSL -o /tmp/config.tar.gz \
      "https://github.com/phoenixctms/config-default/archive/${CONFIG_TAG}.tar.gz" \
 && tar -xzf /tmp/config.tar.gz -C /ctsms --strip-components 1 \
 && rm -f /tmp/config.tar.gz \
 && mkdir -p /ctsms/bulk_processor/output \
 && curl -fsSL -o /tmp/bulk-processor.tar.gz \
      "https://github.com/phoenixctms/bulk-processor/archive/${BULK_TAG}.tar.gz" \
 && tar -xzf /tmp/bulk-processor.tar.gz -C /ctsms/bulk_processor --strip-components 1 \
 && rm -f /tmp/bulk-processor.tar.gz \
 && perl /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/minify.pl \
      --folder=/ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup \
 && test -f /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup/settings.yml \
 && test -f /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup/config.cfg \
 && test -f /ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup/production.yml \
 && chmod -R 755 /ctsms/bulk_processor \
 && chmod -R 777 /ctsms/bulk_processor/output \
 && curl -fsSL -o /ctsms/ecrfdataexport.sh https://raw.githubusercontent.com/phoenixctms/install-debian/master/ecrfdataexport.sh \
 && curl -fsSL -o /ctsms/ecrfdataimport.sh https://raw.githubusercontent.com/phoenixctms/install-debian/master/ecrfdataimport.sh \
 && curl -fsSL -o /ctsms/inquirydataexport.sh https://raw.githubusercontent.com/phoenixctms/install-debian/master/inquirydataexport.sh \
 && curl -fsSL -o /ctsms/inquirydataimport.sh https://raw.githubusercontent.com/phoenixctms/install-debian/master/inquirydataimport.sh \
 && chmod 755 /ctsms/*.sh

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

WORKDIR /ctsms/bulk_processor
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["perl", "/ctsms/bulk_processor/CTSMS/BulkProcessor/Projects/WebApps/Signup/app.pl"]
