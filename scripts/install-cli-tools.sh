#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu 22.04 DevOps Toolbelt Installer
# DevOps/Kubernetes tools for building, deploying, debugging, and operating cloud-native infrastructure.

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"

ARGOCD_VERSION="${ARGOCD_VERSION:-latest}"   # Example: v3.2.0 or latest
K9S_VERSION="${K9S_VERSION:-latest}"         # Example: v0.50.9 or latest
HELM_MAJOR="${HELM_MAJOR:-3}"                # Default: Helm 3
HELM_VERSION="${HELM_VERSION:-}"             # Example: v3.19.0. Empty = latest for HELM_MAJOR
CRICTL_VERSION="${CRICTL_VERSION:-latest}"   # Example: v1.34.0 or latest
YQ_VERSION="${YQ_VERSION:-latest}"           # Example: v4.48.1 or latest
KUSTOMIZE_VERSION="${KUSTOMIZE_VERSION:-latest}" # Example: v5.8.1, 5.8.1, or latest
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
LOG_FILE="${LOG_FILE:-/tmp/devops-toolbelt-install-$(date +%Y%m%d-%H%M%S).log}"

SUDO=""
if [[ "${EUID}" -ne 0 ]]; then
  SUDO="sudo"
fi

APT_UPDATED=0

# ---------- Colors ----------
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
  RESET="$(tput sgr0)"
  BOLD="$(tput bold)"
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  YELLOW="$(tput setaf 3)"
  BLUE="$(tput setaf 4)"
  MAGENTA="$(tput setaf 5)"
  CYAN="$(tput setaf 6)"
else
  RESET=""
  BOLD=""
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
      warn "This script was built for Ubuntu 22.04. Detected: ${PRETTY_NAME:-unknown Linux}."
    elif [[ "${VERSION_ID:-}" != "22.04" ]]; then
      warn "This script was built for Ubuntu 22.04. Detected: ${PRETTY_NAME:-Ubuntu ${VERSION_ID:-unknown}}."
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

latest_github_tag() {
  local repo="$1"
  local effective_url
  effective_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest")"
  echo "${effective_url}" | sed -E 's#^.*/tag/([^/?#]+).*$#\1#'
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
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    apt-transport-https \
    unzip \
    tar \
    gzip \
    openssl
}

install_apt_package() {
  local pkg="$1"
  install_base_packages
  info "Installing ${pkg} via apt"
  run ${SUDO} apt-get install -y "${pkg}"
  command -v "${pkg}" >/dev/null 2>&1 || die "${pkg} was installed by apt but is not in PATH"
  success "${pkg} installed"
}

# ---------- Individual installers ----------
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

install_jq() {
  install_apt_package "jq"
}

install_git() {
  install_apt_package "git"
}

install_make() {
  install_apt_package "make"
}

install_tmux() {
  install_apt_package "tmux"
}

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

install_helm() {
  install_base_packages

  local helm_script script_url
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

install_kustomize() {
  install_base_packages

  local arch tag version encoded_tag url tmpdir archive
  arch="$(get_arch)"

  if [[ "${KUSTOMIZE_VERSION}" == "latest" ]]; then
    tag="$(latest_github_tag "kubernetes-sigs/kustomize")"
  else
    version="${KUSTOMIZE_VERSION#kustomize/}"
    [[ "${version}" == v* ]] || version="v${version}"
    tag="kustomize/${version}"
  fi

  [[ -n "${tag}" ]] || die "Unable to determine Kustomize version."

  version="${tag#kustomize/}"
  encoded_tag="${tag//\//%2F}"
  url="https://github.com/kubernetes-sigs/kustomize/releases/download/${encoded_tag}/kustomize_${version}_linux_${arch}.tar.gz"

  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/kustomize.tar.gz"

  info "Installing Kustomize (${version})"
  run curl -fsSL -o "${archive}" "${url}"
  run tar -xzf "${archive}" -C "${tmpdir}"
  run ${SUDO} install -m 0755 "${tmpdir}/kustomize" "${INSTALL_DIR}/kustomize"
  rm -rf "${tmpdir}"

  command -v kustomize >/dev/null 2>&1 || die "kustomize installed to ${INSTALL_DIR}, but kustomize is not in PATH"
  success "kustomize installed at ${INSTALL_DIR}/kustomize"
}

# ---------- Verification ----------
version_of() {
  local tool="$1"

  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo -e "${RED}missing${RESET}"
    return 1
  fi

  case "${tool}" in
    argocd)
      argocd version --client --short 2>/dev/null || argocd version --client 2>/dev/null || true
      ;;
    vault)
      vault version 2>/dev/null || true
      ;;
    jq)
      jq --version 2>/dev/null || true
      ;;
    git)
      git --version 2>/dev/null || true
      ;;
    make)
      make --version 2>/dev/null | head -n 1 || true
      ;;
    tmux)
      tmux -V 2>/dev/null || true
      ;;
    k9s)
      k9s version --short 2>/dev/null || k9s version 2>/dev/null | head -n 5 || true
      ;;
    helm)
      helm version --short 2>/dev/null || helm version 2>/dev/null || true
      ;;
    crictl)
      crictl --version 2>/dev/null || true
      ;;
    yq)
      yq --version 2>/dev/null || true
      ;;
    kustomize)
      kustomize version 2>/dev/null || true
      ;;
    *)
      "${tool}" --version 2>/dev/null || true
      ;;
  esac
}

