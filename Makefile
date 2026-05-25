SHELL := /bin/bash

SCRIPT := scripts/install-cli-tools.sh

ARGOCD_VERSION ?= latest
K9S_VERSION ?= latest
HELM_MAJOR ?= 3
HELM_VERSION ?=
CRICTL_VERSION ?= latest
YQ_VERSION ?= latest
KUSTOMIZE_VERSION ?= latest

export ARGOCD_VERSION
export K9S_VERSION
export HELM_MAJOR
export HELM_VERSION
export CRICTL_VERSION
export YQ_VERSION
export KUSTOMIZE_VERSION

.DEFAULT_GOAL := help

.PHONY: help chmod menu install all argocd vault jq git make make-tool tmux k9s helm crictl yq kustomize verify bootstrap

help:
	@echo "Ubuntu 22.04 DevOps Toolbelt Installer"
	@echo "DevOps/Kubernetes tools for building, deploying, debugging, and operating cloud-native infrastructure."
	@echo
	@echo "Interactive:"
	@echo "  make menu"
	@echo
	@echo "Install all:"
	@echo "  make install"
	@echo
	@echo "Install one tool:"
	@echo "  make argocd       # GitOps continuous delivery CLI"
	@echo "  make vault        # HashiCorp secrets management CLI"
	@echo "  make jq           # JSON query and formatting tool"
	@echo "  make git          # Source control client"
	@echo "  make make-tool    # Task runner/build automation"
	@echo "  make tmux         # Persistent terminal multiplexer"
	@echo "  make k9s          # Terminal UI for Kubernetes"
	@echo "  make helm         # Kubernetes package manager"
	@echo "  make crictl       # Container runtime CRI debug CLI"
	@echo "  make yq           # YAML/JSON processor"
	@echo "  make kustomize    # Kubernetes YAML overlay manager"
	@echo
	@echo "Verify:"
	@echo "  make verify"
	@echo
	@echo "Version examples:"
	@echo "  make argocd ARGOCD_VERSION=v3.2.0"
	@echo "  make k9s K9S_VERSION=v0.50.9"
	@echo "  make helm HELM_MAJOR=3 HELM_VERSION=v3.19.0"
	@echo "  make crictl CRICTL_VERSION=v1.34.0"
	@echo "  make yq YQ_VERSION=v4.48.1"
	@echo "  make kustomize KUSTOMIZE_VERSION=v5.8.1"
	@echo
	@echo "If GNU Make is not installed yet:"
	@echo "  chmod +x scripts/install-cli-tools.sh"
	@echo "  ./scripts/install-cli-tools.sh make"

chmod:
	@chmod +x $(SCRIPT)

menu: chmod
	@$(SCRIPT) menu

install: all

all: chmod
	@$(SCRIPT) all

argocd: chmod
	@$(SCRIPT) argocd

vault: chmod
	@$(SCRIPT) vault

jq: chmod
	@$(SCRIPT) jq

git: chmod
	@$(SCRIPT) git

make: make-tool

make-tool: chmod
	@$(SCRIPT) make

tmux: chmod
	@$(SCRIPT) tmux

k9s: chmod
	@$(SCRIPT) k9s

helm: chmod
	@$(SCRIPT) helm

crictl: chmod
	@$(SCRIPT) crictl

yq: chmod
	@$(SCRIPT) yq

kustomize: chmod
	@$(SCRIPT) kustomize

verify: chmod
	@$(SCRIPT) verify

bootstrap:
	@sudo apt-get update -y
	@sudo apt-get install -y make
