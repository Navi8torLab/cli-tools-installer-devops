#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu 22.04 - 26.04 LTS DevOps & Kubernetes Toolbelt Installer
# Build a workstation or bastion host with common CLI tools used for Kubernetes operations,
# GitOps deployments, secrets management, YAML/JSON processing, container runtime troubleshooting,
# and terminal productivity.

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
LOG_FILE="${LOG_FILE:-/tmp/devops-toolbelt-install-$(date +%Y%m%d-%H%M%S).log}"

# Version overrides
K8S_MINOR_VERSION="${K8S_MINOR_VERSION:-v1.36}"       # Kubernetes apt repo minor, example: v1.34, v1.35, v1.36
ARGOCD_VERSION="${ARGOCD_VERSION:-latest}"           # Example: v3.4.2 or latest
HELM_MAJOR="${HELM_MAJOR:-3}"                        # Default: Helm 3
HELM_VERSION="${HELM_VERSION:-}"                     # Example: v3.21.0. Empty = latest for HELM_MAJOR
KUSTOMIZE_VERSION="${KUSTOMIZE_VERSION:-latest}"     # Example: v5.8.1, 5.8.1, or latest
K9S_VERSION="${K9S_VERSION:-latest}"                 # Example: v0.50.18 or latest
KUBIE_VERSION="${KUBIE_VERSION:-latest}"             # Example: v0.28.0 or latest
KUBECOLOR_VERSION="${KUBECOLOR_VERSION:-latest}"     # Example: v0.6.0 or latest
KUBECTL_TREE_VERSION="${KUBECTL_TREE_VERSION:-latest}" # Example: v0.6.0 or latest
STERN_VERSION="${STERN_VERSION:-latest}"             # Example: v1.34.0 or latest
CRICTL_VERSION="${CRICTL_VERSION:-latest}"           # Example: v1.36.0 or latest
K8SGPT_VERSION="${K8SGPT_VERSION:-latest}"           # Example: v0.4.33 or latest
YQ_VERSION="${YQ_VERSION:-latest}"                   # Example: v4.53.2 or latest
KUBESPY_VERSION="${KUBESPY_VERSION:-latest}"         # Example: v0.6.3 or latest

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  SUDO="sudo"
fi

APT_UPDATED=0

# ---------- Colors ----------
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  RESET="$(tput sgr0)"
  BOLD="$(tput bold)"
  DIM="$(tput dim)"
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"
  CYAN="$(tput setaf 6)"
else
  RESET=""
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  MAGENTA=""
  CYAN=""
fi

info()    { echo -e "${BLUE}==>${RESET} $*" | tee -a "${LOG_FILE}"; }
success() { echo -e "${GREEN}✔${RESET} $*" | tee -a "${LOG_FILE}"; }
warn()    { echo -e "${YELLOW}WARN:${RESET} $*" | tee -a "${LOG_FILE}"; }
error()   { echo -e "${RED}ERROR:${RESET} $*" | tee -a "${LOG_FILE}" >&2; }
die()     { error "$*"; exit 1; }

pause_menu() {
  if [[ -t 0 ]]; then
    echo
    read -r -p "Press Enter to continue..." _
  fi
}

run() {
  echo -e "${MAGENTA}+${RESET} $*" | tee -a "${LOG_FILE}"
  "$@" 2>&1 | tee -a "${LOG_FILE}"
  return "${PIPESTATUS[0]}"
}

# ---------- Helpers ----------
preflight() {
  touch "${LOG_FILE}" 2>/dev/null || die "Cannot write log file: ${LOG_FILE}"

  if [[ "${EUID}" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    die "sudo is required when not running as root. Install sudo or run this script as root."
  fi

  if [[ ":${PATH}:" != *":/usr/local/bin:"* ]]; then
    warn "/usr/local/bin is not in PATH. Tools installed there may verify as missing until PATH is updated."
    warn "Temporary fix: export PATH=/usr/local/bin:\$PATH"
  fi
}

detect_ubuntu() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
      warn "This script was built for Ubuntu 22.04 - 26.04 LTS. Detected: ${PRETTY_NAME:-unknown Linux}."
    fi
  else
    warn "Cannot read /etc/os-release. Continuing anyway."
  fi
}

get_arch() {
  local arch
  arch="$(dpkg --print-architecture)"
  case "${arch}" in
    amd64) echo "amd64" ;;
    arm64) echo "arm64" ;;
    *) die "Unsupported architecture: ${arch}. Supported: amd64, arm64." ;;
  esac
}

get_kubie_arch_pattern() {
  local arch
  arch="$(dpkg --print-architecture)"
  case "${arch}" in
    amd64) echo "linux.*(amd64|x86_64|x86-64)" ;;
    arm64) echo "linux.*(arm64|aarch64)" ;;
    *) die "Unsupported architecture: ${arch}. Supported: amd64, arm64." ;;
  esac
}

latest_github_tag() {
  local repo="$1"
  local effective_url
  effective_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest")"
  echo "${effective_url}" | sed -E 's#^.*/tag/([^/?#]+).*$#\1#'
}

download_github_release_json() {
  local repo="$1"
  local version="$2"
  local output="$3"

  if [[ "${version}" == "latest" ]]; then
    run curl -fsSL -o "${output}" "https://api.github.com/repos/${repo}/releases/latest"
  else
    run curl -fsSL -o "${output}" "https://api.github.com/repos/${repo}/releases/tags/${version}"
  fi
}

extract_first_release_asset_url() {
  local json_file="$1"
  local include_regex="$2"
  local exclude_regex="${3:-(__never_match__)}"

  grep '"browser_download_url":' "${json_file}" \
    | sed -E 's/.*"browser_download_url": "([^"]+)".*/\1/' \
    | grep -Ei "${include_regex}" \
    | grep -Evi "${exclude_regex}" \
    | awk 'NR==1 {print; exit}'
}

extract_release_asset_url_awk() {
  local json_file="$1"
  local include_regex="$2"
  local exclude_regex="${3:-$^}"

  awk -v asset_include_regex="${include_regex}" -v exclude="${exclude_regex}" -F'"' '
    /"browser_download_url":/ {
      url=$4
      low=tolower(url)
      if (low ~ tolower(asset_include_regex) && low !~ tolower(exclude)) {
        print url
        exit
      }
    }
  ' "${json_file}"
}


