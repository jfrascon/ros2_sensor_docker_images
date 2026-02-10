#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $(basename "${BASH_SOURCE[0]}") <pkgs_dir> <refs_file> <ignored_keys_file> [--help | -h]

Description:
  Clone required repositories, install the custom launch file, and update rosdep ignored keys.

Options:
  -h, --help  Show this help message.

Arguments:
  pkgs_dir           Parent directory where repositories will be cloned.
  refs_file          File containing required repository refs:
                     realsense-ros <ref>
                     ros2_launch_helpers <ref>
  ignored_keys_file  Existing file where rosdep ignored keys are appended.

Notes:
  - refs_file must define both keys: realsense-ros and ros2_launch_helpers.
  - Example refs_file content:
      realsense-ros 4.57.3
      ros2_launch_helpers main
  - Destination paths are fixed:
      <pkgs_dir>/realsense-ros
      <pkgs_dir>/ros2_launch_helpers
  - If any destination already exists, the script fails.
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
    if [ -n "${CURRENT_CLONE_DIR:-}" ] && [ -d "${CURRENT_CLONE_DIR}" ]; then
        log "ERROR: git clone failed, removing destination directory: ${CURRENT_CLONE_DIR}" >&2
        rm -rf "${CURRENT_CLONE_DIR}"
    fi
}

SHORT_OPTS="h"
LONG_OPTS="help"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

eval set -- "${PARSED_ARGS}"

while true; do
    case "${1}" in
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

if [ "$#" -ne 3 ]; then
    log "ERROR: Expected 3 positional arguments: <pkgs_dir> <refs_file> <ignored_keys_file>. Got: $*" >&2
    usage
    exit 2
fi

PKGS_DIR="${1}"
REFS_FILE="${2}"
ROSDEP_IGNORED_KEYS_FILE="${3}"

if [ -e "${PKGS_DIR}" ] && [ ! -d "${PKGS_DIR}" ]; then
    log "ERROR: pkgs_dir exists but is not a directory: ${PKGS_DIR}" >&2
    exit 1
fi

mkdir --parent --verbose "${PKGS_DIR}"
PKGS_DIR="$(cd "${PKGS_DIR}" && pwd)"

if [ ! -f "${REFS_FILE}" ]; then
    log "ERROR: refs_file does not exist: ${REFS_FILE}" >&2
    exit 1
fi

if [ ! -f "${ROSDEP_IGNORED_KEYS_FILE}" ]; then
    log "ERROR: Rosdep ignored keys file does not exist: ${ROSDEP_IGNORED_KEYS_FILE}" >&2
    exit 1
fi

require_cmd git
require_cmd grep

realsense_repo_url="https://github.com/realsenseai/realsense-ros.git"
ros2_launch_helpers_repo_url="https://github.com/jfrascon/ros2_launch_helpers.git"

REALSENSE_ROS_REF=""
ROS2_LAUNCH_HELPERS_REF=""
line_number=0

# Read refs_file line by line.
# - IFS= keeps leading/trailing spaces in each raw line so we can handle comments/blank lines explicitly.
# - read -r avoids backslash escaping.
# - "|| [ -n \"\${line}\" ]" ensures the last line is processed even if the file does not end with a newline.
while IFS= read -r line || [ -n "${line}" ]; do
    line_number=$((line_number + 1))
    # Example: if line is "    realsense-ros    4.57.6", trimmed_line becomes "realsense-ros    4.57.6".
    trimmed_line="${line#"${line%%[![:space:]]*}"}"

    # Skip blank lines and comment lines (a comment is any line whose first non-space character is '#').
    if [ -z "${trimmed_line}" ] || [[ "${trimmed_line}" == \#* ]]; then
        continue
    fi

    repo_key=""
    repo_ref=""
    # Any extra fields in the line are ignored on purpose.
    read -r repo_key repo_ref _ <<<"${trimmed_line}"

    if [ -z "${repo_key}" ] || [ -z "${repo_ref}" ]; then
        log "ERROR: Invalid refs_file format at line ${line_number}. Expected: <repo_key> <ref>" >&2
        exit 2
    fi

    case "${repo_key}" in
    realsense-ros)
        if [ -n "${REALSENSE_ROS_REF}" ]; then
            log "ERROR: Duplicate key in refs_file at line ${line_number}: realsense-ros" >&2
            exit 2
        fi

        REALSENSE_ROS_REF="${repo_ref}"
        ;;
    ros2_launch_helpers)
        if [ -n "${ROS2_LAUNCH_HELPERS_REF}" ]; then
            log "ERROR: Duplicate key in refs_file at line ${line_number}: ros2_launch_helpers" >&2
            exit 2
        fi

        ROS2_LAUNCH_HELPERS_REF="${repo_ref}"
        ;;
    *)
        log "ERROR: Unknown key in refs_file at line ${line_number}: ${repo_key}" >&2
        exit 2
        ;;
    esac
