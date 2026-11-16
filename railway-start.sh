#!/bin/sh
# Start LinkStack on Railway.
# 1. Seed the volume at /htdocs from the image on first boot.
# 2. Finish LinkStack's setup (admin account, app key, production mode) before
#    Apache starts, so the public URL never shows the open web installer.
# 3. Run Apache in the foreground on $PORT.
set -eu

DATA=/htdocs
DIST=/opt/linkstack

export PORT="${PORT:-8080}"
export SERVER_ADMIN="${SERVER_ADMIN:-webmaster@localhost}"
export HTTP_SERVER_NAME="${HTTP_SERVER_NAME:-${RAILWAY_PUBLIC_DOMAIN:-localhost}}"
export HTTPS_SERVER_NAME="${HTTPS_SERVER_NAME:-$HTTP_SERVER_NAME}"
export LOG_LEVEL="${LOG_LEVEL:-info}"
export TZ="${TZ:-UTC}"

# Same Apache layout fixes as the image build, repeated at runtime in case a
# platform restores files from lower image layers.
: > /etc/apache2/conf.d/ssl.conf
grep -q '^Listen ${PORT}$' /etc/apache2/httpd.conf || sed -i 's/^Listen 80$/Listen ${PORT}/' /etc/apache2/httpd.conf

cat > /etc/php83/conf.d/50-railway.ini <<INI
upload_max_filesize = ${UPLOAD_MAX_FILESIZE:-8M}
post_max_size = ${UPLOAD_MAX_FILESIZE:-8M}
memory_limit = ${PHP_MEMORY_LIMIT:-256M}
date.timezone = ${TZ}
INI

# A fresh Railway volume is empty apart from lost+found.
if [ ! -f "$DATA/version.json" ]; then
  rmdir "$DATA/lost+found" 2>/dev/null || true
  if [ -n "$(ls -A "$DATA" 2>/dev/null | grep -v '^lost+found$' || true)" ]; then
    echo "railway-start: $DATA is not empty and has no version.json; refusing to overwrite it" >&2
    exit 1
  fi
  echo "railway-start: seeding $DATA with LinkStack $(cat "$DIST/version.json")"
  cp -a "$DIST/." "$DATA/"
fi
chown apache:apache "$DATA"

echo "railway-start: LinkStack $(tr -d '\r\n' < "$DATA/version.json") on the volume, image $(tr -d '\r\n' < "$DIST/version.json")"

# Setup and migrations run as the apache user, like the app itself.
su -s /bin/sh apache -c 'cd /htdocs && /usr/bin/php83 /usr/local/lib/linkstack-railway-bootstrap.php'

rm -f "$DATA/httpd.pid" /run/apache2/httpd.pid 2>/dev/null || true
echo "railway-start: starting Apache on port $PORT"
exec httpd -D FOREGROUND