apt_update_once() {
  if [[ "${APT_UPDATED}" -eq 0 ]]; then
    info "Updating apt package index"
    run ${SUDO} apt-get update -y
    APT_UPDATED=1
  fi
}

install_base_packages() {
  apt_update_once
  info "Installing base dependencies"
  run ${SUDO} apt-get install -y \
    bash \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    apt-transport-https \
    unzip \
    tar \
    gzip \
    openssl \
    gawk \
    sed \
    grep \
    coreutils
}

install_apt_package() {
  local pkg="$1"
  local cmd="${2:-$1}"

  install_base_packages
  info "Installing ${pkg} via apt"
  run ${SUDO} apt-get install -y "${pkg}"
  command -v "${cmd}" >/dev/null 2>&1 || die "${cmd} was installed by apt package ${pkg} but is not in PATH"
  success "${pkg} installed"
}

install_from_tarball_find_binary() {
  local url="$1"
  local binary_name="$2"
  local archive_name="$3"
  local tmpdir archive extracted_binary

  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/${archive_name}"

  run curl -fL --retry 3 --retry-delay 2 -o "${archive}" "${url}"
  run tar -xzf "${archive}" -C "${tmpdir}"

  extracted_binary="$(find "${tmpdir}" -type f -name "${binary_name}" | awk 'NR==1 {print; exit}' || true)"
  [[ -n "${extracted_binary}" ]] || {
    rm -rf "${tmpdir}"
    die "${binary_name} binary was not found after extracting ${archive_name}"
  }

  run chmod +x "${extracted_binary}"
  run ${SUDO} install -m 0755 "${extracted_binary}" "${INSTALL_DIR}/${binary_name}"
  rm -rf "${tmpdir}"

  command -v "${binary_name}" >/dev/null 2>&1 || die "${binary_name} installed to ${INSTALL_DIR}, but it is not in PATH"
  success "${binary_name} installed at ${INSTALL_DIR}/${binary_name}"
}

# ---------- Core & Official Tools ----------
configure_kubernetes_apt_repo() {
  install_base_packages

  info "Configuring Kubernetes apt repository for ${K8S_MINOR_VERSION}"
  run ${SUDO} mkdir -p /etc/apt/keyrings

  local key_tmp
  key_tmp="$(mktemp)"

  run curl -fsSL "https://pkgs.k8s.io/core:/stable:/${K8S_MINOR_VERSION}/deb/Release.key" -o "${key_tmp}.asc"
  run gpg --dearmor -o "${key_tmp}.gpg" "${key_tmp}.asc"
  run ${SUDO} install -m 0644 "${key_tmp}.gpg" /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  rm -f "${key_tmp}" "${key_tmp}.asc" "${key_tmp}.gpg"

  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_MINOR_VERSION}/deb/ /" \
    | ${SUDO} tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

  APT_UPDATED=0
  apt_update_once
}

install_kubectl() {
  configure_kubernetes_apt_repo
  info "Installing kubectl"
  run ${SUDO} apt-get install -y kubectl
  command -v kubectl >/dev/null 2>&1 || die "kubectl was installed but is not in PATH"
  success "kubectl installed"
}

install_kubeadm() {
  configure_kubernetes_apt_repo
  info "Installing kubeadm"
  run ${SUDO} apt-get install -y kubeadm
  command -v kubeadm >/dev/null 2>&1 || die "kubeadm was installed but is not in PATH"
  success "kubeadm installed"
}

install_helm() {
  install_base_packages

  local helm_script script_url rc
  helm_script="$(mktemp)"
  script_url="https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-${HELM_MAJOR}"

  info "Installing Helm ${HELM_MAJOR}"
  run curl -fsSL -o "${helm_script}" "${script_url}"
  run chmod 700 "${helm_script}"

  if [[ -n "${HELM_VERSION}" ]]; then
    info "Pinning Helm version: ${HELM_VERSION}"
    DESIRED_VERSION="${HELM_VERSION}" "${helm_script}" 2>&1 | tee -a "${LOG_FILE}"
    rc="${PIPESTATUS[0]}"
    [[ "${rc}" -eq 0 ]] || return "${rc}"
  else
    "${helm_script}" 2>&1 | tee -a "${LOG_FILE}"
    rc="${PIPESTATUS[0]}"
    [[ "${rc}" -eq 0 ]] || return "${rc}"
  fi

  rm -f "${helm_script}"
  command -v helm >/dev/null 2>&1 || die "helm was installed but is not in PATH"
  success "helm installed"
}

install_kustomize() {
  install_base_packages

  local arch version tag encoded_tag asset url tmpdir archive extracted_binary releases_json
  arch="$(get_arch)"
  tmpdir="$(mktemp -d)"

  if [[ "${KUSTOMIZE_VERSION}" == "latest" ]]; then
    info "Finding latest Kustomize release"
    releases_json="${tmpdir}/kustomize-releases.json"
    run curl -fsSL -o "${releases_json}" "https://api.github.com/repos/kubernetes-sigs/kustomize/releases?per_page=100"

    version="$(
      awk -F'"' '
        /"tag_name": "kustomize\/v/ {
          value=$4
          sub(/^kustomize\//, "", value)
          print value
          exit
        }
      ' "${releases_json}"
    )"
  else
    version="${KUSTOMIZE_VERSION}"
    version="${version#kustomize/}"
    version="${version#v}"
    version="v${version}"
  fi

  if [[ -z "${version}" ]]; then
    rm -rf "${tmpdir}"
    die "Unable to determine Kustomize version."
  fi

  tag="kustomize/${version}"
  encoded_tag="kustomize%2F${version}"
  asset="kustomize_${version}_linux_${arch}.tar.gz"
  url="https://github.com/kubernetes-sigs/kustomize/releases/download/${encoded_tag}/${asset}"
  archive="${tmpdir}/${asset}"

  info "Installing Kustomize (${tag})"
  run curl -fL --retry 3 --retry-delay 2 -o "${archive}" "${url}"
  run tar -xzf "${archive}" -C "${tmpdir}"

  extracted_binary="${tmpdir}/kustomize"
  [[ -f "${extracted_binary}" ]] || {
    rm -rf "${tmpdir}"
    die "Kustomize binary was not found after extracting ${asset}"
  }

  run ${SUDO} install -m 0755 "${extracted_binary}" "${INSTALL_DIR}/kustomize"
  rm -rf "${tmpdir}"

  command -v kustomize >/dev/null 2>&1 || die "kustomize installed to ${INSTALL_DIR}, but kustomize is not in PATH"
  success "kustomize installed at ${INSTALL_DIR}/kustomize"
}

