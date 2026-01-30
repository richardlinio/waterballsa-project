.PHONY: swagger
swagger:
	npx @apidevtools/swagger-cli bundle docs/api-docs/swagger.yaml -o docs/api-docs/bundled-swagger.yaml -t yaml
	@echo "✓ Bundled swagger file generated at docs/api-docs/bundled-swagger.yaml"

.PHONY: up
up:
	docker compose up -d

.PHONY: build
build:
	docker compose build --no-cache

.PHONY: down
down:
	docker compose down -v
