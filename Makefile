SHELL := /bin/bash

SCRIPT := scripts/install-cli-tools.sh

K8S_MINOR_VERSION ?= v1.36
ARGOCD_VERSION ?= latest
HELM_MAJOR ?= 3
HELM_VERSION ?=
KUSTOMIZE_VERSION ?= latest
K9S_VERSION ?= latest
KUBIE_VERSION ?= latest
KUBECOLOR_VERSION ?= latest
KUBECTL_TREE_VERSION ?= latest
STERN_VERSION ?= latest
CRICTL_VERSION ?= latest
K8SGPT_VERSION ?= latest
YQ_VERSION ?= latest
KUBESPY_VERSION ?= latest

export K8S_MINOR_VERSION
export ARGOCD_VERSION
export HELM_MAJOR
export HELM_VERSION
export KUSTOMIZE_VERSION
export K9S_VERSION
export KUBIE_VERSION
export KUBECOLOR_VERSION
export KUBECTL_TREE_VERSION
export STERN_VERSION
export CRICTL_VERSION
export K8SGPT_VERSION
export YQ_VERSION
export KUBESPY_VERSION

.DEFAULT_GOAL := help

.PHONY: help chmod menu install all core-tools verify \
	kubectl kubeadm helm kustomize \
	k9s tmux kubectx-kubens kubectx kubens kubie kubecolor \
	stern crictl kubectl-tree \
	argocd k8sgpt \
	git make make-tool jq yq \
	vault kubespy bootstrap

help:
	@echo "Ubuntu 22.04 - 26.04 LTS DevOps & Kubernetes Toolbelt Installer"
	@echo "Build a workstation or bastion host with categorized CLI tools for Kubernetes operations,"
	@echo "GitOps deployments, secrets management, runtime debugging, and workflow automation."
	@echo
	@echo "Interactive:"
	@echo "  make menu"
	@echo "  In the menu, choose option 3 or type a list such as: 5,8,10-13"
	@echo
	@echo "Install options:"
	@echo "  make core-tools       # argocd vault jq git make k9s helm crictl yq kustomize"
	@echo "  make install          # install every tool"
	@echo
	@echo "Kubernetes Core, Packaging & Manifest Tools:"
	@echo "  make kubectl          # Official Kubernetes CLI"
	@echo "  make kubeadm          # Kubernetes cluster bootstrap CLI"
	@echo "  make helm             # Kubernetes package manager"
	@echo "  make kustomize        # Kubernetes YAML overlay manager"
	@echo
	@echo "Cluster Navigation, Inspection & Efficiency:"
	@echo "  make k9s              # Terminal UI for Kubernetes"
	@echo "  make tmux             # Persistent terminal multiplexer"
	@echo "  make kubectx-kubens   # Switch kube contexts and namespaces"
	@echo "  make kubie            # Isolated kube context shells"
	@echo "  make kubecolor        # Colorized kubectl output wrapper"
	@echo
	@echo "Debugging & Observability:"
	@echo "  make stern            # Multi-pod log tailing"
	@echo "  make crictl           # Container runtime CRI debug CLI"
	@echo "  make kubectl-tree     # Show Kubernetes ownership trees"
	@echo "  make kubespy          # Watch Kubernetes resource changes"
	@echo
	@echo "GitOps & Operational Diagnostics:"
	@echo "  make argocd           # GitOps continuous delivery CLI"
	@echo "  make k8sgpt           # AI-assisted Kubernetes diagnostics"
	@echo
	@echo "Workflow Automation & Source Control:"
	@echo "  make git              # Source control client"
	@echo "  make make-tool        # Task runner/build automation"
	@echo "  make jq               # JSON query and formatting tool"
	@echo "  make yq               # YAML/JSON processor"
	@echo
	@echo "Secrets & Security:"
	@echo "  make vault            # HashiCorp secrets management CLI"
	@echo
	@echo "Verify:"
	@echo "  make verify"
	@echo
	@echo "Version examples:"
	@echo "  make kubectl K8S_MINOR_VERSION=v1.34"
	@echo "  make kubeadm K8S_MINOR_VERSION=v1.34"
	@echo "  make argocd ARGOCD_VERSION=v3.4.2"
	@echo "  make helm HELM_VERSION=v3.21.0"
	@echo "  make kustomize KUSTOMIZE_VERSION=v5.8.1"
	@echo "  make k9s K9S_VERSION=v0.50.18"
	@echo "  make kubie KUBIE_VERSION=v0.28.0"
	@echo "  make kubecolor KUBECOLOR_VERSION=v0.6.0"
	@echo "  make stern STERN_VERSION=v1.34.0"
	@echo "  make crictl CRICTL_VERSION=v1.36.0"
	@echo "  make kubectl-tree KUBECTL_TREE_VERSION=v0.6.0"
	@echo "  make k8sgpt K8SGPT_VERSION=v0.4.33"
	@echo "  make yq YQ_VERSION=v4.53.2"
	@echo "  make kubespy KUBESPY_VERSION=v0.6.3"
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

core-tools: chmod
	@$(SCRIPT) core-tools

verify: chmod
	@$(SCRIPT) verify

kubectl: chmod
	@$(SCRIPT) kubectl

kubeadm: chmod
	@$(SCRIPT) kubeadm

helm: chmod
	@$(SCRIPT) helm

kustomize: chmod
	@$(SCRIPT) kustomize

k9s: chmod
	@$(SCRIPT) k9s

tmux: chmod
	@$(SCRIPT) tmux

kubectx-kubens: chmod
	@$(SCRIPT) kubectx-kubens

kubectx: kubectx-kubens

kubens: kubectx-kubens

kubie: chmod
	@$(SCRIPT) kubie

kubecolor: chmod
	@$(SCRIPT) kubecolor

stern: chmod
	@$(SCRIPT) stern

crictl: chmod
	@$(SCRIPT) crictl

kubectl-tree: chmod
	@$(SCRIPT) kubectl-tree

argocd: chmod
	@$(SCRIPT) argocd

k8sgpt: chmod
	@$(SCRIPT) k8sgpt

git: chmod
	@$(SCRIPT) git

make: make-tool

make-tool: chmod
	@$(SCRIPT) make

jq: chmod
	@$(SCRIPT) jq

yq: chmod
	@$(SCRIPT) yq

vault: chmod
	@$(SCRIPT) vault

kubespy: chmod
	@$(SCRIPT) kubespy

bootstrap:
	@sudo apt-get update -y
	@sudo apt-get install -y make