# ---------- Cluster Navigation & Efficiency ----------
install_k9s() {
  install_base_packages

  local arch url deb
  arch="$(get_arch)"

  if [[ "${K9S_VERSION}" == "latest" ]]; then
    url="https://github.com/derailed/k9s/releases/latest/download/k9s_linux_${arch}.deb"
  else
    url="https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_linux_${arch}.deb"
  fi

  deb="$(mktemp --suffix=.deb)"
  info "Installing k9s (${K9S_VERSION})"
  run curl -fsSL -o "${deb}" "${url}"
  run ${SUDO} apt-get install -y "${deb}"
  rm -f "${deb}"

  command -v k9s >/dev/null 2>&1 || die "k9s was installed but is not in PATH"
  success "k9s installed"
}

install_tmux() {
  install_apt_package "tmux"
}

install_kubectx_kubens() {
  install_base_packages

  info "Installing kubectx and kubens"
  local tmpdir
  tmpdir="$(mktemp -d)"

  run curl -fsSL -o "${tmpdir}/kubectx" "https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx"
  run curl -fsSL -o "${tmpdir}/kubens" "https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens"

  run ${SUDO} install -m 0755 "${tmpdir}/kubectx" "${INSTALL_DIR}/kubectx"
  run ${SUDO} install -m 0755 "${tmpdir}/kubens" "${INSTALL_DIR}/kubens"
  rm -rf "${tmpdir}"

  command -v kubectx >/dev/null 2>&1 || die "kubectx installed to ${INSTALL_DIR}, but it is not in PATH"
  command -v kubens >/dev/null 2>&1 || die "kubens installed to ${INSTALL_DIR}, but it is not in PATH"
  success "kubectx and kubens installed"
}

install_kubie() {
  install_base_packages

  local version json asset_include_regex url tmpdir asset download_path binary
  if [[ "${KUBIE_VERSION}" == "latest" ]]; then
    version="latest"
  else
    version="${KUBIE_VERSION}"
  fi

  tmpdir="$(mktemp -d)"
  json="${tmpdir}/kubie-release.json"

  info "Finding Kubie release asset (${version})"
  download_github_release_json "kubie-org/kubie" "${version}" "${json}"

  asset_pattern="$(get_kubie_arch_pattern)"
  url="$(extract_first_release_asset_url "${json}" "${asset_pattern}" "(sha|checksum|\.txt|\.sig|\.asc)$")"

  if [[ -z "${url}" ]]; then
    rm -rf "${tmpdir}"
    die "Unable to find a Kubie Linux asset for this architecture."
  fi

  asset="$(basename "${url}")"
  download_path="${tmpdir}/${asset}"

  info "Installing Kubie from ${asset}"
  run curl -fL --retry 3 --retry-delay 2 -o "${download_path}" "${url}"

  case "${asset}" in
    *.tar.gz|*.tgz)
      run tar -xzf "${download_path}" -C "${tmpdir}"
      ;;
    *.zip)
      run unzip -o "${download_path}" -d "${tmpdir}"
      ;;
    *)
      ;;
  esac

  binary="$(find "${tmpdir}" -type f \( -name "kubie" -o -name "kubie-linux-*" -o -name "kubie_*" \) | awk 'NR==1 {print; exit}' || true)"
  [[ -n "${binary}" ]] || {
    rm -rf "${tmpdir}"
    die "Kubie binary was not found in release asset ${asset}"
  }

  run chmod +x "${binary}"
  run ${SUDO} install -m 0755 "${binary}" "${INSTALL_DIR}/kubie"
  rm -rf "${tmpdir}"

  command -v kubie >/dev/null 2>&1 || die "kubie installed to ${INSTALL_DIR}, but it is not in PATH"
  success "kubie installed at ${INSTALL_DIR}/kubie"
}


install_kubecolor() {
  install_base_packages

  local arch version json tmpdir url asset download_path binary
  arch="$(get_arch)"

  if [[ "${KUBECOLOR_VERSION}" == "latest" ]]; then
    version="latest"
  else
    version="${KUBECOLOR_VERSION}"
  fi

  tmpdir="$(mktemp -d)"
  json="${tmpdir}/kubecolor-release.json"

  info "Finding Kubecolor release asset (${version})"
  download_github_release_json "kubecolor/kubecolor" "${version}" "${json}"

  # Prefer the native .deb package when available. Fall back to a raw Linux binary asset.
  url="$(extract_release_asset_url_awk "${json}" "linux.*${arch}.*\\.deb$" "(rpm|sha|checksum|txt|sig|asc)")"
  if [[ -z "${url}" ]]; then
    url="$(extract_release_asset_url_awk "${json}" "linux.*${arch}$" "(deb|rpm|sha|checksum|txt|sig|asc)")"
  fi

  if [[ -z "${url}" ]]; then
    rm -rf "${tmpdir}"
    die "Unable to find a Kubecolor Linux asset for architecture ${arch}."
  fi

  asset="$(basename "${url}")"
  download_path="${tmpdir}/${asset}"

  info "Installing Kubecolor from ${asset}"
  run curl -fL --retry 3 --retry-delay 2 -o "${download_path}" "${url}"

  case "${asset}" in
    *.deb)
      run ${SUDO} apt-get install -y "${download_path}"
      ;;
    *.tar.gz|*.tgz)
      run tar -xzf "${download_path}" -C "${tmpdir}"
      binary="$(find "${tmpdir}" -type f -name "kubecolor" | awk 'NR==1 {print; exit}' || true)"
      [[ -n "${binary}" ]] || {
        rm -rf "${tmpdir}"
        die "kubecolor binary was not found after extracting ${asset}"
      }
      run chmod +x "${binary}"
      run ${SUDO} install -m 0755 "${binary}" "${INSTALL_DIR}/kubecolor"
      ;;
    *)
      run chmod +x "${download_path}"
      run ${SUDO} install -m 0755 "${download_path}" "${INSTALL_DIR}/kubecolor"
      ;;
  esac

  rm -rf "${tmpdir}"
  command -v kubecolor >/dev/null 2>&1 || die "kubecolor installed, but it is not in PATH"
  success "kubecolor installed"
}

