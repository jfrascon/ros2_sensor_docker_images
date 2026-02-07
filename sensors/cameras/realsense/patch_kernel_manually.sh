#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  patch_kernel_manually.sh [--branch <branch> | --tag <tag>]

Description:
  Manually patch host OS kernel modules following option A.1.2.

Options:
  --branch <branch>  Clone the specified librealsense branch (example: master).
  --tag <tag>        Clone the specified librealsense tag (example: v2.56.5).
  -h, --help         Show this help message.

Notes:
  - --branch and --tag are mutually exclusive.
  - If neither is provided, the latest published tag is used (GitHub releases/latest).
EOF
}

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%d_%H-%M-%S')" "$*"; }

require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log "ERROR: Missing required command: ${cmd}"
        exit 1
    fi
}

# Non-interactive apt execution settings
APT_ENV=(DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a)
APT_GET_OPTS=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)

# Minimal prerequisites required before argument parsing and package installation
require_cmd getopt

SHORT_OPTS="h"
LONG_OPTS="help,branch:,tag:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

eval set -- "${PARSED_ARGS}"

BRANCH=""
TAG=""
while true; do
    case "$1" in
    --branch)
        BRANCH="$2"
        shift 2
        ;;
    --tag)
        TAG="$2"
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
        log "ERROR: Unexpected option: $1"
        usage
        exit 2
        ;;
    esac
done

if [ "$#" -ne 0 ]; then
    log "ERROR: Unexpected positional arguments: $*"
    usage
    exit 2
fi

if [ -n "${BRANCH}" ] && [ -n "${TAG}" ]; then
    log "ERROR: --branch and --tag cannot be used together."
    usage
    exit 2
fi

# Detect likely container environment to avoid confusion
if [ -f "/.dockerenv" ] || [ -f "/run/.containerenv" ]; then
    log "ERROR: This must be run on the HOST, not inside a container." >&2
    exit 1
fi

# Ensure this script runs only on Ubuntu LTS host
if [ ! -r /etc/os-release ]; then
    log "ERROR: /etc/os-release not found."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    log "ERROR: Unsupported OS '${ID:-unknown}'. Ubuntu LTS is required."
    exit 1
fi

if [[ "${VERSION:-}" != *"LTS"* ]]; then
    log "ERROR: Ubuntu non-LTS detected (${PRETTY_NAME:-unknown}). Ubuntu LTS is required."
    exit 1
fi

log "Detected host OS: ${PRETTY_NAME:-Ubuntu LTS} (${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}), kernel: $(uname -r)"

require_cmd apt-get

# Detect if the script is running with root privileges to determine if sudo is needed for privileged operations.
SUDO_CMD=()
if [ "$(id -u)" -ne 0 ]; then
    require_cmd sudo
    SUDO_CMD=(sudo)
else
    SUDO_CMD=()
fi

# Refresh apt package index
log "Updating apt package index."
"${SUDO_CMD[@]}" env "${APT_ENV[@]}" apt-get "${APT_GET_OPTS[@]}" update

# Install required packages for building librealsense and kernel modules
log "Installing dependencies required for A.1.2."
"${SUDO_CMD[@]}" env "${APT_ENV[@]}" apt-get "${APT_GET_OPTS[@]}" install -y --no-install-recommends ca-certificates curl git wget cmake build-essential libssl-dev \
    udev \
    libusb-1.0-0-dev \
    libudev-dev \
    pkg-config \
    v4l-utils

default_dst_dir="/tmp/librealsense"

if [ -e "${default_dst_dir}" ]; then
    dst_dir="$(mktemp -d /tmp/librealsense_XXXXXX)"
else
    dst_dir="${default_dst_dir}"
fi

log "Using destination directory: ${dst_dir}"

# Clone the librealsense repository at the specified branch or tag, or the latest published release if neither is
# specified.
if [ -n "${BRANCH}" ]; then
    REF="${BRANCH}"
    REF_KIND="branch"
elif [ -n "${TAG}" ]; then
    REF="${TAG}"
    REF_KIND="tag"
else
    # Retrieve latest published release tag from librealsense repository.
    latest_release_json="$(curl -fsSL https://api.github.com/repos/realsenseai/librealsense/releases/latest)"
    REF="$(printf '%s\n' "${latest_release_json}" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"
    if [ -z "${REF}" ]; then
        log "ERROR: Could not resolve latest release tag from GitHub API."
        exit 1
    fi
    REF_KIND="tag (latest release)"
fi

log "Cloning librealsense using ${REF_KIND}: ${REF}"
git clone --branch "${REF}" --depth 1 https://github.com/realsenseai/librealsense.git "${dst_dir}"

# Install the udev rules
log "Installing RealSense udev rules on host."
bash "${dst_dir}/scripts/setup_udev_rules.sh"
"${SUDO_CMD[@]}" udevadm control --reload-rules
"${SUDO_CMD[@]}" udevadm trigger

# Patch the kernel modules for your Ubuntu LTS version
# Visit the function ${dst_dir}/scripts/patch-utils-hwe.sh::choose_kernel_branch to see which kernels are supported.
# As of February 2026, the supported kernels listed in the function choose_kernel_branch for the latest published
# release, v2.57.6, marked as beta, are:
# Ubuntu 20.04 LTS (focal): 5.4, 5.8, 5.11, 5.13, 5.15.
# Ubuntu 22.04 LTS (jammy): 5.15, 5.19, 6.2, 6.5, 6.8.
# Ubuntu 24.04 LTS (noble): 6.8, 6.11, 6.14.
log "Patching kernel modules for Ubuntu LTS."
bash "${dst_dir}/scripts/patch-realsense-ubuntu-lts-hwe.sh"

# The script above will download, patch and build realsense-affected kernel modules (drivers).
# Then it will attempt to insert the patched module instead of the active one.
# If failed the original uvc modules will be restored.

# Refer to the URL https://github.com/realsenseai/librealsense/blob/master/doc/installation.md#troubleshooting-installation-and-patch-related-issues
# for troubleshooting installation and patch related issues.

# Check the patched modules installation by examining the generated log as well as inspecting the latest entries in
# kernel log.
# The log should indicate that a new _uvcvideo_ driver has been registered.
log "Showing latest kernel log entries."
"${SUDO_CMD[@]}" dmesg | tail -n 50