verify_all() {
  echo
  echo -e "${BOLD}${CYAN}Installed CLI versions${RESET}"
  printf "%-12s %s\n" "Tool" "Version"
  printf "%-12s %s\n" "----" "-------"

  local tool
  for tool in argocd vault jq git make tmux k9s helm crictl yq kustomize; do
    if command -v "${tool}" >/dev/null 2>&1; then
      printf "%-12s " "${tool}"
      version_of "${tool}" | head -n 1
    else
      printf "%-12s %b\n" "${tool}" "${RED}missing${RESET}"
    fi
  done
}

# ---------- Install all with per-tool summary ----------
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

  echo -e "${BOLD}${CYAN}Installing all CLI tools${RESET}"
  echo -e "${YELLOW}Log file:${RESET} ${LOG_FILE}"
  echo

  # Apt-based tools first.
  install_one_with_summary "jq" "install_jq"
  install_one_with_summary "git" "install_git"
  install_one_with_summary "make" "install_make"
  install_one_with_summary "tmux" "install_tmux"

  # Upstream release/repo-based tools.
  install_one_with_summary "helm" "install_helm"
  install_one_with_summary "argocd" "install_argocd"
  install_one_with_summary "vault" "install_vault"
  install_one_with_summary "k9s" "install_k9s"
  install_one_with_summary "crictl" "install_crictl"
  install_one_with_summary "yq" "install_yq"
  install_one_with_summary "kustomize" "install_kustomize"

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

# ---------- TUI ----------
menu_row() {
  local number="$1"
  local label="$2"
  local desc="$3"
  printf "${GREEN}%2s)${RESET} %-24s ${CYAN}%s${RESET}\n" "${number}" "${label}" "${desc}"
}

print_menu() {
  if [[ -t 1 ]]; then
    clear || true
  fi

  echo -e "${BOLD}${CYAN}Ubuntu 22.04 DevOps Toolbelt Installer${RESET}"
  echo -e "${YELLOW}DevOps/Kubernetes tools for building, deploying, debugging, and operating cloud-native infrastructure.${RESET}"
  echo -e "${YELLOW}Log file:${RESET} ${LOG_FILE}"
  echo
  menu_row "1"  "Install ALL tools"    "Install every CLI listed below"
  menu_row "2"  "Argo CD CLI"          "GitOps continuous delivery CLI"
  menu_row "3"  "Vault CLI"            "HashiCorp secrets management CLI"
  menu_row "4"  "jq"                   "JSON query and formatting tool"
  menu_row "5"  "git"                  "Source control client"
  menu_row "6"  "make"                 "Task runner/build automation"
  menu_row "7"  "tmux"                 "Persistent terminal multiplexer"
  menu_row "8"  "k9s"                  "Terminal UI for Kubernetes"
  menu_row "9"  "Helm CLI"             "Kubernetes package manager"
  menu_row "10" "crictl"               "Container runtime CRI debug CLI"
  menu_row "11" "yq"                   "YAML/JSON processor"
  menu_row "12" "Kustomize"            "Kubernetes YAML overlay manager"
  menu_row "13" "Verify versions"      "Show installed CLI versions"
  menu_row "0"  "Quit"                 "Exit installer"
  echo
  echo -e "${YELLOW}Version overrides:${RESET}"
  echo "  ARGOCD_VERSION=v3.2.0"
  echo "  K9S_VERSION=v0.50.9"
  echo "  HELM_MAJOR=3"
  echo "  HELM_VERSION=v3.19.0"
  echo "  CRICTL_VERSION=v1.34.0"
  echo "  YQ_VERSION=v4.48.1"
  echo "  KUSTOMIZE_VERSION=v5.8.1"
  echo
}

interactive_menu() {
  while true; do
    print_menu
    read -r -p "Select an option [0-13]: " choice
    echo

    case "${choice}" in
      1) install_all || true ;;
      2) install_argocd ;;
      3) install_vault ;;
      4) install_jq ;;
      5) install_git ;;
      6) install_make ;;
      7) install_tmux ;;
      8) install_k9s ;;
      9) install_helm ;;
      10) install_crictl ;;
      11) install_yq ;;
      12) install_kustomize ;;
      13) verify_all ;;
      0|q|Q|quit|exit)
        echo -e "${GREEN}Goodbye.${RESET}"
        exit 0
        ;;
      *)
        warn "Invalid option: ${choice}"
        ;;
    esac

    pause_menu
  done
}

usage() {
  cat <<EOF
Usage:
  $0 [menu|all|argocd|vault|jq|git|make|tmux|k9s|helm|crictl|yq|kustomize|verify]

Examples:
  $0 menu
  $0 all
  $0 helm
  $0 tmux
  $0 crictl
  $0 yq
  $0 kustomize
  ARGOCD_VERSION=v3.2.0 $0 argocd
  K9S_VERSION=v0.50.9 $0 k9s
  HELM_VERSION=v3.19.0 $0 helm
  CRICTL_VERSION=v1.34.0 $0 crictl
  YQ_VERSION=v4.48.1 $0 yq
  KUSTOMIZE_VERSION=v5.8.1 $0 kustomize

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
    argocd) install_argocd ;;
    vault) install_vault ;;
    jq) install_jq ;;
    git) install_git ;;
    make|make-tool) install_make ;;
    tmux) install_tmux ;;
    k9s) install_k9s ;;
    helm) install_helm ;;
    crictl) install_crictl ;;
    yq) install_yq ;;
    kustomize) install_kustomize ;;
    verify) verify_all ;;
    help|-h|--help) usage ;;
    *)
      usage
      die "Unknown command: ${cmd}"
      ;;
  esac
}

main "$@"
