# Atajos para desarrollo. Requiere Node 22+ y Flutter estable.
API ?= http://10.0.2.2:8080

.PHONY: setup bff app test test-bff test-app e2e hooks chaos-normal chaos-latency chaos-outage-home campaign

setup: hooks ## Instala dependencias y genera plataformas
	cd bff && npm ci
	cd app && ./tool/setup_platforms.sh

hooks: ## Activa el hook de Conventional Commits
	git config core.hooksPath tool/hooks

bff: ## Levanta el BFF en :8080
	cd bff && PUBLIC_BASE_URL=$(API) npm run dev

app: ## Ejecuta la app apuntando al BFF local
	cd app && flutter run --dart-define=API_BASE_URL=$(API)

test: test-bff test-app

test-bff:
	cd bff && npm test

test-app:
	cd app && flutter analyze && flutter test

e2e: ## Requiere BFF corriendo y emulador abierto
	cd app && flutter test integration_test --dart-define=API_BASE_URL=$(API)

# --- Demostración de escenarios degradados (también disponibles en la app: Perfil → Diagnóstico)
chaos-normal:
	curl -s -X DELETE localhost:8080/v1/admin/chaos -H 'X-Admin-Key: dev-admin-key'; echo
chaos-latency:
	curl -s -X PUT localhost:8080/v1/admin/chaos -H 'X-Admin-Key: dev-admin-key' -H 'content-type: application/json' -d '{"enabled":true,"latencyMs":3000,"jitterMs":1000}'; echo
chaos-outage-home:
	curl -s -X PUT localhost:8080/v1/admin/chaos -H 'X-Admin-Key: dev-admin-key' -H 'content-type: application/json' -d '{"enabled":true,"outages":["experience"]}'; echo
campaign: ## Publica un banner nuevo para el segmento joven SIN publicar la app
	curl -s -X POST localhost:8080/v1/admin/campaigns -H 'X-Admin-Key: dev-admin-key' -H 'content-type: application/json' \
	  -d '{"title":"Cashback de octubre","body":"5% de vuelta en tus compras con tarjeta de débito.","segments":["joven"],"priority":99,"ctaLabel":"Pregúntale al asistente","ctaDeeplink":"/assistant"}'; echo