install_kubectl_tree() {
  install_base_packages

  local arch tag version_no_v asset url
  arch="$(get_arch)"

  if [[ "${KUBECTL_TREE_VERSION}" == "latest" ]]; then
    tag="$(latest_github_tag "ahmetb/kubectl-tree")"
  else
    tag="${KUBECTL_TREE_VERSION}"
  fi

  version_no_v="${tag#v}"
  asset="kubectl-tree_v${version_no_v}_linux_${arch}.tar.gz"
  url="https://github.com/ahmetb/kubectl-tree/releases/download/v${version_no_v}/${asset}"

  info "Installing kubectl-tree (${tag})"
  install_from_tarball_find_binary "${url}" "kubectl-tree" "${asset}"

  command -v kubectl-tree >/dev/null 2>&1 || die "kubectl-tree installed to ${INSTALL_DIR}, but it is not in PATH"
  success "kubectl-tree installed. Use it as: kubectl tree"
}

# ---------- Debugging & Observability ----------
install_stern() {
  install_base_packages

  local arch tag version_no_v asset url
  arch="$(get_arch)"

  if [[ "${STERN_VERSION}" == "latest" ]]; then
    tag="$(latest_github_tag "stern/stern")"
  else
    tag="${STERN_VERSION}"
  fi

  version_no_v="${tag#v}"
  asset="stern_${version_no_v}_linux_${arch}.tar.gz"
  url="https://github.com/stern/stern/releases/download/${tag}/${asset}"

  info "Installing Stern (${tag})"
  install_from_tarball_find_binary "${url}" "stern" "${asset}"
}

install_crictl() {
  install_base_packages

  local arch version url tmpdir archive
  arch="$(get_arch)"

  if [[ "${CRICTL_VERSION}" == "latest" ]]; then
    version="$(latest_github_tag "kubernetes-sigs/cri-tools")"
  else
    version="${CRICTL_VERSION}"
  fi

  [[ -n "${version}" ]] || die "Unable to determine crictl version."

  url="https://github.com/kubernetes-sigs/cri-tools/releases/download/${version}/crictl-${version}-linux-${arch}.tar.gz"
  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/crictl.tar.gz"

  info "Installing crictl (${version})"
  run curl -fsSL -o "${archive}" "${url}"
  run tar -xzf "${archive}" -C "${tmpdir}"
  run ${SUDO} install -m 0755 "${tmpdir}/crictl" "${INSTALL_DIR}/crictl"
  rm -rf "${tmpdir}"

  command -v crictl >/dev/null 2>&1 || die "crictl installed to ${INSTALL_DIR}, but crictl is not in PATH"
  success "crictl installed at ${INSTALL_DIR}/crictl"
}

# ---------- Monitoring & Operations ----------
install_argocd() {
  install_base_packages

  local arch url tmp
  arch="$(get_arch)"

  if [[ "${ARGOCD_VERSION}" == "latest" ]]; then
    url="https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-${arch}"
  else
    url="https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-${arch}"
  fi

  tmp="$(mktemp)"
  info "Installing Argo CD CLI (${ARGOCD_VERSION})"
  run curl -fsSL -o "${tmp}" "${url}"
  run chmod +x "${tmp}"
  run ${SUDO} install -m 0755 "${tmp}" "${INSTALL_DIR}/argocd"
  rm -f "${tmp}"

  command -v argocd >/dev/null 2>&1 || die "argocd installed to ${INSTALL_DIR}, but argocd is not in PATH"
  success "argocd installed at ${INSTALL_DIR}/argocd"
}

install_k8sgpt() {
  install_base_packages

  local arch deb_arch version url deb
  arch="$(get_arch)"
  case "${arch}" in
    amd64) deb_arch="amd64" ;;
    arm64) deb_arch="arm64" ;;
    *) die "Unsupported architecture for K8sGPT: ${arch}" ;;
  esac

  if [[ "${K8SGPT_VERSION}" == "latest" ]]; then
    version="$(latest_github_tag "k8sgpt-ai/k8sgpt")"
  else
    version="${K8SGPT_VERSION}"
  fi

  url="https://github.com/k8sgpt-ai/k8sgpt/releases/download/${version}/k8sgpt_${deb_arch}.deb"
  deb="$(mktemp --suffix=.deb)"

  info "Installing K8sGPT (${version})"
  run curl -fL --retry 3 --retry-delay 2 -o "${deb}" "${url}"
  run ${SUDO} apt-get install -y "${deb}"
  rm -f "${deb}"

  command -v k8sgpt >/dev/null 2>&1 || die "k8sgpt was installed but is not in PATH"
  success "k8sgpt installed"
}

# ---------- Workflow Automation & Source Control ----------
install_git() {
  install_apt_package "git"
}

install_make() {
  install_apt_package "make"
}

install_jq() {
  install_apt_package "jq"
}

install_yq() {
  install_base_packages

  local arch version url tmp
  arch="$(get_arch)"

  if [[ "${YQ_VERSION}" == "latest" ]]; then
    url="https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}"
    version="latest"
  else
    version="${YQ_VERSION}"
    url="https://github.com/mikefarah/yq/releases/download/${version}/yq_linux_${arch}"
  fi

  tmp="$(mktemp)"
  info "Installing yq (${version})"
  run curl -fsSL -o "${tmp}" "${url}"
  run chmod +x "${tmp}"
  run ${SUDO} install -m 0755 "${tmp}" "${INSTALL_DIR}/yq"
  rm -f "${tmp}"

  command -v yq >/dev/null 2>&1 || die "yq installed to ${INSTALL_DIR}, but yq is not in PATH"
  success "yq installed at ${INSTALL_DIR}/yq"
}

