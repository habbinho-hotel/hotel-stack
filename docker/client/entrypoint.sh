#!/bin/sh
# Gera os arquivos de configuração do Octane (public/configuration/*.json) a partir dos
# .example do repositório, trocando as URLs de localhost pelas deste ambiente.
# Só cria o que ainda não existe: um arquivo seu montado por volume não é sobrescrito.
set -eu

CONF="${OCTANE_CONF_DIR:-/usr/share/nginx/html/configuration}"

# Valores sem barra final (usados como estão no client-mode.json)
U_RAW="${PUBLIC_URL:-http://localhost:8080}"; U_RAW="${U_RAW%/}"
W_RAW="${PUBLIC_WS_URL:-ws://localhost:2096}"; W_RAW="${W_RAW%/}"
A_RAW="${PUBLIC_API_URL:-http://localhost:2096}"; A_RAW="${A_RAW%/}"

# Versões escapadas para o lado direito do sed (\ / & |)
esc() { printf '%s' "$1" | sed 's/[\\/&|]/\\&/g'; }
U=$(esc "$U_RAW")
W=$(esc "$W_RAW")
A=$(esc "$A_RAW")

render() {
  name="$1"
  src="$CONF/$name.example"
  dst="$CONF/$name.json"
  [ -f "$dst" ] && return 0
  [ -f "$src" ] || { echo "[octane-config] faltando $src" >&2; exit 1; }
  # A ordem importa: as URLs mais específicas vêm antes da troca genérica de http://localhost
  sed \
    -e "s|http://localhost/camera/photo/temp|$U/gamedata/camera|g" \
    -e "s|http://localhost/gamedata/badgeparts/|$U/gamedata/c_images/groupbadge/badgeparts/|g" \
    -e "s|http://localhost/habbo-imaging/badge/|$U/gamedata/c_images/groupbadge/badge/|g" \
    -e "s|http://localhost/gamedata/badgeparts/|$U/gamedata/c_images/groupbadge/badgeparts/|g" \
    -e "s|http://localhost|$U|g" \
    -e "s|ws://localhost:2096|$W|g" \
    -e "s|http://localhost:2096|$A|g" \
    "$src" > "$dst"
}

render renderer-config
render ui-config
render hotlooks
render news

# Corrige a api.url que o sed pode ter transformado em http://localhost:8080:2096
# O api.url deve ser http://localhost:2096 (ponto de conexão do game server)
if [ -f "$CONF/renderer-config.json" ]; then
  sed -i 's|"api\.url": "http://localhost:8080:2096"|"api.url": "http://localhost:2096"|g' "$CONF/renderer-config.json"
fi

# Index HTML sem o script do Turnstile (não requer internet a mais)
cat > /usr/share/nginx/html/index.html << 'INDEXEOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><div id="root"></div><script src="configuration/bootstrap.js?v=mwkcd1pq"></script></body></html>
INDEXEOF

if [ ! -f "$CONF/client-mode.json" ]; then
  # Sem ofuscação nem modo seguro (mesmo padrão do instalador para um arquivo novo)
  cat > "$CONF/client-mode.json" <<EOF
{
    "distObfuscationEnabled": false,
    "secureAssetsEnabled": false,
    "secureApiEnabled": false,
    "apiBaseUrl": "${A_RAW}",
    "plainConfigBaseUrl": "${U_RAW}/configuration/",
    "plainGamedataBaseUrl": "${U_RAW}/gamedata/"
}
EOF
fi

echo "[octane-config] cliente configurado para ${U_RAW} (ws: ${W_RAW})"
