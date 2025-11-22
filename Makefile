.PHONY: swagger
swagger:
	npx @apidevtools/swagger-cli bundle docs/api-docs/swagger.yaml -o docs/api-docs/bundled-swagger.yaml -t yaml
	@echo "✓ Bundled swagger file generated at docs/api-docs/bundled-swagger.yaml"
