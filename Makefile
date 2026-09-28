# Use bash as the shell, with environment lookup
SHELL := /usr/bin/env bash

.DEFAULT_GOAL := all

MAKEFLAGS += --no-print-directory --silent

PROJECT_ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: all # Generate chart docs and schema (default target).
all: docs schema

.PHONY: help # Print this help message.
help:
	@grep -E '^\.PHONY: [a-zA-Z_-]+ .*?# .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = "(: |#)"}; {printf "%-30s %s\n", $$2, $$3}'

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
	helm template admiral-k8s-agent charts/admiral-k8s-agent \
		--set admiral.server=admiral.example.com:443 --set admiral.clusterId=00000000-0000-0000-0000-000000000000