# ---------- Security & Compliance Tracking ----------
install_vault() {
  install_base_packages

  info "Adding HashiCorp apt repository"
  local key_tmp repo_line
  key_tmp="$(mktemp)"

  run curl -fsSL https://apt.releases.hashicorp.com/gpg -o "${key_tmp}.asc"
  run gpg --dearmor -o "${key_tmp}.gpg" "${key_tmp}.asc"
  run ${SUDO} install -m 0644 "${key_tmp}.gpg" /usr/share/keyrings/hashicorp-archive-keyring.gpg
  rm -f "${key_tmp}" "${key_tmp}.asc" "${key_tmp}.gpg"

  repo_line="deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
  echo "${repo_line}" | ${SUDO} tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

  APT_UPDATED=0
  apt_update_once

  info "Installing Vault CLI"
  run ${SUDO} apt-get install -y vault
  command -v vault >/dev/null 2>&1 || die "vault was installed but is not in PATH"
  success "vault installed"
}

install_kubespy() {
  install_base_packages

  local arch tag asset url
  arch="$(get_arch)"

  if [[ "${KUBESPY_VERSION}" == "latest" ]]; then
    tag="$(latest_github_tag "pulumi/kubespy")"
  else
    tag="${KUBESPY_VERSION}"
  fi

  asset="kubespy-${tag}-linux-${arch}.tar.gz"
  url="https://github.com/pulumi/kubespy/releases/download/${tag}/${asset}"

  info "Installing kubespy (${tag})"
  install_from_tarball_find_binary "${url}" "kubespy" "${asset}"
}

# ---------- Verification ----------
version_of() {
  local tool="$1"

  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo -e "${RED}missing${RESET}"
    return 1
  fi

  case "${tool}" in
    kubectl)
      kubectl version --client=true --output=yaml 2>/dev/null | awk '/gitVersion:/ {print $2; exit}' || kubectl version --client 2>/dev/null || true
      ;;
    kubeadm)
      kubeadm version -o short 2>/dev/null || kubeadm version 2>/dev/null || true
      ;;
    helm)
      helm version --short 2>/dev/null || helm version 2>/dev/null || true
      ;;
    kustomize)
      kustomize version 2>/dev/null || true
      ;;
    k9s)
      k9s version --short 2>/dev/null || k9s version 2>/dev/null | awk 'NR<=5 {print}' || true
      ;;
    tmux)
      tmux -V 2>/dev/null || true
      ;;
    kubectx)
      kubectx --help 2>/dev/null | awk 'NR==1 {print; exit}' || echo "installed"
      ;;
    kubens)
      kubens --help 2>/dev/null | awk 'NR==1 {print; exit}' || echo "installed"
      ;;
    kubie)
      kubie --version 2>/dev/null || true
      ;;
    kubecolor)
      kubecolor --version 2>/dev/null || kubecolor version 2>/dev/null || echo "installed"
      ;;
    kubectl-tree)
      kubectl-tree --help 2>/dev/null | awk 'NR==1 {print; exit}' || echo "installed"
      ;;
    stern)
      stern --version 2>/dev/null || true
      ;;
    crictl)
      crictl --version 2>/dev/null || true
      ;;
    argocd)
      argocd version --client --short 2>/dev/null || argocd version --client 2>/dev/null || true
      ;;
    k8sgpt)
      k8sgpt version 2>/dev/null || k8sgpt --version 2>/dev/null || true
      ;;
    git)
      git --version 2>/dev/null || true
      ;;
    make)
      make --version 2>/dev/null | awk 'NR==1 {print; exit}' || true
      ;;
    jq)
      jq --version 2>/dev/null || true
      ;;
    yq)
      yq --version 2>/dev/null || true
      ;;
    vault)
      vault version 2>/dev/null || true
      ;;
    kubespy)
      kubespy version 2>/dev/null || kubespy --version 2>/dev/null || echo "installed"
      ;;
    *)
      "${tool}" --version 2>/dev/null || true
      ;;
  esac
}

first_line() {
  # Avoid piping command output directly into `head` while pipefail is enabled.
  # Some CLIs print multiple lines and can trigger SIGPIPE/exit 141 when head exits early.
  awk 'NF { print; exit }'
}

verify_tool() {
  local tool="$1"
  local output=""

  if command -v "${tool}" >/dev/null 2>&1; then
    printf "%-14s " "${tool}"

    set +e
    output="$(version_of "${tool}" 2>/dev/null)"
    set -e

    if [[ -n "${output}" ]]; then
      printf "%s\n" "${output}" | first_line
    else
      echo "installed"
    fi
  else
    printf "%-14s %b\n" "${tool}" "${RED}missing${RESET}"
  fi
}

verify_all() {
  echo
  echo -e "${BOLD}${CYAN}Installed CLI versions${RESET}"

  echo
  echo -e "${BOLD}Kubernetes Core, Packaging & Manifest Tools${RESET}"
  printf "%-14s %s\n" "Tool" "Version"
  printf "%-14s %s\n" "----" "-------"
  for tool in kubectl kubeadm helm kustomize; do verify_tool "${tool}"; done

  echo
  echo -e "${BOLD}Cluster Navigation, Inspection & Efficiency${RESET}"
  printf "%-14s %s\n" "Tool" "Version"
  printf "%-14s %s\n" "----" "-------"
  for tool in k9s tmux kubectx kubens kubie kubecolor; do verify_tool "${tool}"; done

  echo
  echo -e "${BOLD}Debugging & Observability${RESET}"
  printf "%-14s %s\n" "Tool" "Version"
  printf "%-14s %s\n" "----" "-------"
  for tool in stern crictl kubectl-tree kubespy; do verify_tool "${tool}"; done

  echo
  echo -e "${BOLD}GitOps & Operational Diagnostics${RESET}"
  printf "%-14s %s\n" "Tool" "Version"
  printf "%-14s %s\n" "----" "-------"
  for tool in argocd k8sgpt; do verify_tool "${tool}"; done

  echo
  echo -e "${BOLD}Workflow Automation & Source Control${RESET}"
  printf "%-14s %s\n" "Tool" "Version"
  printf "%-14s %s\n" "----" "-------"
  for tool in git make jq yq; do verify_tool "${tool}"; done

  echo
  echo -e "${BOLD}Secrets & Security${RESET}"
  printf "%-14s %s\n" "Tool" "Version"
  printf "%-14s %s\n" "----" "-------"
  for tool in vault; do verify_tool "${tool}"; done
}

