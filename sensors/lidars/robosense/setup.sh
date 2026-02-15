#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF_USAGE
Usage:
  $(basename "${BASH_SOURCE[0]}") <pkgs_dir> <refs_file>

Description:
  Install dependencies and clone required ROS2 repositories for RoboSense LiDARs.

Arguments:
  pkgs_dir   Directory where repositories will be cloned (created if missing).
  refs_file  File containing required repository refs:
             rslidar_sdk <ref>
             rslidar_msg <ref>
             ros2_launch_helpers <ref>

Notes:
  - refs_file must define the keys: rslidar_sdk, rslidar_msg, ros2_launch_helpers.
  - Example refs_file content:
      rslidar_sdk main
      rslidar_msg main
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir --parent --verbose "${PKGS_DIR}"
PKGS_DIR="$(cd "${PKGS_DIR}" && pwd)"

RSLIDAR_SDK_REF=""
RSLIDAR_MSG_REF=""
ROS2_LAUNCH_HELPERS_REF=""
line_number=0

# Read refs_file line by line and validate all required keys are present exactly once.
while IFS= read -r line || [ -n "${line}" ]; do
    line_number=$((line_number + 1))
    trimmed_line="${line#"${line%%[![:space:]]*}"}"

    if [ -z "${trimmed_line}" ] || [[ "${trimmed_line}" == \#* ]]; then
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
    rslidar_sdk)
        if [ -n "${RSLIDAR_SDK_REF}" ]; then
            log "ERROR: Duplicate key in refs_file at line ${line_number}: rslidar_sdk" >&2
            exit 2
        fi
        RSLIDAR_SDK_REF="${repo_ref}"
        ;;
    rslidar_msg)
        if [ -n "${RSLIDAR_MSG_REF}" ]; then
            log "ERROR: Duplicate key in refs_file at line ${line_number}: rslidar_msg" >&2
            exit 2
        fi
        RSLIDAR_MSG_REF="${repo_ref}"
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

if [ -z "${RSLIDAR_SDK_REF}" ]; then
    log "ERROR: Missing required key in refs_file: rslidar_sdk" >&2
    exit 2
fi

if [ -z "${RSLIDAR_MSG_REF}" ]; then
    log "ERROR: Missing required key in refs_file: rslidar_msg" >&2
    exit 2
fi

if [ -z "${ROS2_LAUNCH_HELPERS_REF}" ]; then
    log "ERROR: Missing required key in refs_file: ros2_launch_helpers" >&2
    exit 2
fi

# Maintained forks are used because they include fixes and ROS2 improvements not available in upstream.
remote_rslidar_sdk_repo="https://github.com/jfrascon/rslidar_sdk.git"
remote_rslidar_msg_repo="https://github.com/RobotnikAutomation/rslidar_msg.git"
remote_ros2_launch_helpers_repo="https://github.com/jfrascon/ros2_launch_helpers.git"

# Validate that requested refs exist in remote repositories before cloning.
if ! git ls-remote --exit-code --heads --tags "${remote_rslidar_sdk_repo}" "${RSLIDAR_SDK_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${RSLIDAR_SDK_REF}' not found in ${remote_rslidar_sdk_repo}" >&2
    exit 1
fi

if ! git ls-remote --exit-code --heads --tags "${remote_rslidar_msg_repo}" "${RSLIDAR_MSG_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${RSLIDAR_MSG_REF}' not found in ${remote_rslidar_msg_repo}" >&2
    exit 1
fi

# The ros2_launch_helpers package might already exist if several sensor setup scripts are
# executed sequentially against the same PKGS_DIR. We still validate the requested ref.
if ! git ls-remote --exit-code --heads --tags "${remote_ros2_launch_helpers_repo}" "${ROS2_LAUNCH_HELPERS_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${ROS2_LAUNCH_HELPERS_REF}' not found in ${remote_ros2_launch_helpers_repo}" >&2
    exit 1
fi

# ----------------------------------------------------------------------------------------------------------------------
# Installing dependencies required by rslidar_sdk/rs_driver.
# ----------------------------------------------------------------------------------------------------------------------

