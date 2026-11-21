# Habbinho Hotel

Este repositório reúne o Octane, o Polaris e o pack de gamedata para desenvolvimento e deploy. O `release.env` fixa a combinação testada por digest de imagem e SHA-256 do pack. As imagens saem dos repositórios do client e do emulador.

## Subir a release

Use Linux ou WSL com Docker Compose 2.24.4 ou superior, Make, curl, OpenSSL, Python 3 e as ferramentas GNU `flock` e `sha256sum`. Rode os comandos na raiz do `hotel-stack`.

```sh
make up
make smoke
```

Abra http://localhost:8080. O script cria `.env.hotel` com senhas locais, verifica o pack e reutiliza o cache nas próximas subidas. Os volumes guardam o banco, as chaves do Polaris e as do Caddy. Use `make ps`, `make logs` e `make down` para operar a stack.

O manifesto vem vazio até a primeira publicação revisada. Nesse intervalo, use o fluxo de fontes abaixo. O projeto Compose anterior continua em [`docker-compose.yml`](docker-compose.yml) com o [guia legado](docs/legacy.md). Seus checkouts aninhados, `.env` e volumes ficam separados do novo fluxo.

## Trabalhar nas fontes

Clone os quatro repositórios em diretórios irmãos.

```text
habbinho-hotel/
├── hotel-stack/
├── habbinho-client/
├── habbinho-emulator/
└── hotel-gamedata/
```

A partir do `hotel-stack`, aponte para um pack já extraído que você tem autorização para usar. Mantenha `GAMEDATA_DIR` no ambiente da sessão para os demais comandos.

```sh
export GAMEDATA_DIR=/caminho/do/pack-revisado
make local
HOTEL_MODE=local make logs
make watch  # recompila e recria só o Polaris ao alterar o código Java
```

`make build` constrói as duas imagens locais. Use `./scripts/dev compose` para os subcomandos do Compose e `HOTEL_MODE=local` para selecionar os containers das fontes. Se o hotel legado estiver usando a porta 8080, crie um arquivo a partir de `.env.runtime.example`, gere senhas próprias e ajuste `HTTP_BIND`, `PUBLIC_URL` e `PUBLIC_WS_URL` para outra porta. Passe o caminho em `HOTEL_ENV_FILE`. Use `make smoke` na porta padrão ou `./scripts/smoke http://localhost:8081` na outra porta.

