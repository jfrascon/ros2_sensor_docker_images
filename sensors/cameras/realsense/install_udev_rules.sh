#!/usr/bin/env bash
set -euo pipefail

# This script installs RealSense udev rules.
# It must be run on the HOST machine, not inside a container.
# It supports clone mode (default), which fetches librealsense from GitHub, and source-dir mode, which uses an existing
# local librealsense tree.

usage() {
    cat <<EOF
Usage:
  $(basename "${BASH_SOURCE[0]}") [--source-dir <dir>] [--remote-ref <ref>] [--clone-dir <dir>] [--help | -h]

Description:
  Install udev rules for RealSense cameras.

Options:
  --source-dir <dir>  Use an existing local librealsense source directory (no clone).
  --remote-ref <ref>  Clone the specified librealsense branch or tag (example: master or v2.56.5).
  --clone-dir <dir>   Destination directory for the cloned repository (clone mode only).
  -h, --help          Show this help message.

Notes:
  - Two modes are supported: clone mode (default) and source-dir mode.
  - --source-dir selects source-dir mode. If omitted, clone mode is used.
  - --remote-ref is valid only in clone mode.
  - --clone-dir is valid only in clone mode.
  - In clone mode, if --remote-ref is not provided,
    the latest published tag is used (GitHub releases/latest).
  - In clone mode, if --clone-dir is not provided, a temporary directory like
    /tmp/librealsense2_XXXXXX is created with mktemp (the Xs are replaced).
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
        if dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
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
LONG_OPTS="help,source-dir:,remote-ref:,clone-dir:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

eval set -- "${PARSED_ARGS}"

USE_SOURCE_DIR=0
SOURCE_DIR=""

REMOTE_REF=""
REMOTE_REF_SET=0

CLONE_DIR=""
CLONE_DIR_SET=0

while true; do
    case "${1}" in
    --source-dir)
        SOURCE_DIR="${2}"
        USE_SOURCE_DIR=1
        shift 2
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
# Packages required to build librealsense2 from source.
# In clone mode, additional packages are needed to fetch the sources, and will be added later.
APT_PACKAGES=(
    ca-certificates
    libssl-dev
    libusb-1.0-0-dev
    libudev-dev
    pkg-config
    udev
    v4l-utils
)

# Check if the script is in clone mode or source-dir mode based on the presence of --source-dir.
# Depending on the mode, validate that the provided arguments make sense, and set up any additional dependencies or
# variables needed for the respective mode.
if [ "${USE_SOURCE_DIR}" -eq 0 ]; then
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
        # Check that the provided directory does not already exist to prevent git clone from failing.
        if [ -d "${CLONE_DIR}" ]; then
            log "ERROR: Destination directory already exists: ${CLONE_DIR}" >&2
            exit 1
        fi
    # Otherwise, if no flag --clone-dir was provided, create a temporary directory for cloning using mktemp.
    else
        CLONE_DIR="$(mktemp -d /tmp/librealsense2_XXXXXX)"
    fi

    # In clone mode, additional packages are needed.
    APT_PACKAGES+=(curl git)
else # The script is in 'source-dir' mode
    if [ "${REMOTE_REF_SET}" -eq 1 ]; then
        log "ERROR: --remote-ref can only be used with clone mode" >&2
        usage
        exit 2
    fi

    if [ "${CLONE_DIR_SET}" -eq 1 ]; then
        log "ERROR: --clone-dir can only be used with clone mode" >&2
        usage
        exit 2
    fi

    # Defensive check: getopt enforces an argument for --source-dir, but users can still pass an empty value
    # (e.g. --source-dir "" or --source-dir=), which must be rejected explicitly.
    if [ -z "${SOURCE_DIR}" ]; then
        log "ERROR: --source-dir requires a directory argument" >&2
        usage
        exit 2
    fi

    if [ ! -d "${SOURCE_DIR}" ]; then
        log "ERROR: Source directory does not exist: ${SOURCE_DIR}" >&2
        exit 1
    fi

    if [ ! -f "${SOURCE_DIR}/CMakeLists.txt" ]; then
        log "ERROR: ${SOURCE_DIR} does not look like a librealsense source tree (CMakeLists.txt not found)" >&2
        exit 1
    fi
fi

"${SUDO_CMD[@]}" env "${APT_ENV[@]}" apt-get "${APT_GET_OPTS[@]}" update
install_pkgs "${APT_PACKAGES[@]}"

# If the script is in clone mode, clone the librealsense repository and determine the source directory.
# If the script is in source-dir mode, use the provided source directory directly.
if [ "${USE_SOURCE_DIR}" -eq 0 ]; then
    if [ "${REMOTE_REF_SET}" -eq 1 ]; then
        # If the user provided the flag --remote-ref with an empty value (""), reject it explicitly since it would cause
        # git clone to fail.
        if [ -z "${REMOTE_REF}" ]; then
            log "ERROR: --remote-ref requires a reference argument" >&2
            usage
            exit 2
        fi

        REF_KIND="remote reference"
    else
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
    SOURCE_DIR="${CLONE_DIR}"
else
    log "Using existing librealsense source directory: ${SOURCE_DIR}"
fi

# Install the udev rules
log "Installing RealSense udev rules on host."
bash "${SOURCE_DIR}/scripts/setup_udev_rules.sh"
"${SUDO_CMD[@]}" udevadm control --reload-rules
"${SUDO_CMD[@]}" udevadm trigger
