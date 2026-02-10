#!/usr/bin/env bash

set -euo pipefail

# This script builds and installs librealsense2 from source.
# It supports clone mode (default), which fetches sources from GitHub, and source-dir mode, which uses an existing local
# librealsense tree.

usage() {
    cat <<EOF
Usage:
  $(basename "${BASH_SOURCE[0]}") [--source-dir <dir>] [--remote-ref <ref>] [--clone-dir <dir>] [--option <NAME>=<VALUE> ...]

Description:
  Build and install librealsense2 from source using one of two modes:
  clone mode (default) or source-dir mode.

Options:
  --source-dir <dir>       Use an existing local librealsense source directory (no clone).
  --remote-ref <ref>       Clone the specified librealsense branch or tag (example: master or v2.56.5).
  --clone-dir <dir>        Destination directory for the cloned repository (clone mode only).
  --option <NAME>=<VALUE>  Add CMake option (repeatable), where <VALUE> is ON|OFF|TRUE|FALSE.
  -h, --help               Show this help message.

Notes:
  - Two modes are supported: clone mode (default) and source-dir mode.
  - --source-dir selects source-dir mode. If omitted, clone mode is used.
  - --remote-ref is valid only in clone mode.
  - --clone-dir is valid only in clone mode.
  - In clone mode, if --remote-ref is not provided,
    the latest published tag is used (GitHub releases/latest).
  - In clone mode, if --clone-dir is not provided, a temporary directory like
    /tmp/librealsense2_XXXXXX is created with mktemp (the Xs are replaced).
  - --option is repeatable, example:
    --option BUILD_WITH_CUDA=ON --option BUILD_EXAMPLES=OFF
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

# Minimal prerequisites required before argument parsing
require_cmd getopt

SHORT_OPTS="h"
LONG_OPTS="help,source-dir:,remote-ref:,clone-dir:,option:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

# Parse arguments using getopt and set corresponding variables and flags.
eval set -- "${PARSED_ARGS}"

USE_SOURCE_DIR=0
SOURCE_DIR=""

REMOTE_REF=""
REMOTE_REF_SET=0

CLONE_DIR=""
CLONE_DIR_SET=0

CMAKE_OPTIONS=()

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
    --option)
        opt="${2}"

        if [[ "${opt}" != *=* ]]; then
            log "ERROR: Invalid --option '${opt}'. Expected NAME=VALUE" >&2
            usage
            exit 2
        fi

        opt_name="${opt%%=*}"
        opt_value="${opt#*=}"

        if [ -z "${opt_name}" ] || [ -z "${opt_value}" ]; then
            log "ERROR: Invalid --option '${opt}'. Expected non-empty NAME and VALUE" >&2
            usage
            exit 2
        fi

        # Validate that the option name is a valid CMake variable name (letters, digits, underscores; must not start
        # with a digit). This also rejects invalid characters such as '-' or spaces.
        # Examples: BUILD_WITH_CUDA (valid), 1FOO (invalid), BUILD-WITH-CUDA (invalid).
        if [[ ! "${opt_name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
            log "ERROR: Invalid CMake option name '${opt_name}'" >&2
            exit 2
        fi

        opt_value_upper="${opt_value^^}"

        case "${opt_value_upper}" in
        ON | OFF)
            opt_value_normalized="${opt_value_upper}"
            ;;
        TRUE)
            opt_value_normalized="ON"
            ;;
        FALSE)
            opt_value_normalized="OFF"
            ;;
        *)
            log "ERROR: Invalid --option value '${opt_value}' for '${opt_name}'. Use ON|OFF|TRUE|FALSE" >&2
            exit 2
            ;;
        esac

        CMAKE_OPTIONS+=("-D${opt_name}=${opt_value_normalized}")
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

# Ensure this script runs only on Ubuntu LTS host
if [ ! -r /etc/os-release ]; then
    log "ERROR: /etc/os-release not found" >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    log "ERROR: Unsupported OS '${ID:-unknown}'. Ubuntu LTS is required" >&2
    exit 1
fi