# ---------- Install all ----------
install_one_with_summary() {
  local label="$1"
  local func="$2"
  local rc=0

  echo
  echo -e "${BOLD}${CYAN}--- Installing ${label} ---${RESET}" | tee -a "${LOG_FILE}"

  set +e
  (
    set -Eeuo pipefail
    "${func}"
  )
  rc=$?
  set -Eeuo pipefail

  if [[ "${rc}" -eq 0 ]]; then
    INSTALL_OK+=("${label}")
    success "${label} install finished"
  else
    INSTALL_FAILED+=("${label}")
    error "${label} install failed with exit code ${rc}"
  fi
}

install_all() {
  INSTALL_OK=()
  INSTALL_FAILED=()

  echo -e "${BOLD}${CYAN}Installing full DevOps & Kubernetes toolbelt${RESET}"
  echo -e "${YELLOW}Log file:${RESET} ${LOG_FILE}"
  echo

  install_one_with_summary "kubectl" "install_kubectl"
  install_one_with_summary "kubeadm" "install_kubeadm"
  install_one_with_summary "Helm" "install_helm"
  install_one_with_summary "Kustomize" "install_kustomize"

  install_one_with_summary "K9s" "install_k9s"
  install_one_with_summary "tmux" "install_tmux"
  install_one_with_summary "kubectx & kubens" "install_kubectx_kubens"
  install_one_with_summary "Kubie" "install_kubie"
  install_one_with_summary "Kubecolor" "install_kubecolor"

  install_one_with_summary "Stern" "install_stern"
  install_one_with_summary "crictl" "install_crictl"
  install_one_with_summary "kubectl tree" "install_kubectl_tree"
  install_one_with_summary "kubespy" "install_kubespy"

  install_one_with_summary "Argo CD CLI" "install_argocd"
  install_one_with_summary "K8sGPT" "install_k8sgpt"

  install_one_with_summary "git" "install_git"
  install_one_with_summary "make" "install_make"
  install_one_with_summary "jq" "install_jq"
  install_one_with_summary "yq" "install_yq"

  install_one_with_summary "Vault CLI" "install_vault"

  echo
  echo -e "${BOLD}${CYAN}Install summary${RESET}"
  if [[ "${#INSTALL_OK[@]}" -gt 0 ]]; then
    echo -e "${GREEN}Succeeded:${RESET} ${INSTALL_OK[*]}"
  fi
  if [[ "${#INSTALL_FAILED[@]}" -gt 0 ]]; then
    echo -e "${RED}Failed:${RESET} ${INSTALL_FAILED[*]}"
    echo -e "${YELLOW}Review log:${RESET} ${LOG_FILE}"
  else
    echo -e "${GREEN}All tools installed successfully.${RESET}"
  fi

  verify_all

  if [[ "${#INSTALL_FAILED[@]}" -gt 0 ]]; then
    return 1
  fi
}

verify_core_tools() {
  echo
  echo -e "${BOLD}${CYAN}Core Tools CLI versions${RESET}"
  printf "%-14s %s\n" "Tool" "Version"
  printf "%-14s %s\n" "----" "-------"

  for tool in argocd vault jq git make k9s helm crictl yq kustomize; do
    verify_tool "${tool}"
  done
}

install_core_tools() {
  INSTALL_OK=()
  INSTALL_FAILED=()

  echo -e "${BOLD}${CYAN}Installing Core Tools only${RESET}"
  echo -e "${YELLOW}Core Tools:${RESET} argocd vault jq git make k9s helm crictl yq kustomize"
  echo -e "${YELLOW}Log file:${RESET} ${LOG_FILE}"
  echo

  install_one_with_summary "Argo CD CLI" "install_argocd"
  install_one_with_summary "Vault CLI" "install_vault"
  install_one_with_summary "jq" "install_jq"
  install_one_with_summary "git" "install_git"
  install_one_with_summary "make" "install_make"
  install_one_with_summary "K9s" "install_k9s"
  install_one_with_summary "Helm" "install_helm"
  install_one_with_summary "crictl" "install_crictl"
  install_one_with_summary "yq" "install_yq"
  install_one_with_summary "Kustomize" "install_kustomize"

  echo
  echo -e "${BOLD}${CYAN}Core Tools install summary${RESET}"
  if [[ "${#INSTALL_OK[@]}" -gt 0 ]]; then
    echo -e "${GREEN}Succeeded:${RESET} ${INSTALL_OK[*]}"
  fi
  if [[ "${#INSTALL_FAILED[@]}" -gt 0 ]]; then
    echo -e "${RED}Failed:${RESET} ${INSTALL_FAILED[*]}"
    echo -e "${YELLOW}Review log:${RESET} ${LOG_FILE}"
  else
    echo -e "${GREEN}All Core Tools installed successfully.${RESET}"
  fi

  verify_core_tools

  if [[ "${#INSTALL_FAILED[@]}" -gt 0 ]]; then
    return 1
  fi
}


run_menu_action() {
  local label="$1"
  local func="$2"
  local rc=0

  set +e
  (
    set -Eeuo pipefail
    "${func}"
  )
  rc=$?
  set -Eeuo pipefail

  if [[ "${rc}" -eq 0 ]]; then
    success "${label} completed"
  else
    error "${label} failed with exit code ${rc}"
    echo -e "${YELLOW}Review log:${RESET} ${LOG_FILE}"
  fi

  return 0
}

