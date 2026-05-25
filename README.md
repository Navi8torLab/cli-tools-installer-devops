# Ubuntu 22.04 DevOps & Kubernetes Toolbelt Installer

Build a workstation or bastion host with common CLI tools used for Kubernetes operations, GitOps deployments, secrets management, YAML/JSON processing, container runtime troubleshooting, and terminal productivity.

## Tool list

| Tool | Description |
|---|---|
| `argocd` | GitOps continuous delivery CLI for Argo CD |
| `vault` | HashiCorp secrets management CLI |
| `jq` | JSON query and formatting tool |
| `git` | Source control client |
| `make` | Task runner and build automation tool |
| `tmux` | Persistent terminal multiplexer for long-running shell sessions |
| `k9s` | Terminal UI for Kubernetes cluster operations |
| `helm` | Kubernetes package manager for Helm charts |
| `crictl` | CLI for debugging CRI-compatible container runtimes such as containerd |
| `yq` | YAML/JSON processor |
| `kustomize` | Kubernetes YAML overlay and patch manager |

## Files

```text
cli-tools-installer-devops-toolbelt-tmux-kustomize/
├── Makefile
└── scripts/
    └── install-cli-tools.sh
```

## Interactive colored TUI menu

```bash
chmod +x scripts/install-cli-tools.sh
./scripts/install-cli-tools.sh
```

Or with Make:

```bash
make menu
```

Menu layout:

```text
====================================================================
 Ubuntu 22.04 DevOps & Kubernetes Toolbelt Installer
====================================================================

Purpose:
  Build a workstation or bastion host with common CLI tools used for
  Kubernetes operations, GitOps deployments, secrets management,
  YAML/JSON processing, container runtime troubleshooting, and
  terminal productivity.

How to use this menu:
  • Select one tool to install it individually.
  • Select option 1 to install the full DevOps toolbelt.
  • Select Verify versions after installation.
  • Use the version override variables below when pinning releases.

 1) Install ALL tools        Install every CLI listed below
 2) Argo CD CLI              GitOps continuous delivery CLI
 3) Vault CLI                HashiCorp secrets management CLI
 4) jq                       JSON query and formatting tool
 5) git                      Source control client
 6) make                     Task runner/build automation
 7) tmux                     Persistent terminal multiplexer
 8) k9s                      Terminal UI for Kubernetes
 9) Helm CLI                 Kubernetes package manager
10) crictl                   Container runtime CRI debug CLI
11) yq                       YAML/JSON processor
12) Kustomize                Kubernetes YAML overlay manager
13) Verify versions          Show installed CLI versions
 0) Quit                     Exit installer
```

## Install everything

```bash
make install
```

Equivalent direct script command:

```bash
./scripts/install-cli-tools.sh all
```

The install-all option now installs each tool independently. If one tool fails, the script keeps going, prints a final install summary, and writes a log file under `/tmp`, for example:

```text
/tmp/devops-toolbelt-install-YYYYMMDD-HHMMSS.log
```

## Install one tool at a time

```bash
make argocd
make vault
make jq
make git
make make-tool
make tmux
make k9s
make helm
make crictl
make yq
make kustomize
```

Equivalent direct script commands:

```bash
./scripts/install-cli-tools.sh argocd
./scripts/install-cli-tools.sh vault
./scripts/install-cli-tools.sh jq
./scripts/install-cli-tools.sh git
./scripts/install-cli-tools.sh make
./scripts/install-cli-tools.sh tmux
./scripts/install-cli-tools.sh k9s
./scripts/install-cli-tools.sh helm
./scripts/install-cli-tools.sh crictl
./scripts/install-cli-tools.sh yq
./scripts/install-cli-tools.sh kustomize
```

## Verify installed tools

```bash
make verify
```

Or:

```bash
./scripts/install-cli-tools.sh verify
```

## Version overrides

Install a specific Argo CD CLI version:

```bash
make argocd ARGOCD_VERSION=v3.2.0
```

Install a specific k9s version:

```bash
make k9s K9S_VERSION=v0.50.9
```

Install a specific Helm 3 version:

```bash
make helm HELM_MAJOR=3 HELM_VERSION=v3.19.0
```

Install a specific crictl version:

```bash
make crictl CRICTL_VERSION=v1.34.0
```

Install a specific yq version:

```bash
make yq YQ_VERSION=v4.48.1
```

Install a specific Kustomize version:

```bash
make kustomize KUSTOMIZE_VERSION=v5.8.1
```

Default behavior:

```text
ARGOCD_VERSION=latest
K9S_VERSION=latest
HELM_MAJOR=3
HELM_VERSION=
CRICTL_VERSION=latest
YQ_VERSION=latest
KUSTOMIZE_VERSION=latest
```

## If Make is not installed yet

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

If a tool still shows as `missing`, check whether `/usr/local/bin` is in your PATH:

```bash
echo "$PATH"
command -v argocd vault helm crictl yq kustomize
```

Temporary PATH fix:

```bash
export PATH=/usr/local/bin:$PATH
```

If only Kustomize fails, install it again directly with:

```bash
make kustomize
```

Or pin a known Kustomize release:

```bash
make kustomize KUSTOMIZE_VERSION=v5.8.1
```

Review the installer log:

```bash
ls -lt /tmp/devops-toolbelt-install-*.log | head
```

Then open the newest log:

```bash
less /tmp/devops-toolbelt-install-YYYYMMDD-HHMMSS.log
```

## Install method notes

- `jq`, `git`, `make`, and `tmux` are installed using Ubuntu apt packages.
- Vault is installed using the HashiCorp apt repository.
- Argo CD CLI is installed from the official GitHub release binary.
- k9s is installed from the official GitHub `.deb` release asset.
- Helm is installed using the official Helm install script.
- crictl is installed from the Kubernetes SIGs `cri-tools` GitHub release tarball.
- yq is installed from the `mikefarah/yq` GitHub release binary.
- Kustomize is installed from the Kubernetes SIGs `kustomize` GitHub release tarball.


## Kustomize installer fix

Kustomize latest-release detection is pipe-safe in this bundle. The script first writes the GitHub releases response to a temporary file, then parses the newest `kustomize/v*` release from that file. This avoids the `curl: (23) Failure writing output to destination` error that can happen when `grep -m1` or `head` closes a pipe early while `pipefail` is enabled.

To install only Kustomize:

```bash
make kustomize
```

To pin a known Kustomize version:

```bash
make kustomize KUSTOMIZE_VERSION=v5.8.1
```