done <"${REFS_FILE}"

if [ -z "${REALSENSE_ROS_REF}" ]; then
    log "ERROR: Missing required key in refs_file: realsense-ros" >&2
    exit 2
fi

if [ -z "${ROS2_LAUNCH_HELPERS_REF}" ]; then
    log "ERROR: Missing required key in refs_file: ros2_launch_helpers" >&2
    exit 2
fi

realsense_ros_dst="${PKGS_DIR}/realsense-ros"
ros2_launch_helpers_dst="${PKGS_DIR}/ros2_launch_helpers"

if [ -e "${realsense_ros_dst}" ]; then
    log "ERROR: Destination directory already exists: ${realsense_ros_dst}" >&2
    exit 1
fi

if [ -e "${ros2_launch_helpers_dst}" ]; then
    log "ERROR: Destination directory already exists: ${ros2_launch_helpers_dst}" >&2
    exit 1
fi

# Validate that each provided ref exists in remote as a branch or tag.
if ! git ls-remote --exit-code --heads --tags "${realsense_repo_url}" "${REALSENSE_ROS_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${REALSENSE_ROS_REF}' not found in ${realsense_repo_url}" >&2
    exit 1
fi

if ! git ls-remote --exit-code --heads --tags "${ros2_launch_helpers_repo_url}" "${ROS2_LAUNCH_HELPERS_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${ROS2_LAUNCH_HELPERS_REF}' not found in ${ros2_launch_helpers_repo_url}" >&2
    exit 1
fi

log "Cloning '${realsense_repo_url}' using remote reference '${REALSENSE_ROS_REF}'"
log "Using destination directory '${realsense_ros_dst}'"
# Set cleanup target for ERR trap so a failed clone removes only this destination directory.
CURRENT_CLONE_DIR="${realsense_ros_dst}"
trap 'cleanup_clone_dir_on_error' ERR
git clone --branch "${REALSENSE_ROS_REF}" --depth 1 "${realsense_repo_url}" "${realsense_ros_dst}"
trap - ERR
# Clear cleanup target after a successful clone to avoid deleting unrelated paths on later errors.
CURRENT_CLONE_DIR=""

# Free space for Docker image builds; VCS history is not required.
rm -rf "${realsense_ros_dst}/.git"

log "Cloning '${ros2_launch_helpers_repo_url}' using remote reference '${ROS2_LAUNCH_HELPERS_REF}'"
log "Using destination directory '${ros2_launch_helpers_dst}'"
# Set cleanup target for ERR trap so a failed clone removes only this destination directory.
CURRENT_CLONE_DIR="${ros2_launch_helpers_dst}"
trap 'cleanup_clone_dir_on_error' ERR
git clone --branch "${ROS2_LAUNCH_HELPERS_REF}" --depth 1 "${ros2_launch_helpers_repo_url}" "${ros2_launch_helpers_dst}"
trap - ERR
# Clear cleanup target after a successful clone to avoid deleting unrelated paths on later errors.
CURRENT_CLONE_DIR=""

# Free space.
rm -rf "${ros2_launch_helpers_dst}/.git"

# ----------------------------------------------------------------------------------------------------------------------
# Installing launch file eut_sensor.launch.py
# ----------------------------------------------------------------------------------------------------------------------
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "${script_dir}/eut_sensor.launch.py" ]; then
    log "ERROR: Missing required launch file: ${script_dir}/eut_sensor.launch.py" >&2
    exit 1
fi

log "Placing eut_sensor.launch.py into ${realsense_ros_dst}/realsense2_camera/launch/eut_sensor.launch.py"
install -m 0755 "${script_dir}/eut_sensor.launch.py" "${realsense_ros_dst}/realsense2_camera/launch/eut_sensor.launch.py"

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
        log "Rosdep key to ignore '${key}' already exists in file '${ROSDEP_IGNORED_KEYS_FILE}'. Skipping adding it again"
    fi
done
