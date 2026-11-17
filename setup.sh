#!/usr/bin/env bash
# Prepara tudo para o docker compose: clona os 3 repositórios, cria o .env com senhas
# aleatórias e a pasta gamedata (com os poucos assets que vêm no repositório do Polaris).
set -euo pipefail
cd "$(dirname "$0")"

clone() { # pasta url
  if [ -d "$1/.git" ]; then
    echo "[ok] $1 já existe"
  else
    git clone --depth 1 "$2" "$1"
  fi
}

clone polaris-emulator https://github.com/duckietm/Polaris-Emulator.git
clone Octane           https://github.com/duckietm/Octane.git
clone Octane-Renderer  https://github.com/duckietm/Octane-Renderer.git

if [ ! -f .env ]; then
  gen() { head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'; }
  sed -e "s|^DB_ROOT_PASSWORD=.*|DB_ROOT_PASSWORD=$(gen)|" \
      -e "s|^DB_PASSWORD=.*|DB_PASSWORD=$(gen)|" \
      .env.example > .env
  echo "[ok] .env criado com senhas aleatórias"
else
  echo "[ok] .env já existe (mantido)"
fi

# gamedata: assets copiados do repositório do Polariser.
# O resto (furni, roupas, config/*.json...) você coloca aqui; veja o README.
mkdir -p gamedata/images gamedata/c_images/groupbadge/badgeparts

# -n: não sobrescreve arquivos que você já tenha colocado (o aviso "non-portable" do cp novo é só ruído)
cp -rn polaris-emulator/Assets/images/.     gamedata/images/ 2> >(grep -v 'non-portable' >&2 || true)
cp -rn polaris-emulator/Assets/badgeparts/. gamedata/c_images/groupbadge/badgeparts/ 2> >(grep -v 'non-portable' >&2 || true)

# Copiar subpastas adicionais de imagens que o cliente Octane espera
for folder in additions events furniextras navigator reception rules wallet; do
  cp -rn polaris-emulator/Assets/images/$folder/     gamedata/images/$folder/ 2> >(grep -v 'non-portable' >&2 || true)
done

echo "[ok] gamedata/ preparado (imagens e badgeparts ampliados)"

echo
echo "Próximos passos:"
echo "  docker compose build      # na primeira vez leva alguns minutos"
echo "  docker compose up -d"
echo "  docker compose logs -f polaris"
