#!/usr/bin/env bash
set -euo pipefail

# Setup host Ubuntu for RealSense by installing udev rules, patching the kernel (optional), and installing
# librealsense2 (optional).

usage() {
    cat <<EOF
Usage:
  $(basename "${BASH_SOURCE[0]}") [--no-patch-kernel] [--l4t] [--install-librealsense2] [--remote-ref <ref>] [--clone-dir <dir>] [--option <NAME>=<VALUE> ...] [--help | -h]

Description:
  Setup host Ubuntu for RealSense by installing udev rules, patching the kernel (optional), and installing
  librealsense2 (optional).

Options:
  --no-patch-kernel         Skip kernel patching step.
  --l4t                     Use the Jetson L4T patch script when kernel patching is executed.
  --install-librealsense2   Install librealsense2 from source.
  --remote-ref <ref>        Clone the specified librealsense branch or tag (example: master or v2.56.5).
  --clone-dir <dir>         Destination directory for the cloned repository.
  --option <NAME>=<VALUE>   Add CMake option for librealsense install (repeatable), where <VALUE> is ON|OFF|TRUE|FALSE.
  -h, --help                Show this help message.

Notes:
  - If both --no-patch-kernel and --l4t are provided, --no-patch-kernel takes precedence and patching is skipped.
  - If --remote-ref is not provided, the latest release tag is used.
  - If --clone-dir is not provided, mktemp creates /tmp/librealsense2_XXXXXX.
  - install_udev_rules.sh is always executed.
EOF
}

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%d_%H-%M-%S')" "$*"; }

require_cmd() {
    local cmd="${1}"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log "ERROR: Missing required command: ${cmd}" >&2
        exit 1
    fi
}

cleanup_clone_dir_on_error() {
    if [ -n "${CLONE_DIR:-}" ] && [ -d "${CLONE_DIR}" ]; then
        log "ERROR: git clone failed, removing destination directory: ${CLONE_DIR}" >&2
        rm -rf "${CLONE_DIR}"
    fi
}

# Install only resolvable Debian packages.
install_pkgs() {
    local pkgs=("$@")
    local to_install=()
    local pkg

    [ ${#pkgs[@]} -eq 0 ] && {
        log "No packages given" >&2
        return 0
    }

    for pkg in "${pkgs[@]}"; do
        # If it is already installed, skip it.
        if dpkg-query -W -f='${Status}\n' "${pkg}" 2>/dev/null | grep -q '^install ok installed$'; then
            log "Checking package '${pkg}': already installed"
            continue
        fi

        if "${SUDO_CMD[@]}" env "${APT_ENV[@]}" apt-get "${APT_GET_OPTS[@]}" --simulate --no-install-recommends install "${pkg}" >/dev/null 2>&1; then
            to_install+=("${pkg}")
            log "Checking package '${pkg}': installable"
        else
            log "ERROR: Package '${pkg}' is not installable" >&2
            return 1
        fi
    done

    if [ ${#to_install[@]} -eq 0 ]; then
        log "All requested packages are already installed"
        return 0
    fi

    log "Installing packages: ${to_install[*]}"
    "${SUDO_CMD[@]}" env "${APT_ENV[@]}" apt-get "${APT_GET_OPTS[@]}" install --yes --no-install-recommends "${to_install[@]}" || {
        log "ERROR: Package installation failed: ${to_install[*]}" >&2
        return 1
    }

    return 0
}

SHORT_OPTS="h"
LONG_OPTS="help,no-patch-kernel,l4t,install-librealsense2,remote-ref:,clone-dir:,option:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}
eval set -- "${PARSED_ARGS}"

SKIP_PATCH_KERNEL=0
USE_L4T=0
INSTALL_LIBREALSENSE2=0

REMOTE_REF=""
REMOTE_REF_SET=0

CLONE_DIR=""
CLONE_DIR_SET=0

INSTALL_OPTIONS=()

while true; do
    case "${1}" in
    --no-patch-kernel)
        SKIP_PATCH_KERNEL=1
        shift
        ;;
    --l4t)
        USE_L4T=1
        shift
        ;;
    --install-librealsense2)
        INSTALL_LIBREALSENSE2=1
        shift
        ;;
    --remote-ref)
        REMOTE_REF="${2}"
        REMOTE_REF_SET=1
        shift 2
        ;;
    --clone-dir)
        CLONE_DIR="${2}"
        CLONE_DIR_SET=1
        shift 2
        ;;
    --option)
        INSTALL_OPTIONS+=("--option" "${2}")
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *)
        log "ERROR: Unexpected option: ${1}" >&2
        usage
        exit 2
        ;;
    esac
