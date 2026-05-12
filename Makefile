# Use bash as the shell, with environment lookup
SHELL := /usr/bin/env bash

.DEFAULT_GOAL := all

MAKEFLAGS += --no-print-directory --silent

PROJECT_ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: all # Build chart dependencies, docs, and schema (default target).
all: deps docs schema

.PHONY: help # Print this help message.
help:
	@grep -E '^\.PHONY: [a-zA-Z_-]+ .*?# .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = "(: |#)"}; {printf "%-30s %s\n", $$2, $$3}'

.PHONY: dev # Create a KinD cluster and install Admiral with demo values.
dev:
	./scripts/demo.sh

.PHONY: dev-down # Delete the KinD cluster.
dev-down:
	kind delete cluster --name admiral

.PHONY: deps # Build Helm chart dependencies.
deps:
	helm dependency build charts/admiral

.PHONY: lint # Run chart linting.
lint:
	./scripts/lint.sh

.PHONY: docs # Generate chart documentation.
docs:
	./scripts/helm-docs.sh

.PHONY: schema # Generate values JSON schema.
schema:
	./scripts/gen-schema.sh

.PHONY: template # Render chart templates locally (for debugging).
template:
	helm template admiral charts/admiral

.PHONY: template-kind # Render chart templates with KinD values.
template-kind:
	helm template admiral charts/admiral -f values/kind.yaml