if [[ "${VERSION:-}" != *"LTS"* ]]; then
    log "ERROR: Ubuntu non-LTS detected (${PRETTY_NAME:-unknown}). Ubuntu LTS is required" >&2
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

# The command apt-get must be present, otherwise we cannot install the dependencies required to build librealsense2 from
# source.
require_cmd apt-get

# Non-interactive apt execution settings
APT_ENV=(DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a)
APT_GET_OPTS=(-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold)
# Packages required to build librealsense2 from source.
# In clone mode, additional packages are needed to fetch the sources, and will be added later.
APT_PACKAGES=(
    ca-certificates
    cmake
    build-essential
    libssl-dev
    libusb-1.0-0-dev
    libudev-dev
    pkg-config
    udev
    v4l-utils
    libgtk-3-dev
    libglfw3-dev
    libgl1-mesa-dev
    libglu1-mesa-dev
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

        CLONE_DIR_EFFECTIVE="${CLONE_DIR}"

        if [ -d "${CLONE_DIR_EFFECTIVE}" ]; then
            log "ERROR: Destination directory already exists: ${CLONE_DIR_EFFECTIVE}" >&2
            exit 1
        fi
    # Otherwise, if no flag --clone-dir was provided, create a temporary directory for cloning using mktemp.
    else
        require_cmd mktemp
        CLONE_DIR_EFFECTIVE="$(mktemp -d /tmp/librealsense2_XXXXXX)"
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

log "Updating apt package index"
"${SUDO_CMD[@]}" env "${APT_ENV[@]}" apt-get "${APT_GET_OPTS[@]}" update

log "Installing required dependencies"
"${SUDO_CMD[@]}" env "${APT_ENV[@]}" apt-get "${APT_GET_OPTS[@]}" install -y --no-install-recommends "${APT_PACKAGES[@]}"

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

        EFFECTIVE_REF="${REMOTE_REF}"
        REF_KIND="remote ref"
    else
        if ! latest_release_json="$(curl -fsSL https://api.github.com/repos/realsenseai/librealsense/releases/latest)"; then
            log "ERROR: Failed to query GitHub API for the latest librealsense release" >&2
            exit 1
        fi

        EFFECTIVE_REF="$(printf '%s\n' "${latest_release_json}" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

        if [ -z "${EFFECTIVE_REF}" ]; then
            log "ERROR: Could not resolve latest release tag from GitHub API" >&2
            exit 1
        fi

        REF_KIND="tag (latest release)"
    fi

    log "Cloning librealsense using ${REF_KIND}: ${EFFECTIVE_REF}"
    log "Using destination directory: ${CLONE_DIR_EFFECTIVE}"
    git clone --branch "${EFFECTIVE_REF}" --depth 1 https://github.com/realsenseai/librealsense.git "${CLONE_DIR_EFFECTIVE}"
    # Free space for Docker image builds; VCS history is not required.
    rm -rf "${CLONE_DIR_EFFECTIVE}/.git"
    SOURCE_DIR="${CLONE_DIR_EFFECTIVE}"
else
    log "Using existing librealsense source directory: ${SOURCE_DIR}"
fi

BUILD_DIR="${SOURCE_DIR}/build"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Reference for build options:
# https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake
# https://dev.realsenseai.com/docs/build-configuration
log "Configuring librealsense build"

if [ "${#CMAKE_OPTIONS[@]}" -eq 0 ]; then
    log "No --option values provided. Using librealsense default CMake options"
else
    log "Applying user CMake options: ${CMAKE_OPTIONS[*]}"
fi

cmake .. -DCMAKE_BUILD_TYPE=Release "${CMAKE_OPTIONS[@]}"

cpu_count="$(nproc)"

if [ "${cpu_count}" -gt 1 ]; then
    build_jobs="$((cpu_count - 1))"
else
    build_jobs=1
fi

log "Building librealsense using ${build_jobs} parallel jobs"
make -j"${build_jobs}"

log "Installing librealsense to the host system"
"${SUDO_CMD[@]}" make install
"${SUDO_CMD[@]}" ldconfig

log "Done. librealsense2 has been installed from source in ${SOURCE_DIR}"
