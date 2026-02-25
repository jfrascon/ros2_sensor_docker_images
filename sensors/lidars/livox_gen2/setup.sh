#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF_USAGE
Usage:
  $(basename "${BASH_SOURCE[0]}") <pkgs_dir> <refs_file>

Description:
  Install Livox-SDK2 from source and clone required ROS2 repositories for Livox Gen2 LiDARs.

Arguments:
  pkgs_dir   Directory where repositories will be cloned (created if missing).
  refs_file  File containing required repository refs:
             livox_sdk2 <ref>
             livox_ros_driver2 <ref>
             ros2_launch_helpers <ref>

Notes:
  - refs_file must define the keys: livox_sdk2, livox_ros_driver2, ros2_launch_helpers.
  - Example refs_file content:
      livox_sdk2 main
      livox_ros_driver2 main
      ros2_launch_helpers main
EOF_USAGE
}

log() { printf '[%s] %s\n' "$(date --utc '+%Y-%m-%d_%H-%M-%S')" "$*"; }

require_cmd() {
    local cmd="${1}"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log "ERROR: Missing required command: ${cmd}" >&2
        exit 1
    fi
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -ne 2 ]; then
    log "ERROR: Expected 2 positional arguments: <pkgs_dir> <refs_file>. Got: $*" >&2
    usage
    exit 2
fi

PKGS_DIR="${1}"
REFS_FILE="${2}"

if [ -e "${PKGS_DIR}" ] && [ ! -d "${PKGS_DIR}" ]; then
    log "ERROR: pkgs_dir exists but is not a directory: ${PKGS_DIR}" >&2
    exit 1
fi

if [ ! -f "${REFS_FILE}" ]; then
    log "ERROR: refs_file does not exist: ${REFS_FILE}" >&2
    exit 1
fi

require_cmd git
require_cmd cmake
require_cmd make
require_cmd nproc
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir --parent --verbose "${PKGS_DIR}"
PKGS_DIR="$(cd "${PKGS_DIR}" && pwd)"

LIVOX_SDK2_REF=""
LIVOX_ROS_DRIVER2_REF=""
ROS2_LAUNCH_HELPERS_REF=""
line_number=0

# Read refs_file line by line and validate all required keys are present exactly once.
while IFS= read -r line || [ -n "${line}" ]; do
    line_number=$((line_number + 1))
    trimmed_line="${line#"${line%%[![:space:]]*}"}"

    if [ -z "${trimmed_line}" ] || [[ ${trimmed_line} == \#* ]]; then
        continue
    fi

    repo_key=""
    repo_ref=""
    read -r repo_key repo_ref _ <<<"${trimmed_line}"

    if [ -z "${repo_key}" ] || [ -z "${repo_ref}" ]; then
        log "ERROR: Invalid refs_file format at line ${line_number}. Expected: <repo_key> <ref>" >&2
        exit 2
    fi

    case "${repo_key}" in
    livox_sdk2)
        if [ -n "${LIVOX_SDK2_REF}" ]; then
            log "ERROR: Duplicate key in refs_file at line ${line_number}: livox_sdk2" >&2
            exit 2
        fi
        LIVOX_SDK2_REF="${repo_ref}"
        ;;
    livox_ros_driver2)
        if [ -n "${LIVOX_ROS_DRIVER2_REF}" ]; then
            log "ERROR: Duplicate key in refs_file at line ${line_number}: livox_ros_driver2" >&2
            exit 2
        fi
        LIVOX_ROS_DRIVER2_REF="${repo_ref}"
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

if [ -z "${LIVOX_SDK2_REF}" ]; then
    log "ERROR: Missing required key in refs_file: livox_sdk2" >&2
    exit 2
fi

if [ -z "${LIVOX_ROS_DRIVER2_REF}" ]; then
    log "ERROR: Missing required key in refs_file: livox_ros_driver2" >&2
    exit 2
fi

if [ -z "${ROS2_LAUNCH_HELPERS_REF}" ]; then
    log "ERROR: Missing required key in refs_file: ros2_launch_helpers" >&2
    exit 2
fi

remote_livox_sdk2_repo="https://github.com/jfrascon/livox_sdk2.git"
remote_livox_ros_driver2_repo="https://github.com/jfrascon/livox_ros_driver2.git"
remote_ros2_launch_helpers_repo="https://github.com/jfrascon/ros2_launch_helpers.git"

