#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $(basename "${BASH_SOURCE[0]}") [--remote-ref <ref>] <clone_dir> <ignored_keys_file> [--help | -h]

Description:
  Clone the RealSense ROS2 driver and install the custom launch file.

Options:
  --remote-ref <ref>  Branch or tag to clone (example: ros2-master or 4.57.6).
  -h, --help  Show this help message.

Arguments:
  clone_dir          Destination directory for the cloned repository.
  ignored_keys_file  Existing file where rosdep ignored keys are appended.

Notes:
  - If --remote-ref is not provided, the latest published tag is used (GitHub releases/latest).
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

# Minimal prerequisites required before argument parsing
require_cmd getopt
require_cmd git
require_cmd install
require_cmd curl

SHORT_OPTS="h"
LONG_OPTS="help,remote-ref:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

eval set -- "${PARSED_ARGS}"

REMOTE_REF=""
while true; do
    case "$1" in
    --remote-ref)
        REMOTE_REF="$2"
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

if [ "$#" -ne 2 ]; then
    log "ERROR: Expected 2 positional arguments: <clone_dir> <ignored_keys_file>. Got: $*"
    usage
    exit 2
fi

CLONE_DIR="${1}"
ROSDEP_IGNORED_KEYS_FILE="${2}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "${CLONE_DIR}" ]; then
    log "ERROR: Destination directory already exists: ${CLONE_DIR}. Please remove it or choose a new destination."
    exit 1
fi

if [ ! -f "${ROSDEP_IGNORED_KEYS_FILE}" ]; then
    log "ERROR: Rosdep ignored keys file does not exist: ${ROSDEP_IGNORED_KEYS_FILE}"
    exit 1
fi

parent_dir="$(dirname "${CLONE_DIR}")"
mkdir --parent --verbose "${parent_dir}"
cd "${parent_dir}" # Set current directory

remote_repo="https://github.com/realsenseai/realsense-ros.git"
local_repo="${CLONE_DIR}"

log "Cloning the repository '${remote_repo}' into the path '${local_repo}'"
# Determine which git ref to clone: use --remote-ref when provided, otherwise use the latest release tag.
if [ -n "${REMOTE_REF}" ]; then
    REF="${REMOTE_REF}"
    REF_KIND="remote ref"
else
    if ! latest_release_json="$(curl -fsSL https://api.github.com/repos/realsenseai/realsense-ros/releases/latest)"; then
        log "ERROR: Failed to query GitHub API for the latest realsense-ros release."
        exit 1
    fi

    REF="$(printf '%s\n' "${latest_release_json}" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

    if [ -z "${REF}" ]; then
        log "ERROR: Could not resolve latest release tag from GitHub API."
        exit 1
    fi

    REF_KIND="tag (latest release)"
fi

log "Cloning realsense-ros using ${REF_KIND}: ${REF}"
# --depth 1: Clone only the latest commit to save time and bandwidth, as we don't need the full history for this use
# case.
git clone --branch "${REF}" --depth 1 "${remote_repo}" "${local_repo}"

# Free space for Docker image builds; VCS history is not required.
rm -rf "${local_repo}/.git"

# ----------------------------------------------------------------------------------------------------------------------
# Installing launch file eut_sensor.launch.py
# ----------------------------------------------------------------------------------------------------------------------
log "Placing eut_sensor.launch.py into ${local_repo}/realsense2_camera/launch/eut_sensor.launch.py"
install -m 0755 "${script_dir}/eut_sensor.launch.py" "${local_repo}/realsense2_camera/launch/eut_sensor.launch.py"

# ----------------------------------------------------------------------------------------------------------------------
# Write rosdep keys to ignore during 'rosdep install'.
# ----------------------------------------------------------------------------------------------------------------------
# As described in the README.md file, when installing the RealSense ROS2 driver from source we have to install the
# dependencies using 'rosdep install --from-paths src --ignore-src -r -y ...' command.
# Also in that document, it is described that when installing both software items, the librealsense2 library and the
# RealSense ROS2 driver, from source, we have to install the librealsense2 library first, and then the RealSense ROS2
# driver, but skipping the item 'librealsense2' during the installation of the RealSense ROS2 driver dependencies using
# rosdep, otherwise we might encounter conflicts between the librealsense2 library installed from source and the one
# provided by the system package manager.
# Reference: https://github.com/ros-infrastructure/rosdep/issues/649
# Locally ignore rosdep keys using empty list of packages: https://github.com/ros-infrastructure/rosdep/issues/649
rosdep_ignored_keys=("librealsense2: {ubuntu: []}")

# -q, --quiet: Suppress normal output.
# -x, --line-regexp: Select only those matches that exactly match the whole line.
# -F, --fixed-strings: Interpret the pattern as fixed strings, not regular expressions.
for key in "${rosdep_ignored_keys[@]}"; do
    if ! grep -qxF -- "${key}" -- "${ROSDEP_IGNORED_KEYS_FILE}"; then
        printf '%s\n' "${key}" >>"${ROSDEP_IGNORED_KEYS_FILE}"
        log "Added rosdep key to ignore, '${key}', to file '${ROSDEP_IGNORED_KEYS_FILE}'"
    else
        log "Rosdep key to ignore '${key}' already exists in file '${ROSDEP_IGNORED_KEYS_FILE}'. Skipping adding it again."
    fi
done
