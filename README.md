# Ubuntu 22.04 - 26.04 LTS DevOps & Kubernetes Toolbelt Installer

Build a workstation or bastion host with categorized CLI tools for Kubernetes operations, GitOps deployments, secrets management, runtime debugging, observability, and workflow automation.

## Tool Categories

### Kubernetes Core, Packaging & Manifest Tools

| Tool | Description |
|---|---|
| `kubectl` | Official Kubernetes CLI for interacting with clusters |
| `kubeadm` | Kubernetes cluster bootstrap and lifecycle CLI |
| `helm` | Kubernetes package manager for Helm charts |
| `kustomize` | Kubernetes YAML overlay and patch manager |

### Cluster Navigation, Inspection & Efficiency

| Tool | Description |
|---|---|
| `k9s` | Terminal UI for Kubernetes cluster operations |
| `tmux` | Persistent terminal multiplexer for long-running shell sessions |
| `kubectx` / `kubens` | Fast switching between Kubernetes contexts and namespaces |
| `kubie` | Isolated Kubernetes context and namespace shells |
| `kubecolor` | Colorized wrapper for kubectl output |

### Debugging & Observability

| Tool | Description |
|---|---|
| `stern` | Tail logs from multiple Kubernetes pods and containers |
| `crictl` | Debug CRI-compatible container runtimes such as containerd |
| `kubectl-tree` | Kubectl plugin that shows Kubernetes ownerReference trees |
| `kubespy` | Watch Kubernetes resource changes in real time |

### GitOps & Operational Diagnostics

| Tool | Description |
|---|---|
| `argocd` | Argo CD GitOps continuous delivery CLI |
| `k8sgpt` | AI-assisted Kubernetes diagnostics and issue analysis |

### Workflow Automation & Source Control

| Tool | Description |
|---|---|
| `git` | Source control client |
| `make` | Task runner and build automation tool |
| `jq` | JSON query and formatting tool |
| `yq` | YAML/JSON processor |

### Secrets & Security

| Tool | Description |
|---|---|
| `vault` | HashiCorp Vault secrets management CLI |

## Files

```text
devops-kubernetes-toolbelt-recategorized/
├── Makefile
└── scripts/
    └── install-cli-tools.sh
```

## Interactive TUI

```bash
chmod +x scripts/install-cli-tools.sh
./scripts/install-cli-tools.sh
```

Or:

```bash
make menu
```

## Menu Layout

```text
====================================================================
 Ubuntu 22.04 - 26.04 LTS DevOps & Kubernetes Toolbelt Installer
====================================================================

Purpose:
  Build a workstation or bastion host with common CLI tools used for
  Kubernetes operations, GitOps deployments, secrets management,
  YAML/JSON processing, container runtime troubleshooting, and
  terminal productivity.

 1) Install Core Tools       Install argocd vault jq git make k9s helm crictl yq kustomize
 2) Install ALL Tools        Install every tool in category order
 3) Select multiple tools    Install choices like 5,8,10-13
 4) Verify versions          Show installed CLI versions by category

Kubernetes Core, Packaging & Manifest Tools
 5) kubectl                  Official Kubernetes CLI
 6) kubeadm                  Kubernetes cluster bootstrap CLI
 7) Helm                     Kubernetes package manager
 8) Kustomize                Kubernetes YAML overlay manager

Cluster Navigation, Inspection & Efficiency
 9) K9s                      Terminal UI for Kubernetes
10) tmux                     Persistent terminal multiplexer
11) kubectx & kubens         Switch kube contexts and namespaces
12) Kubie                    Isolated kube context shells
13) Kubecolor                Colorized kubectl output wrapper

Debugging & Observability
14) Stern                    Multi-pod log tailing
15) crictl                   Container runtime CRI debug CLI
16) kubectl tree             Show Kubernetes ownership trees
17) kubespy                  Watch Kubernetes resource changes

GitOps & Operational Diagnostics
18) Argo CD CLI              GitOps continuous delivery CLI
19) K8sGPT                   AI-assisted Kubernetes diagnostics

Workflow Automation & Source Control
20) git                      Source control client
21) make                     Task runner/build automation
22) jq                       JSON query and formatting tool
23) yq                       YAML/JSON processor

Secrets & Security
24) Vault CLI                HashiCorp secrets management CLI

 0) Quit                     Exit installer
```

## Install Core Tools Only

Use this option when you want only the compact toolbelt:

```text
argocd
vault
jq
git
make
k9s
helm
crictl
yq
kustomize
```

From the menu:

```text
1) Install Core Tools
```

From Make:

```bash
make core-tools
```

From the script:

```bash
./scripts/install-cli-tools.sh core-tools
```

## Install Everything

```bash
make install
```

Or:

```bash
./scripts/install-cli-tools.sh all
```

The install-all option installs each tool independently. If one tool fails, the script keeps going, prints a final summary, and writes a log file under `/tmp`, for example:

```text
/tmp/devops-toolbelt-install-YYYYMMDD-HHMMSS.log
```