# ---------- TUI ----------
menu_row() {
  local number="$1"
  local label="$2"
  local desc="$3"
  printf "${GREEN}%2s)${RESET} %-26s ${CYAN}%s${RESET}\n" "${number}" "${label}" "${desc}"
}

category_header() {
  local title="$1"
  echo
  echo -e "${BOLD}${MAGENTA}${title}${RESET}"
  echo -e "${DIM}$(printf '%*s' "${#title}" '' | tr ' ' '-')${RESET}"
}

print_menu() {
  if [[ -t 1 ]]; then
    clear || true
  fi

  echo -e "${BOLD}${CYAN}====================================================================${RESET}"
  echo -e "${BOLD}${CYAN} Ubuntu 22.04 - 26.04 LTS DevOps & Kubernetes Toolbelt Installer${RESET}"
  echo -e "${BOLD}${CYAN}====================================================================${RESET}"
  echo
  echo -e "${YELLOW}Purpose:${RESET}"
  echo -e "  Build a workstation or bastion host with common CLI tools used for"
  echo -e "  Kubernetes operations, GitOps deployments, secrets management,"
  echo -e "  YAML/JSON processing, container runtime troubleshooting, and"
  echo -e "  terminal productivity."
  echo
  echo -e "${YELLOW}How to use this menu:${RESET}"
  echo -e "  ${GREEN}•${RESET} Select one tool to install it individually."
  echo -e "  ${GREEN}•${RESET} Select option 1 to install the full DevOps toolbelt."
  echo -e "  ${GREEN}•${RESET} Select option 24 to install only the Core Tools subset."
  echo -e "  ${GREEN}•${RESET} Select option 23 for multi-select, or type a list directly."
  echo -e "  ${GREEN}•${RESET} Multi-select examples: 2,5,7-10 or 11-14,22."
  echo -e "  ${GREEN}•${RESET} Select Verify versions after installation."
  echo -e "  ${GREEN}•${RESET} Use version override variables below when pinning releases."
  echo
  echo -e "${YELLOW}Log file:${RESET} ${LOG_FILE}"
  echo

  menu_row "1" "Install ALL tools" "Install every tool in category order"
  menu_row "24" "Install Core Tools" "Install argocd vault jq git make k9s helm crictl yq kustomize"

  category_header "Kubernetes Core, Packaging & Manifest Tools"
  menu_row "2" "kubectl" "Official Kubernetes CLI"
  menu_row "3" "kubeadm" "Kubernetes cluster bootstrap CLI"
  menu_row "4" "Helm" "Kubernetes package manager"
  menu_row "5" "Kustomize" "Kubernetes YAML overlay manager"

  category_header "Cluster Navigation, Inspection & Efficiency"
  menu_row "6" "K9s" "Terminal UI for Kubernetes"
  menu_row "7" "tmux" "Persistent terminal multiplexer"
  menu_row "8" "kubectx & kubens" "Switch kube contexts and namespaces"
  menu_row "9" "Kubie" "Isolated kube context shells"
  menu_row "10" "Kubecolor" "Colorized kubectl output wrapper"

  category_header "Debugging & Observability"
  menu_row "11" "Stern" "Multi-pod log tailing"
  menu_row "12" "crictl" "Container runtime CRI debug CLI"
  menu_row "13" "kubectl tree" "Show Kubernetes ownership trees"
  menu_row "14" "kubespy" "Watch Kubernetes resource changes"

  category_header "GitOps & Operational Diagnostics"
  menu_row "15" "Argo CD CLI" "GitOps continuous delivery CLI"
  menu_row "16" "K8sGPT" "AI-assisted Kubernetes diagnostics"

  category_header "Workflow Automation & Source Control"
  menu_row "17" "git" "Source control client"
  menu_row "18" "make" "Task runner/build automation"
  menu_row "19" "jq" "JSON query and formatting tool"
  menu_row "20" "yq" "YAML/JSON processor"

  category_header "Secrets & Security"
  menu_row "21" "Vault CLI" "HashiCorp secrets management CLI"

  echo
  menu_row "22" "Verify versions" "Show installed CLI versions by category"
  menu_row "23" "Select multiple tools" "Install choices like 2,5,7-10"
  menu_row "0" "Quit" "Exit installer"

  echo
  echo -e "${YELLOW}Version overrides:${RESET}"
  echo "  K8S_MINOR_VERSION=v1.36"
  echo "  ARGOCD_VERSION=v3.4.2"
  echo "  HELM_MAJOR=3"
  echo "  HELM_VERSION=v3.21.0"
  echo "  KUSTOMIZE_VERSION=v5.8.1"
  echo "  K9S_VERSION=v0.50.18"
  echo "  KUBIE_VERSION=v0.28.0"
  echo "  KUBECOLOR_VERSION=v0.6.0"
  echo "  KUBECTL_TREE_VERSION=v0.6.0"
  echo "  STERN_VERSION=v1.34.0"
  echo "  CRICTL_VERSION=v1.36.0"
  echo "  K8SGPT_VERSION=v0.4.33"
  echo "  YQ_VERSION=v4.53.2"
  echo "  KUBESPY_VERSION=v0.6.3"
  echo
}

run_menu_selection() {
  local choice="$1"

  case "${choice}" in
    1) install_all || true ;;
    2) run_menu_action "kubectl" "install_kubectl" ;;
    3) run_menu_action "kubeadm" "install_kubeadm" ;;
    4) run_menu_action "Helm" "install_helm" ;;
    5) run_menu_action "Kustomize" "install_kustomize" ;;
    6) run_menu_action "K9s" "install_k9s" ;;
    7) run_menu_action "tmux" "install_tmux" ;;
    8) run_menu_action "kubectx & kubens" "install_kubectx_kubens" ;;
    9) run_menu_action "Kubie" "install_kubie" ;;
    10) run_menu_action "Kubecolor" "install_kubecolor" ;;
    11) run_menu_action "Stern" "install_stern" ;;
    12) run_menu_action "crictl" "install_crictl" ;;
    13) run_menu_action "kubectl tree" "install_kubectl_tree" ;;
    14) run_menu_action "kubespy" "install_kubespy" ;;
    15) run_menu_action "Argo CD CLI" "install_argocd" ;;
    16) run_menu_action "K8sGPT" "install_k8sgpt" ;;
    17) run_menu_action "git" "install_git" ;;
    18) run_menu_action "make" "install_make" ;;
    19) run_menu_action "jq" "install_jq" ;;
    20) run_menu_action "yq" "install_yq" ;;
    21) run_menu_action "Vault CLI" "install_vault" ;;
    22) verify_all ;;
    23) prompt_multi_select ;;
    24) install_core_tools || true ;;
    0|q|Q|quit|exit)
      echo -e "${GREEN}Goodbye.${RESET}"
      exit 0
      ;;
    *)
      warn "Invalid option: ${choice}"
      ;;
  esac
}

