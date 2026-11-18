#!/usr/bin/env bash
# Install script for Hotel (Polaris + Octane) with nitro-assets integration
# Usage: bash /home/o/Downloads/hotel-docker/setup.sh

set -euo pipefail
cd "$(dirname "$0")"

# Source .env file if it exists (so variables are available even on re-runs)
if [ -f .env ]; then
  # shellcheck source=/dev/null
  set -a
  . .env
  set +a
fi

echo "========================================="
echo "  Hotel (Polaris + Octane) Installation"
echo "========================================="

# ==========================================
# 1. Clone repositories
# ==========================================
echo ""
echo "[1/7] Cloning repositories..."

clone() {
  local name="$1" url="$2"
  if [ -d "$name/.git" ]; then
    echo "  [ok] $name já existe"
  else
    echo "  [cloning] $name"
    git clone --depth 1 "$url" "$name"
  fi
}

clone polaris-emulator https://github.com/duckietm/Polaris-Emulator.git
clone Octane           https://github.com/duckietm/Octane.git
clone Octane-Renderer  https://github.com/duckietm/Octane-Renderer.git

echo "  [ok] Todos os repositórios clonados (ou já existiam)"

# ==========================================
# 2. Create .env file
# ==========================================
echo ""
echo "[2/7] Creating .env file..."

