.PHONY: help up down logs restart backend-build backend-test backend-dev flutter-test flutter-run clean

COMPOSE_FILE = containers/compose.yaml

help:
	@echo "Comandos disponíveis:"
	@echo "  make up            - Inicia PostgreSQL e Backend via Podman"
	@echo "  make down          - Para todos os containers do Podman"
	@echo "  make logs          - Acompanha logs dos containers Podman"
	@echo "  make restart       - Reinicia os containers Podman"
	@echo "  make backend-build - Compila a API TypeScript"
	@echo "  make backend-test  - Executa a suíte de testes da API"
	@echo "  make backend-dev   - Executa a API localmente com recarga"
	@echo "  make flutter-test  - Executa testes do frontend Flutter"
	@echo "  make flutter-run   - Executa o app Flutter"

up:
	podman compose -f $(COMPOSE_FILE) up -d

down:
	podman compose -f $(COMPOSE_FILE) down

logs:
	podman compose -f $(COMPOSE_FILE) logs -f

restart: down up

backend-build:
	cd backend && npm run build

backend-test:
	cd backend && DATABASE_URL="postgresql://trago:tragopassword@localhost:5432/trago" npm test

backend-dev:
	cd backend && NODE_ENV=development TRAGO_DEMO_AUTH=true npm run dev

flutter-test:
	cd mobile && flutter test

flutter-run:
	cd mobile && flutter run

clean:
	rm -rf backend/dist mobile/build