expand_multi_select() {
  local raw="$1"
  local compact token start end i
  compact="$(echo "${raw}" | tr -d '[:space:]')"

  if [[ -z "${compact}" ]]; then
    return 0
  fi

  IFS=',' read -ra tokens <<< "${compact}"

  for token in "${tokens[@]}"; do
    [[ -z "${token}" ]] && continue

    if [[ "${token}" =~ ^[0-9]+$ ]]; then
      echo "${token}"
    elif [[ "${token}" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      start="${BASH_REMATCH[1]}"
      end="${BASH_REMATCH[2]}"

      if (( start > end )); then
        warn "Skipping invalid descending range: ${token}"
        continue
      fi

      for (( i=start; i<=end; i++ )); do
        echo "${i}"
      done
    else
      warn "Skipping invalid selection token: ${token}"
    fi
  done
}

run_multi_select() {
  local raw="$1"
  local -a expanded=()
  local choice seen_all=0

  mapfile -t expanded < <(expand_multi_select "${raw}")

  if [[ "${#expanded[@]}" -eq 0 ]]; then
    warn "No valid selections found. Example: 2,5,7-10"
    return 0
  fi

  echo -e "${BOLD}${CYAN}Multi-select expanded to:${RESET} ${expanded[*]}"

  for choice in "${expanded[@]}"; do
    if [[ "${choice}" == "1" ]]; then
      seen_all=1
      break
    fi
  done

  if [[ "${seen_all}" -eq 1 ]]; then
    warn "Option 1 installs all tools. Running install-all once and skipping the remaining multi-select entries."
    install_all || true
    return 0
  fi

  for choice in "${expanded[@]}"; do
    case "${choice}" in
      0)
        warn "Skipping option 0 inside multi-select. Use 0 by itself to quit."
        ;;
      23)
        warn "Skipping option 23 inside multi-select to avoid recursion."
        ;;
      *)
        run_menu_selection "${choice}"
        ;;
    esac
  done
}

prompt_multi_select() {
  local selections
  echo -e "${BOLD}${CYAN}Multi-select mode${RESET}"
  echo "Enter menu numbers separated by commas. Ranges are supported."
  echo "Examples:"
  echo "  2,5,7-10"
  echo "  11-14,22"
  echo
  read -r -p "Enter selections: " selections
  run_multi_select "${selections}"
}

interactive_menu() {
  while true; do
    print_menu
    read -r -p "Select an option [0-24 or list]: " choice
    echo

    if [[ "${choice}" == *","* || "${choice}" =~ [0-9]+-[0-9]+ ]]; then
      run_multi_select "${choice}"
    else
      run_menu_selection "${choice}"
    fi

    pause_menu
  done
}

usage() {
  cat <<EOF
Usage:
  $0 [menu|all|core-tools|verify|TOOL]

Interactive multi-select:
  In the menu, choose option 23 or type a list directly.
  Examples: 2,5,7-10 or 11-14,22

Core Tools install subset:
  core-tools
  Installs: argocd vault jq git make k9s helm crictl yq kustomize

Kubernetes Core, Packaging & Manifest Tools:
  kubectl
  kubeadm
  helm
  kustomize

Cluster Navigation, Inspection & Efficiency:
  k9s
  tmux
  kubectx-kubens
  kubie
  kubecolor

Debugging & Observability:
  stern
  crictl
  kubectl-tree
  kubespy

GitOps & Operational Diagnostics:
  argocd
  k8sgpt

Workflow Automation & Source Control:
  git
  make
  jq
  yq

Secrets & Security:
  vault

Examples:
  $0 menu
  $0 all
  $0 core-tools
  $0 kubectl
  $0 kubectx-kubens
  $0 kubecolor
  $0 kubectl-tree
  $0 k8sgpt
  K8S_MINOR_VERSION=v1.34 $0 kubectl
  KUSTOMIZE_VERSION=v5.8.1 $0 kustomize
  KUBECOLOR_VERSION=v0.6.0 $0 kubecolor
  KUBECTL_TREE_VERSION=v0.6.0 $0 kubectl-tree

Log file:
  ${LOG_FILE}
EOF
}

main() {
  preflight
  detect_ubuntu

  local cmd="${1:-menu}"

  case "${cmd}" in
    menu) interactive_menu ;;
    all|install) install_all ;;
    core-tools|core|core-install) install_core_tools ;;
    verify) verify_all ;;

    kubectl) install_kubectl ;;
    kubeadm) install_kubeadm ;;
    helm) install_helm ;;
    kustomize) install_kustomize ;;

    k9s) install_k9s ;;
    tmux) install_tmux ;;
    kubectx-kubens|kubectx|kubens) install_kubectx_kubens ;;
    kubie) install_kubie ;;
    kubecolor) install_kubecolor ;;
    kubectl-tree|tree) install_kubectl_tree ;;

    stern) install_stern ;;
    crictl) install_crictl ;;

    argocd|argo-cd) install_argocd ;;
    k8sgpt) install_k8sgpt ;;

    git) install_git ;;
    make|make-tool) install_make ;;
    jq) install_jq ;;
    yq) install_yq ;;

    vault) install_vault ;;
    kubespy) install_kubespy ;;

    help|-h|--help) usage ;;
    *)
      usage
      die "Unknown command: ${cmd}"
      ;;
  esac
}

main "$@"
