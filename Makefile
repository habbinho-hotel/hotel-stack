.PHONY: up local build watch assets logs ps down backup smoke

up:
	./scripts/dev up

local:
	HOTEL_MODE=local ./scripts/dev up

build:
	HOTEL_MODE=local ./scripts/dev build

watch:
	HOTEL_MODE=local ./scripts/dev compose watch --no-up polaris

assets:
	./scripts/dev assets

logs:
	./scripts/dev compose logs -f

ps:
	./scripts/dev compose ps

down:
	./scripts/dev compose down

backup:
	./scripts/dev backup

smoke:
	./scripts/smoke