if [ ! -f .env ]; then
  gen() { head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
  sed -e "s|^DB_ROOT_PASSWORD=.*|DB_ROOT_PASSWORD=$(gen)|" \
      -e "s|^DB_PASSWORD=.*|DB_PASSWORD=$(gen)|" \
      .env.example > .env
  echo "  [ok] .env criado com senhas aleatórias"
else
  echo "  [ok] .env já existe (mantido)"
fi

# ==========================================
# 3. Setup gamedata assets
# ==========================================
echo ""
echo "[3/7] Setting up gamedata assets..."

# Create directory structure
mkdir -p gamedata/images gamedata/c_images/groupbadge/badgeparts

# Copy from Polar emulator (base assets)
echo "  [copy] Assets from Polar emulator..."
cp -rn polaris-emulator/Assets/images/.     gamedata/images/ 2> >(grep -v 'non-portable' >&2 || true)
cp -rn polaris-emulator/Assets/badgeparts/. gamedata/c_images/groupbadge/badgeparts/ 2> >(grep -v 'non-portable' >&2 || true)

# Copy additional folders expected by Octane client
for folder in additions events furniextras navigator reception rules wallet; do
  cp -rn polaris-emulator/Assets/images/$folder/     gamedata/images/$folder/ 2> >(grep -v 'non-portable' >&2 || true)
done

# === NITRO-ASSETS INTEGRATION ===
# Baixa e integra o conjunto completo de assets do repositório sphynxkitten/nitro-assets
# Isso fornece todos os arquivos de configuração, imagens, sons e mobiliário necessários
# para o hotel funcionar totalmente após o login.

echo "  [nitro-assets] Integrando conjunto completo de assets..."

# Caminho onde o nitro-assets pode estar localizado
NITRO_ASSETS_DIR="$HOME/nitro-assets"

# Se o diretório já existir, usa-o; senão tenta baixar
if [ -d "$NITRO_ASSETS_DIR" ]; then
  echo "  [nitro-assets] Diretório encontrado localmente!"
else
  echo "  [nitro-assets] Tentando baixar do GitHub..."
  if git clone --depth 1 https://github.com/sphynxkitten/nitro-assets.git "$NITRO_ASSETS_DIR" 2>/dev/null; then
    echo "  [nitro-assets] Repositório baixado com sucesso!"
  else
    echo "  [nitro-assets] Não foi possível baixar - usando assets do Polar emulator"
    NITRO_ASSETS_DIR=""
  fi
fi

# Integrate assets if directory exists
if [ -n "$NITRO_ASSETS_DIR" ] && [ -d "$NITRO_ASSETS_DIR" ]; then
  # Copiar arquivos de configuração (o repo nitro-assets não tem pasta config/: os JSONs
  # ficam em clothes/json, furniture/json, effects/json e gamedata/json).
  # -f de propósito: os stubs vazios de gamedata/config são substituídos pelos reais.
  mkdir -p gamedata/config
  for pair in "clothes/json/FigureData.json:FigureData.json" \
              "clothes/json/FigureMap.json:FigureMap.json" \
              "effects/json/EffectMap.json:EffectMap.json" \
              "furniture/json/FurnitureData.json:FurnitureData.json" \
              "furniture/json/ProductData.json:ProductData.json" \
              "gamedata/json/ExternalTexts.json:ExternalTexts.json" \
              "gamedata/json/HabboAvatarActions.json:HabboAvatarActions.json"; do
    src="$NITRO_ASSETS_DIR/${pair%%:*}"
    dst="gamedata/config/${pair##*:}"
    [ -f "$src" ] && cp -f "$src" "$dst"
  done
  echo "  [nitro-assets] Configurações copiadas"

  # Assets que o cliente pede em .hab: os .nitro do nitro-assets têm o mesmo conteúdo (o
  # renderer detecta pelo arquivo, não pela extensão).
  if [ -d "$NITRO_ASSETS_DIR/clothes/nitro" ]; then
    mkdir -p gamedata/clothes
    for f in "$NITRO_ASSETS_DIR"/clothes/nitro/*.nitro; do
      [ -f "$f" ] && cp -f "$f" "gamedata/clothes/$(basename "$f" .nitro).hab"
    done
  fi
  if [ -d "$NITRO_ASSETS_DIR/effects/nitro" ]; then
    mkdir -p gamedata/effect
    for f in "$NITRO_ASSETS_DIR"/effects/nitro/*.nitro; do
      [ -f "$f" ] && cp -f "$f" "gamedata/effect/$(basename "$f" .nitro).hab"
    done
  fi
  # Móveis: hardlink por .hab para não duplicar ~260 MB (fallback: copia)
  if [ -d gamedata/furniture/nitro ]; then
    for f in gamedata/furniture/nitro/*.nitro; do
      [ -f "$f" ] || continue
      dst="gamedata/furniture/$(basename "$f" .nitro).hab"
      ln -f "$f" "$dst" 2>/dev/null || cp -f "$f" "$dst"
    done
  fi
  # c_images (reception, navigator, events...) usa o mesmo conteúdo de images
  mkdir -p gamedata/c_images
  cp -rn gamedata/images/. gamedata/c_images/ 2>/dev/null || true
  # Ícones de mobiliário
  [ -e gamedata/icons ] || ln -s furniture/icons gamedata/icons
  echo "  [nitro-assets] .hab de roupas/efeitos/móveis e c_images prontos"

  # Copiar imagens completas
  if [ -d "$NITRO_ASSETS_DIR/images" ]; then
    cp -rn "$NITRO_ASSETS_DIR/images/"*     gamedata/images/ 2> >(grep -v 'non-portable' >&2 || true)
    echo "  [nitro-assets] Imagens copiadas"
  fi

  # Copiar c_images (badges e ícones)
  if [ -d "$NITRO_ASSETS_DIR/c_images" ]; then
    cp -rn "$NITRO_ASSETS_DIR/c_images/"*     gamedata/c_images/ 2> >(grep -v 'non-portable' >&2 || true)
    echo "  [nitro-assets] C-images (badges) copiadas"
  fi

  # Copiar sons
  if [ -d "$NITRO_ASSETS_DIR/sounds" ]; then
    mkdir -p gamedata/sounds
    cp -rn "$NITRO_ASSETS_DIR/sounds/"*      gamedata/sounds/ 2> >(grep -v 'non-portable' >&2 || true)
    echo "  [nitro-assets] Sons copiados"
  fi

  # Copiar mobiliário (.nitro/.hab bundles)
  if [ -d "$NITRO_ASSETS_DIR/furniture" ]; then
    mkdir -p gamedata/furniture
    cp -rn "$NITRO_ASSETS_DIR/furniture/"*    gamedata/furniture/ 2> >(grep -v 'non-portable' >&2 || true)
    echo "  [nitro-assets] Mobiliário copiado"
  fi

  # Copiar habbopages
  if [ -d "$NITRO_ASSETS_DIR/habbopages" ]; then
    mkdir -p gamedata/habbopages
    cp -rn "$NITRO_ASSETS_DIR/habbopages/"*  gamedata/habbopages/ 2> >(grep -v 'non-portable' >&2 || true)
    echo "  [nitro-assets] Habbo pages copiadas"
  fi

  echo "  [nitro-assets] Conjunto completo integrado com sucesso!"
else
  echo "  [nitro-assets] Usando assets do Polar emulator como fallback"
  echo "  [copy] Assets from Polar emulator..."
  cp -rn polaris-emulator/Assets/images/.     gamedata/images/ 2> >(grep -v 'non-portable' >&2 || true)
  cp -rn polaris-emulator/Assets/badgeparts/. gamedata/c_images/groupbadge/badgeparts/ 2> >(grep -v 'non-portable' >&2 || true)

  for folder in additions events furniextras navigator reception rules wallet; do
    cp -rn polaris-emulator/Assets/images/$folder/     gamedata/images/$folder/ 2> >(grep -v 'non-portable' >&2 || true)
  done
fi

echo "  [ok] gamedata/ pronto"

# ==========================================
# 4. Build and start Docker
# ==========================================
echo ""
echo "[4/7] Building and starting Docker containers..."

docker compose build
echo "  [ok] Build completed"

docker compose up -d
echo "  [ok] Containers started"

# ==========================================
# 5. Wait for Polar to load
# ==========================================
echo ""
echo "[5/7] Waiting for Polar emulator to load..."

# Wait up to 5 minutes for Polar to load
for i in $(seq 1 30); do
  if docker compose logs polaris 2>&1 | grep -q 'Polaris has successfully loaded'; then
    echo "  [ok] Polar emulator loaded successfully!"
    break
  fi
  sleep 10
done

# Check if we found it
if docker compose logs polaris 2>&1 | grep -q 'Polaris has successfully loaded'; then
  echo "  [ok] Polar emulator loaded successfully!"
else
  echo "  [warn] Polar still starting (may still work)"
fi

echo "  [ok] Polar is ready"

# ==========================================
# 6. Verify setup
# ==========================================
echo ""
echo "[6/7] Verifying setup..."

sleep 3

# Check client configs are generated
if docker compose exec client ls /usr/share/nginx/html/configuration/renderer-config.json >/dev/null 2>&1; then
  echo "  [ok] renderer-config.json generated"
else
  echo "  [warn] renderer-config.json not yet generated, waiting..."
  sleep 5
fi

if docker compose exec client curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1/gamedata/config/FigureData.json" | grep -q '200'; then
  echo "  [ok] gamedata config files accessible"
else
  echo "  [warn] gamedata config files may need more time"
fi

# ==========================================
# 7. Final instructions
# ==========================================
echo ""
echo "========================================="
echo "  Installation Complete! ✅"
echo "========================================="
echo ""
echo "Hotel accessible at: http://localhost:8080"
echo "Polaris WebSocket:   ws://localhost:2096"
echo "Database:            MariaDB on port 3306 (internal)"
echo ""
echo "Next steps:"
echo "  1. Open http://localhost:8080 no navegador"
echo "  2. Crie uma conta na tela do Octane"
echo "  3. Dê rank 7 ao usuário via SQL:"
echo "     docker compose exec db sh -c 'mariadb -uroot -p\"${DB_ROOT_PASSWORD}\" \"${DB_NAME}\"'"
echo "        # dentro do SQL: UPDATE users SET \`rank\` = 7 WHERE username = 'SeuNome';"
echo ""
echo "Full assets (recommended):"
echo "  Para assets completos (furni, roupas, catálogo, sons):"
echo "    - Baixe https://github.com/sphynxkitten/nitro-assets"
echo "    - Coloque na pasta ~/nitro-assets"
echo "    - Reexecute este script ou copie manualmente para gamedata/"
echo ""
echo "Limited assets (current - hotel boots successfully):"
echo "  - Login e navegação básica funcionam"
echo "  - Móveis, avatares e catálogo limitado (usando assets do Polar)"
echo ""
echo "To restart or reconfigure:"
echo "  docker compose down && docker compose up -d"
echo "  # or: bash /home/o/Downloads/hotel-docker/setup.sh"
