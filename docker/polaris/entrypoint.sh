#!/bin/sh
# Gera o config.ini a partir do exemplo do repositório + variáveis HOTEL_*, e inicia o Polaris.
set -eu

# Com DB_HOSTNAME definido o Polaris ignora o config.ini e lê só variáveis de ambiente.
# Aqui usamos o config.ini, então garantimos que ela não exista.
unset DB_HOSTNAME

APP_DIR="${APP_DIR:-/app}"
DATA_DIR="${DATA_DIR:-/data}"
CFG="$APP_DIR/config.ini"
cp "$APP_DIR/config.ini.example" "$CFG"

# set_kv chave valor: troca o valor da chave (ou acrescenta no fim). Sem sed, para não
# quebrar com caracteres especiais em senhas.
set_kv() {
  K="$1" V="$2" awk '
    BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"] }
    { i = index($0, "="); if (i > 0 && substr($0, 1, i - 1) == k) { print k "=" v; found = 1 } else print }
    END { if (!found) print k "=" v }
  ' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
}

# Segredos gerados uma vez e guardados no volume /data (sobrevivem a restarts e rebuilds).
SECRETS="$DATA_DIR/secrets.env"
if [ ! -s "$SECRETS" ]; then
  gen() { head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
  {
    echo "MASTER_KEY=$(gen)"
    echo "JWT_SECRET=$(gen)"
  } > "$SECRETS"
  chmod 600 "$SECRETS"
fi
. "$SECRETS"

set_kv db.hostname "${HOTEL_DB_HOST:-db}"
set_kv db.port "${HOTEL_DB_PORT:-3306}"
set_kv db.database "${HOTEL_DB_NAME:-habbo}"
set_kv db.username "${HOTEL_DB_USER:-polaris}"
set_kv db.password "${HOTEL_DB_PASSWORD:?HOTEL_DB_PASSWORD não definido}"
set_kv db.params "?characterEncoding=utf8&useSSL=false&serverTimezone=${TZ:-UTC}"

# O backup automático antes de migrations usa o mariadb-dump, que não existe nesta imagem.
# Faça backups pelo container do banco (veja o README).
set_kv db.migrations.backup.enabled false

set_kv game.host 0.0.0.0
set_kv nitro.secure.master_key "$MASTER_KEY"
set_kv login.remember.jwt.secret "$JWT_SECRET"

# Cookie "Secure" não funciona em http (exceto localhost): só deixa ligado com https.
case "${HOTEL_PUBLIC_URL:-}" in
  https://*) ;;
  *) set_kv login.remember.cookie.secure false ;;
esac

# shellcheck disable=SC2086  # JAVA_OPTS é uma lista de flags, de propósito sem aspas
exec java -Dfile.encoding=UTF8 ${JAVA_OPTS:--Xmx2g} -jar "$APP_DIR/polaris.jar"