done

if [ "$#" -ne 0 ]; then
    log "ERROR: Unexpected positional arguments: $*" >&2
    usage
    exit 2
fi

# flags --option <NAME>=<VALUE> can only be used together with --install-librealsense2 since they are meant to provide
# additional CMake options during librealsense installation.
# Requiring --install-librealsense2 when --option is used prevents confusion and ensures that the provided options are
# actually applied to an installation step.
if [ "${INSTALL_LIBREALSENSE2}" -eq 0 ] && [ "${#INSTALL_OPTIONS[@]}" -gt 0 ]; then
    log "ERROR: --option can only be used together with --install-librealsense2" >&2
    usage
    exit 2
fi

# Detect likely container environment to avoid confusion
if [ -f "/.dockerenv" ] || [ -f "/run/.containerenv" ]; then
    log "ERROR: This must be run on the HOST, not inside a container" >&2
    exit 1
fi

if [ ! -r /etc/os-release ]; then
    log "ERROR: /etc/os-release not found" >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    log "ERROR: Unsupported OS '${ID:-unknown}'" >&2
    exit 1
fi

log "Detected host OS: ${PRETTY_NAME:-Ubuntu LTS} (${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}), kernel: $(uname -r)"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UDEV_SCRIPT="${SCRIPT_DIR}/install_udev_rules.sh"
PATCH_SCRIPT="${SCRIPT_DIR}/patch_realsense_ubuntu.sh"
INSTALL_SCRIPT="${SCRIPT_DIR}/install_librealsense2_from_source.sh"

if [ ! -f "${UDEV_SCRIPT}" ] || [ ! -f "${PATCH_SCRIPT}" ] || [ ! -f "${INSTALL_SCRIPT}" ]; then
    log "ERROR: Expected scripts were not found in ${SCRIPT_DIR}" >&2
    exit 1
fi

# Detect if the script is running with root privileges to determine if sudo is needed for privileged operations.
SUDO_CMD=()

if [ "$(id -u)" -ne 0 ]; then
    # If the script is not running as root, check if sudo is available for privileged operations.
    # If the script is not running as root and sudo is not available, exit with an error since we won't be able to
    # install packages or run 'make install'.
    require_cmd sudo
    SUDO_CMD=(sudo)
fi

