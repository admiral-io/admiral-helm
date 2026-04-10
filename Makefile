.PHONY: dev dev-down deps lint docs schema

## dev: Create a KinD cluster and install Admiral with demo values
dev:
	./scripts/demo.sh

## dev-down: Delete the KinD cluster
dev-down:
	kind delete cluster --name admiral

## deps: Build Helm chart dependencies
deps:
	helm dependency build charts/admiral

## lint: Run chart linting
lint:
	./scripts/lint.sh

## docs: Generate chart documentation
docs:
	./scripts/helm-docs.sh

## schema: Generate values JSON schema
schema:
	./scripts/gen-schema.sh

## template: Render chart templates locally (for debugging)
template:
	helm template admiral charts/admiral

## template-kind: Render chart templates with KinD values
template-kind:
	helm template admiral charts/admiral -f values/kind.yaml
