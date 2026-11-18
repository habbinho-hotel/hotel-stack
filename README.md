# Hotel em Docker (Polaris + Octane): só o essencial

Três containers: **db** (MariaDB 11.4), **polaris** (emulador, Java 25) e **client** (Octane buildado, servido pelo nginx).
Fica de fora tudo o que o All-in-1 Manager instala além disso: Traefik, NGINX no host, PHP, CMS, Gitea, Fail2Ban etc.

## Subir

```bash
./setup.sh                  # clona os 3 repositórios, cria o .env e a pasta gamedata/
docker compose build        # compila o JAR e o cliente (a primeira vez demora)
docker compose up -d
docker compose logs -f polaris   # espere "Polaris has successfully loaded."
```

Abra `http://localhost:8080`. Na primeira subida o Polaris cria o schema sozinho (migrations automáticas), então não precisa importar SQL.

## Assets (obrigatório para o cliente carregar)

O cliente busca tudo em `http://localhost:8080/gamedata/`, que é a pasta `./gamedata`. O `setup.sh` já coloca o pouco que vem no repositório do Polaris. O resto você gera/baixa com o [All-in-1 Converter](https://github.com/duckietm/all-in-1-converter) (ou **Assets → Habbo assets** no All-in-1 Manager) e copia para cá:

| Pasta em `gamedata/` | Conteúdo |
|---|---|
| `config/` | FurnitureData.json, ProductData.json, FigureData.json, FigureMap.json, EffectMap.json, HabboAvatarActions.json, ExternalTexts.json, UITexts.jsonc |
| `furniture/`, `clothes/`, `effect/`, `pets/`, `room/` | bundles `.hab` / `.nitro` |
| `icons/`, `sounds/`, `c_images/` | ícones, sons, emblemas e imagens de catálogo |

## Fonte opcional: HabboAssets (API pública)

O `setup.sh` pode mesclar itens do espelho público [HabboAssets](https://www.habboassets.com/) sem necessidade de token:

| O que adiciona | Endpoint | Onde cai em `gamedata/` |
|---|---|---|
| Badges (todos do hotel) | `/api/v2/badges/zip` | `c_images/` (não sobrescreve existentes) |
| Sons (MP3) | `/api/v2/sounds` | `sounds/` (não sobrescreve existentes) |

Ative com `HABBO_ASSETS=1` (e opcionalmente `HABBO_HOTEL_ID=1`) no `.env`, depois rode `./setup.sh` novamente. Demanda rede, então fica desligado por padrão para manter o setup rápido.

Móveis da HabboAssets exigem um token de API (gratuito, criado no site); móveis já vêm do repositório `sphynxkitten/nitro-assets` integrado pelo `setup.sh`.

## Primeiro usuário e admin

Registre uma conta na tela do Octane e dê rank 7 a ela:

```bash
docker compose exec db sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"'
# dentro do cliente SQL:
#   UPDATE users SET `rank` = 7 WHERE username = 'SeuNome';
```

## Dia a dia

```bash
docker compose ps                      # estado e healthchecks
docker compose logs -f polaris
docker compose restart polaris
docker compose down                    # para tudo (dados ficam nos volumes)
docker compose down -v                 # apaga também banco e segredos
```

Backup do banco (o backup automático do Polaris está desligado porque a imagem não tem `mariadb-dump`):

```bash
docker compose exec db sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' > backup.sql
```

Atualizar para versões novas: `git -C polaris-emulator pull`, `git -C Octane pull`, `git -C Octane-Renderer pull`, depois `docker compose build && docker compose up -d`. As migrations rodam sozinhas.

## Acessar de outra máquina da rede

No `.env`: `HOTEL_HOST=<IP da máquina>` e `BIND_ADDR=0.0.0.0`; depois `docker compose up -d`. A configuração do cliente é regerada ao recriar o container.

## O que ficou de fora de propósito

- **Câmera e emblemas de grupo gerados pelo emulador**: precisam de chaves em `emulator_settings` e de uma pasta compartilhada de escrita entre emulador e nginx.
- **HTTPS / domínio / Cloudflare**: no instalador isso é o Traefik. Para produção, ponha um proxy reverso na frente da porta do `client` e do `polaris` (`/ws` e `/api`) e ajuste `ws.whitelist` no banco.
- **CMS** (AtomCMS, EpicNext): a tela de registro/login do próprio Octane já basta para testar.
- A porta do jogo `3000` (TCP legado) não é publicada; o Octane usa só o WebSocket em `2096`.