Para HMR, [siga o README do client](https://github.com/habbinho-hotel/habbinho-client). Use Vite na porta 5173, encaminhe a API para `http://127.0.0.1:8080` e configure o WebSocket do jogo como `ws://localhost:8080/ws`. A API e o WS chegam ao Polaris via Caddy. O Java usa JDK 25 e Maven Wrapper. Consulte o README do emulador para os testes de código e o harness de integração.

Para sincronizar o fork do Polaris, adicione `https://github.com/duckietm/Polaris-Emulator.git` como remoto `upstream` uma vez. Em clone raso, obtenha o histórico com `git fetch --unshallow origin`. Faça `git fetch upstream` e `git merge upstream/main` numa branch de integração, rode `./mvnw -B verify` em `Emulator/` e promova por PR.

## Promover uma combinação

1. Depois da CI dos componentes, publique as imagens `linux/amd64` e `linux/arm64` com tags `image-vX.Y.Z`. Confira os digests dos índices multiarch no GHCR. Revise as licenças dos arquivos embarcados antes de publicar a imagem web.
2. Gere o pacote com o [empacotador do gamedata](https://github.com/habbinho-hotel/hotel-gamedata) a partir de um diretório de staging revisado. Publique `gamedata.tar.gz` numa Release imutável, com o SHA-256. O pacote precisa ser autorizado para uso e redistribuição. O snapshot histórico requer auditoria antes de qualquer publicação nova.
3. Abra um PR atualizando `release.env`. Use `ghcr.io/habbinho-hotel/habbinho-client:image-vX.Y.Z@sha256:…` e o equivalente do emulador. Use uma versão nova de gamedata a cada alteração de bytes.
4. Rode o smoke e confira no navegador cadastro ou login, entrada em quarto, avatar, inventário e requests de assets. Valide migrations em banco vazio e numa cópia do banco anterior. Use como referências os contratos em `habbinho-emulator/protocol/`, `client.release.allowed` no banco e a configuração do Octane. Marque o commit do stack com uma tag depois da validação. A CI no stack cobre API, configuração, assets e handshake WS.

Mantenha o release anterior disponível para rollback. Configure revalidação de cache em `/gamedata/` e troque para URLs versionadas antes de habilitar cache imutável.

## Deploy do MVP

Use uma VM Linux com disco persistente, Docker e DNS do domínio apontado para o host. A primeira opção é uma OCI Ampere A1, se houver capacidade na região e as imagens tiverem sido testadas em ARM. Um VPS pode usar o mesmo Compose. Mantenha a instância ligada para evitar depender de um mecanismo separado de despertar sob demanda.

Crie `/etc/habbinho/prod.env` com permissão `0600`. Defina `DB_PASSWORD` e `DB_ROOT_PASSWORD` com senhas fortes exclusivas e ajuste o domínio e as URLs.

```dotenv
HOTEL_SITE=hotel.exemplo
PUBLIC_URL=https://hotel.exemplo
PUBLIC_WS_URL=wss://hotel.exemplo/ws
```

Fixe também `MARIADB_IMAGE` e `CADDY_IMAGE` por digest nesse arquivo. Configure portas 80 e 443 para o Caddy, que obtém e renova TLS. O client e o emulador compartilham a mesma origem via `/api` e `/ws`. Banco e Polaris ficam na rede do Compose.

Na primeira subida, prepare os serviços internos antes de expor o Caddy.

```sh
export HOTEL_MODE=prod HOTEL_ENV_FILE=/etc/habbinho/prod.env
./scripts/dev up db polaris client
./scripts/dev compose exec db mariadb -u polaris -p habbo
```

No MariaDB, configure a origem autorizada com o hostname real, sem esquema ou porta. Cadastre o IP interno fixo do Caddy para o Polaris conseguir distinguir jogadores atrás do proxy.

```sql
INSERT INTO emulator_settings (`key`, `value`) VALUES
  ('ws.whitelist', 'hotel.exemplo'),
  ('ws.ip.header', 'X-Forwarded-For'),
  ('ws.ip.header.trusted', '172.30.89.2')
ON DUPLICATE KEY UPDATE `value` = VALUES(`value`);
```

Se a sub-rede se sobrepuser a uma rede da VM, ajuste `HOTEL_SUBNET`, `HOTEL_DYNAMIC_RANGE` e `HOTEL_PROXY_IP` no `prod.env` antes da primeira subida. Reserve o IP do Caddy fora da faixa dinâmica do Compose e use o IP escolhido no SQL. Reinicie o Polaris, suba o edge e rode o smoke.

```sh
./scripts/dev compose restart polaris
make up
./scripts/smoke https://hotel.exemplo
```

Inclua os volumes `db-data` e `polaris-data` no disco persistente. Após parada da JVM, os sockets, as sessões em RAM e gravações pendentes se perdem. O banco e as chaves sobrevivem enquanto os volumes existirem. Habilite fotos e emblemas gerados só após provisionar armazenamento gravável específico e incluí-lo no backup.

### Backup e recuperação

Rode `make backup` no modo do ambiente desejado. Ele gera um dump consistente, com lock das tabelas para cobrir MyISAM, em `.backups/`. Antes de migrations em produção, pare o Polaris e quaisquer outros escritores. Proteja o `prod.env` e faça uma cópia criptografada de `/data` do Polaris, que contém as chaves usadas pela instalação. Guarde os backups fora da VM.

Ensaie o restore num projeto Compose separado. Selecione o projeto de destino em `HOTEL_PROJECT_NAME` e confirme que seu banco `habbo` está vazio. Recupere as chaves no volume de destino com dono UID/GID 1000 e permissão `0600` para `secrets.env` antes de iniciar o Polaris.

```sh
./scripts/dev up db
./scripts/dev compose exec -T db sh -c 'MYSQL_PWD="$MARIADB_ROOT_PASSWORD" exec mariadb -uroot "$MARIADB_DATABASE"' < /caminho/do/backup.sql
```

Se o schema continua compatível após um deploy, reaplique a tag anterior. Para migration incompatível, recupere o backup pré-deploy num banco limpo, com a release correspondente. Gravações posteriores ao backup precisam de tratamento separado.

Guarde o token de acesso a imagens privadas no host com permissão de leitura do pacote. O CI publica com `GITHUB_TOKEN`. Revogue o token HabboAssets que já foi rastreado no client e rotacione credenciais de banco reutilizadas. Para banco existente, altere a senha no próprio MariaDB e no arquivo de ambiente.