# Non-interactive apt execution settings
# DEBIAN_FRONTEND=noninteractive prevents apt from prompting the user for input, which is essential for automated
# scripts.
# NEEDRESTART_MODE=a configures the 'needrestart' tool to automatically restart services if needed after library
# updates, without prompting the user. This is important to ensure that any services using librealsense are restarted to
# use the new version without manual intervention.
APT_ENV=(DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a)
# -o Dpkg::Use-Pty=0 prevents apt from using a pseudo-terminal, which can cause issues in non-interactive environments
# like CI pipelines or when running scripts remotely. This ensures that apt does not attempt to use interactive features
# that require a terminal.
# -o Dpkg::Options::=--force-confdef and -o Dpkg::Options::=--force-confold tell dpkg to automatically handle
# configuration file prompts by keeping the existing configuration files without asking the user. This is crucial for
# non-interactive scripts to avoid hanging on prompts about configuration file changes during package installation or
# upgrades.
APT_GET_OPTS=(-o Dpkg::Use-Pty=0 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
# In clone mode, git is always required. curl is only needed when --remote-ref is omitted and we query GitHub for the
# latest release.
APT_PACKAGES=(git)

# Check if the user provided the flag --clone-dir.
if [ "${CLONE_DIR_SET}" -eq 1 ]; then
    # If the user provided the flag --clone-dir with an empty value (""), reject it explicitly since it would cause
    # git clone to fail with a less clear error message.
    if [ -z "${CLONE_DIR}" ]; then
        log "ERROR: --clone-dir requires a directory argument" >&2
        usage
        exit 2
    fi

    # If the execution flow is here, it means the user provided the flag --clone-dir with a non-empty value.
    if [ -d "${CLONE_DIR}" ]; then
        log "ERROR: Destination directory already exists: ${CLONE_DIR}" >&2
        exit 1
    fi
else
    # If no --clone-dir was provided, create a temporary directory for cloning.
    CLONE_DIR="$(mktemp -d /tmp/librealsense2_XXXXXX)"
fi

if [ "${REMOTE_REF_SET}" -eq 1 ]; then
    # Reject explicit empty remote refs such as: --remote-ref ""
    if [ -z "${REMOTE_REF}" ]; then
        log "ERROR: --remote-ref requires a reference argument" >&2
        usage
        exit 2
    fi

    REF_KIND="remote reference"
else
    APT_PACKAGES+=(curl)
fi

if [ "${#APT_PACKAGES[@]}" -gt 0 ]; then
    "${SUDO_CMD[@]}" env "${APT_ENV[@]}" apt-get "${APT_GET_OPTS[@]}" update
    install_pkgs "${APT_PACKAGES[@]}"
fi

# If the remote ref is not set, we will determine the latest release tag from the GitHub API.
if [ "${REMOTE_REF_SET}" -eq 0 ]; then
    if ! latest_release_json="$(curl -fsSL https://api.github.com/repos/realsenseai/librealsense/releases/latest)"; then
        log "ERROR: Failed to query GitHub API for the latest librealsense release" >&2
        exit 1
    fi

    REMOTE_REF="$(printf '%s\n' "${latest_release_json}" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

    if [ -z "${REMOTE_REF}" ]; then
        log "ERROR: Could not resolve latest release tag from GitHub API" >&2
        exit 1
    fi

    REF_KIND="latest release"
fi

librealsense_repo_url="https://github.com/realsenseai/librealsense.git"
log "Cloning '${librealsense_repo_url}' using ${REF_KIND} '${REMOTE_REF}'"
log "Using destination directory '${CLONE_DIR}'"

# Enable a temporary ERR trap so a failed clone does not leave a partial destination directory.
# The trap is cleared immediately after a successful clone.
trap 'cleanup_clone_dir_on_error' ERR
# --depth 1: Clone only the latest commit to save time and bandwidth, as we don't need the full history for this use
# case.
git clone --branch "${REMOTE_REF}" --depth 1 "${librealsense_repo_url}" "${CLONE_DIR}"
trap - ERR

# Free space for Docker image builds; VCS history is not required.
rm -rf "${CLONE_DIR}/.git"

log "Installing udev rules using source directory: ${CLONE_DIR}"
bash "${UDEV_SCRIPT}" --source-dir "${CLONE_DIR}"

if [ "${SKIP_PATCH_KERNEL}" -eq 1 ]; then
    if [ "${USE_L4T}" -eq 1 ]; then
        log "Both --no-patch-kernel and --l4t were provided; --no-patch-kernel takes precedence and kernel patching is skipped"
    fi

    log "Skipping kernel patching (--no-patch-kernel)"
else
    log "Patching kernel using source directory: ${CLONE_DIR}"
    PATCH_ARGS=(--source-dir "${CLONE_DIR}")

    if [ "${USE_L4T}" -eq 1 ]; then
        PATCH_ARGS+=(--l4t)
    fi

    bash "${PATCH_SCRIPT}" "${PATCH_ARGS[@]}"
fi

if [ "${INSTALL_LIBREALSENSE2}" -eq 1 ]; then
    log "Installing librealsense2 using source directory: ${CLONE_DIR}"
    bash "${INSTALL_SCRIPT}" --source-dir "${CLONE_DIR}" "${INSTALL_OPTIONS[@]}"
else
    log "Skipping librealsense2 installation (--install-librealsense2 not set)"
fi