# Validate that requested refs exist in remote repositories before cloning.
if ! git ls-remote --exit-code --heads --tags "${remote_livox_sdk2_repo}" "${LIVOX_SDK2_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${LIVOX_SDK2_REF}' not found in ${remote_livox_sdk2_repo}" >&2
    exit 1
fi

if ! git ls-remote --exit-code --heads --tags "${remote_livox_ros_driver2_repo}" "${LIVOX_ROS_DRIVER2_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${LIVOX_ROS_DRIVER2_REF}' not found in ${remote_livox_ros_driver2_repo}" >&2
    exit 1
fi

if ! git ls-remote --exit-code --heads --tags "${remote_ros2_launch_helpers_repo}" "${ROS2_LAUNCH_HELPERS_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${ROS2_LAUNCH_HELPERS_REF}' not found in ${remote_ros2_launch_helpers_repo}" >&2
    exit 1
fi

# ----------------------------------------------------------------------------------------------------------------------
# Installing Livox-SDK2 from source.
# ----------------------------------------------------------------------------------------------------------------------

local_livox_sdk2_repo="/tmp/livox_sdk2"
if [ -d "${local_livox_sdk2_repo}" ]; then
    rm -rf "${local_livox_sdk2_repo}"
fi

log "Cloning the repository '${remote_livox_sdk2_repo}' into the path '${local_livox_sdk2_repo}'"
git clone --branch "${LIVOX_SDK2_REF}" --depth 1 "${remote_livox_sdk2_repo}" "${local_livox_sdk2_repo}"

if [ -d "${local_livox_sdk2_repo}/build" ]; then
    rm -rf "${local_livox_sdk2_repo}/build"
fi

mkdir -v "${local_livox_sdk2_repo}/build"
cd "${local_livox_sdk2_repo}/build"
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j"$(nproc)"
make install

# Free space.
cd "${PKGS_DIR}"
rm -rf "${local_livox_sdk2_repo}"

# ----------------------------------------------------------------------------------------------------------------------
# Cloning the 'livox_ros_driver2' package.
# ----------------------------------------------------------------------------------------------------------------------

local_livox_ros_driver2_repo="${PKGS_DIR}/livox_ros_driver2"

if [ -e "${local_livox_ros_driver2_repo}" ]; then
    log "ERROR: Destination directory already exists: ${local_livox_ros_driver2_repo}" >&2
    exit 1
fi

log "Cloning the repository '${remote_livox_ros_driver2_repo}' into the path '${local_livox_ros_driver2_repo}'"
git clone --branch "${LIVOX_ROS_DRIVER2_REF}" --depth 1 "${remote_livox_ros_driver2_repo}" "${local_livox_ros_driver2_repo}"

# Free space.
rm -rf "${local_livox_ros_driver2_repo}/.git"

# ----------------------------------------------------------------------------------------------------------------------
# Installing launch file sensor.launch.py in livox_ros_driver2 package.
# ----------------------------------------------------------------------------------------------------------------------

if [ ! -s "${script_dir}/sensor.launch.py" ]; then
    log "ERROR: Missing file '${script_dir}/sensor.launch.py'" >&2
    exit 1
fi

if [ -f "${local_livox_ros_driver2_repo}/launch_ROS2/sensor.launch.py" ]; then
    rm -f "${local_livox_ros_driver2_repo}/launch_ROS2/sensor.launch.py"
fi

log "Placing the file 'sensor.launch.py' into '${local_livox_ros_driver2_repo}/launch_ROS2/sensor.launch.py'"
install -m 0755 "${script_dir}/sensor.launch.py" "${local_livox_ros_driver2_repo}/launch_ROS2/sensor.launch.py"

# ------------------------------------------------------------------------------
# Cloning 'ros2_launch_helpers' package.
# ------------------------------------------------------------------------------

local_ros2_launch_helpers_repo="${PKGS_DIR}/ros2_launch_helpers"

# The ros2_launch_helpers package might already exist if several sensor setup scripts are
# executed sequentially against the same PKGS_DIR. In that case we keep the existing clone.
if [ ! -d "${local_ros2_launch_helpers_repo}" ]; then
    log "Cloning the repository ${remote_ros2_launch_helpers_repo} into the path ${local_ros2_launch_helpers_repo}"
    git clone --branch "${ROS2_LAUNCH_HELPERS_REF}" --depth 1 "${remote_ros2_launch_helpers_repo}" "${local_ros2_launch_helpers_repo}"
fi

# Free space.
if [ -d "${local_ros2_launch_helpers_repo}/.git" ]; then
    rm -rf "${local_ros2_launch_helpers_repo}/.git"
fi