## Multi-Select Install

From the TUI menu, choose option `3` and enter comma-separated selections or ranges:

```text
5,8,10-13
```

You can also type the same list directly at the main prompt:

```text
Select an option [0-24 or list]: 5,8,10-13
```

Ranges expand from left to right. For example:

```text
10-13
```

expands to:

```text
10 11 12 13
```

If option `2` is included in a multi-select list, the script runs the full install once and skips the remaining entries because option `2` already installs every tool.

If option `1` is included in a multi-select list, the script runs the Core Tools install once and skips the duplicate option `1`.

Option `3` is skipped inside multi-select to avoid recursion.

## Install One Tool or Category Item

```bash
# Kubernetes Core, Packaging & Manifest Tools
make kubectl
make kubeadm
make helm
make kustomize

# Cluster Navigation, Inspection & Efficiency
make k9s
make tmux
make kubectx-kubens
make kubie
make kubecolor

# Debugging & Observability
make stern
make crictl
make kubectl-tree
make kubespy

# GitOps & Operational Diagnostics
make argocd
make k8sgpt

# Workflow Automation & Source Control
make git
make make-tool
make jq
make yq

# Secrets & Security
make vault
```

## Verify Installed Tools

```bash
make verify
```

Or:

```bash
./scripts/install-cli-tools.sh verify
```

## Version Overrides

```bash
make kubectl K8S_MINOR_VERSION=v1.34
make kubeadm K8S_MINOR_VERSION=v1.34
make argocd ARGOCD_VERSION=v3.4.2
make helm HELM_VERSION=v3.21.0
make kustomize KUSTOMIZE_VERSION=v5.8.1
make k9s K9S_VERSION=v0.50.18
make kubie KUBIE_VERSION=v0.28.0
make kubecolor KUBECOLOR_VERSION=v0.6.0
make stern STERN_VERSION=v1.34.0
make crictl CRICTL_VERSION=v1.36.0
make kubectl-tree KUBECTL_TREE_VERSION=v0.6.0
make k8sgpt K8SGPT_VERSION=v0.4.33
make yq YQ_VERSION=v4.53.2
make kubespy KUBESPY_VERSION=v0.6.3
```

Default behavior:

```text
K8S_MINOR_VERSION=v1.36
ARGOCD_VERSION=latest
HELM_MAJOR=3
HELM_VERSION=
KUSTOMIZE_VERSION=latest
K9S_VERSION=latest
KUBIE_VERSION=latest
KUBECOLOR_VERSION=latest
KUBECTL_TREE_VERSION=latest
STERN_VERSION=latest
CRICTL_VERSION=latest
K8SGPT_VERSION=latest
YQ_VERSION=latest
KUBESPY_VERSION=latest
```

## If Make Is Not Installed Yet

Run the script directly first:

```bash
chmod +x scripts/install-cli-tools.sh
./scripts/install-cli-tools.sh make
```

Then use:

```bash
make install
```

## Troubleshooting

### Verify exit 141 fix

This bundle avoids piping CLI version output directly into `head -n 1` while `pipefail` is enabled. Some tools print multiple lines and can trigger a harmless SIGPIPE that appears as:

```text
make: *** [Makefile:123: verify] Error 141
```

The verify logic now captures version output first, then prints the first non-empty line safely.


### Kubecolor parser fix

This bundle avoids using `include` as an `awk` variable name because newer `gawk` versions can treat `include` as a reserved/builtin token. The release asset parser now uses `grep`/`sed` instead, which avoids this error:

```text
awk: fatal: cannot use gawk builtin `include' as variable name
```


### Base dependency fix

This bundle uses `gawk` instead of the virtual package name `awk`. On newer Ubuntu releases, `awk` may be listed as a virtual package with no direct installation candidate, which causes this error:

```text
E: Package 'awk' has no installation candidate
```

`gawk` provides the `awk` command and avoids that apt failure.


If a tool shows as `missing`, check whether `/usr/local/bin` is in your `PATH`:

```bash
echo "$PATH"
```

Temporary fix:

```bash
export PATH=/usr/local/bin:$PATH
```

Review the newest installer log:

```bash
ls -lt /tmp/devops-toolbelt-install-*.log | head
less /tmp/devops-toolbelt-install-YYYYMMDD-HHMMSS.log
```

## Install Method Notes

- `kubectl` and `kubeadm` are installed from the official Kubernetes `pkgs.k8s.io` apt repository.
- `helm` is installed with the official Helm installer script.
- `kustomize` is installed from the Kubernetes SIGs GitHub release tarball.
- `k9s`, `kubie`, `kubecolor`, `stern`, `k8sgpt`, `crictl`, `yq`, and `kubespy` are installed from their upstream GitHub releases.
- `kubectl-tree` is installed from the upstream GitHub release asset.
- `kubectx` and `kubens` are installed from the upstream `ahmetb/kubectx` scripts.
- `git`, `make`, `jq`, and `tmux` are installed from Ubuntu apt packages.
- `vault` is installed from the HashiCorp apt repository.