apt-get update

log "Installing dependencies required by rslidar_sdk"
apt-get install --yes --no-install-recommends \
    libpcap-dev \
    libyaml-cpp-dev

# ----------------------------------------------------------------------------------------------------------------------
# Cloning the 'rslidar_sdk' package.
# ----------------------------------------------------------------------------------------------------------------------

local_rslidar_sdk_repo="${PKGS_DIR}/rslidar_sdk"

if [ -e "${local_rslidar_sdk_repo}" ]; then
    log "ERROR: Destination directory already exists: ${local_rslidar_sdk_repo}" >&2
    exit 1
fi

log "Cloning the repository '${remote_rslidar_sdk_repo}' into the path '${local_rslidar_sdk_repo}'"
git clone --branch "${RSLIDAR_SDK_REF}" --depth 1 "${remote_rslidar_sdk_repo}" "${local_rslidar_sdk_repo}"

# Synchronize and fetch rs_driver submodule required by rslidar_sdk.
git -C "${local_rslidar_sdk_repo}" submodule sync --recursive
git -C "${local_rslidar_sdk_repo}" submodule update --init --recursive --checkout --jobs 4

# Free space.
rm -rf "${local_rslidar_sdk_repo}/.git"
if [ -d "${local_rslidar_sdk_repo}/src/rs_driver/.git" ]; then
    rm -rf "${local_rslidar_sdk_repo}/src/rs_driver/.git"
fi

# ----------------------------------------------------------------------------------------------------------------------
# Installing launch file eut_sensor.launch.py in rslidar_sdk package.
# ----------------------------------------------------------------------------------------------------------------------

if [ ! -s "${script_dir}/eut_sensor.launch.py" ]; then
    log "ERROR: Missing file '${script_dir}/eut_sensor.launch.py'" >&2
    exit 1
fi

if [ -f "${local_rslidar_sdk_repo}/launch/eut_sensor.launch.py" ]; then
    rm -f "${local_rslidar_sdk_repo}/launch/eut_sensor.launch.py"
fi

log "Placing the file 'eut_sensor.launch.py' into '${local_rslidar_sdk_repo}/launch/eut_sensor.launch.py'"
install -m 0755 "${script_dir}/eut_sensor.launch.py" "${local_rslidar_sdk_repo}/launch/eut_sensor.launch.py"

# ----------------------------------------------------------------------------------------------------------------------
# Cloning the 'rslidar_msg' package.
# ----------------------------------------------------------------------------------------------------------------------

local_rslidar_msg_repo="${PKGS_DIR}/rslidar_msg"

if [ -e "${local_rslidar_msg_repo}" ]; then
    log "ERROR: Destination directory already exists: ${local_rslidar_msg_repo}" >&2
    exit 1
fi

log "Cloning the repository '${remote_rslidar_msg_repo}' into the path '${local_rslidar_msg_repo}'"
git clone --branch "${RSLIDAR_MSG_REF}" --depth 1 "${remote_rslidar_msg_repo}" "${local_rslidar_msg_repo}"

# Free space.
rm -rf "${local_rslidar_msg_repo}/.git"

# ----------------------------------------------------------------------------------------------------------------------
# Cloning 'ros2_launch_helpers' package.
# ----------------------------------------------------------------------------------------------------------------------

local_ros2_launch_helpers_repo="${PKGS_DIR}/ros2_launch_helpers"

if [ ! -d "${local_ros2_launch_helpers_repo}" ]; then
    log "Cloning the repository '${remote_ros2_launch_helpers_repo}' into the path '${local_ros2_launch_helpers_repo}'"
    git clone --branch "${ROS2_LAUNCH_HELPERS_REF}" --depth 1 "${remote_ros2_launch_helpers_repo}" "${local_ros2_launch_helpers_repo}"
fi

# Free space.
if [ -d "${local_ros2_launch_helpers_repo}/.git" ]; then
    rm -rf "${local_ros2_launch_helpers_repo}/.git"
fi
