#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF_USAGE
Usage:
  $(basename "${BASH_SOURCE[0]}") <pkgs_dir> <refs_file>

Description:
  Clone required repositories for UMX and create a local bringup package with the launch file.

Arguments:
  pkgs_dir   Directory where repositories will be cloned (created if missing).
  refs_file  File containing required repository refs:
             serial-ros2 <ref>
             um7 <ref>
             ros2_launch_helpers <ref>

Notes:
  - refs_file must define the keys: serial-ros2, um7, ros2_launch_helpers.
  - Example refs_file content:
      serial-ros2 master
      um7 ros2
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

SERIAL_REF=""
UM7_REF=""
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
    # Extra fields in the same line are ignored intentionally.
    read -r repo_key repo_ref _ <<<"${trimmed_line}"

    if [ -z "${repo_key}" ] || [ -z "${repo_ref}" ]; then
        log "ERROR: Invalid refs_file format at line ${line_number}. Expected: <repo_key> <ref>" >&2
        exit 2
    fi

    case "${repo_key}" in
    serial-ros2)
        if [ -n "${SERIAL_REF}" ]; then
            log "ERROR: Duplicate key in refs_file at line ${line_number}: serial-ros2" >&2
            exit 2
        fi
        SERIAL_REF="${repo_ref}"
        ;;
    um7)
        if [ -n "${UM7_REF}" ]; then
            log "ERROR: Duplicate key in refs_file at line ${line_number}: um7" >&2
            exit 2
        fi
        UM7_REF="${repo_ref}"
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

if [ -z "${SERIAL_REF}" ]; then
    log "ERROR: Missing required key in refs_file: serial-ros2" >&2
    exit 2
fi

if [ -z "${UM7_REF}" ]; then
    log "ERROR: Missing required key in refs_file: um7" >&2
    exit 2
fi

if [ -z "${ROS2_LAUNCH_HELPERS_REF}" ]; then
    log "ERROR: Missing required key in refs_file: ros2_launch_helpers" >&2
    exit 2
fi

# ----------------------------------------------------------------------------------------------------------------------
# Setting up 'serial-ros2' package.
# ----------------------------------------------------------------------------------------------------------------------

remote_serial_repo="https://github.com/RoverRobotics-forks/serial-ros2.git"
local_serial_repo="${PKGS_DIR}/serial-ros2"

if [ -e "${local_serial_repo}" ]; then
    log "ERROR: Destination directory already exists: ${local_serial_repo}" >&2
    exit 1
fi

# Validate that the requested ref exists in the remote repository before cloning.
if ! git ls-remote --exit-code --heads --tags "${remote_serial_repo}" "${SERIAL_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${SERIAL_REF}' not found in ${remote_serial_repo}" >&2
    exit 1
fi

log "Cloning the repository '${remote_serial_repo}' into the path '${local_serial_repo}'"
git clone --branch "${SERIAL_REF}" --depth 1 "${remote_serial_repo}" "${local_serial_repo}"

# Free space.
rm -rf "${local_serial_repo}/.git"

# ------------------------------------------------------------------------------
# Setting up 'um7' package.
# ------------------------------------------------------------------------------

remote_um7_repo="https://github.com/ros-drivers/um7.git"
local_um7_repo="${PKGS_DIR}/um7" # For um6 and um7 imus.

if [ -e "${local_um7_repo}" ]; then
    log "ERROR: Destination directory already exists: ${local_um7_repo}" >&2
    exit 1
fi

# Validate that the requested ref exists in the remote repository before cloning.
if ! git ls-remote --exit-code --heads --tags "${remote_um7_repo}" "${UM7_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${UM7_REF}' not found in ${remote_um7_repo}" >&2
    exit 1
fi

log "Cloning the repository '${remote_um7_repo}' into the path '${local_um7_repo}'"
git clone --branch "${UM7_REF}" --depth 1 "${remote_um7_repo}" "${local_um7_repo}"

# Free space.
rm -rf "${local_um7_repo}/.git"

# ------------------------------------------------------------------------------
# Creating local bringup package 'umx_bringup'
# ------------------------------------------------------------------------------

# The repository cloned for this sensor is 'um7', but the ROS package name is 'umx_driver'.
# That package provides the driver executables, but it does not provide a launch directory.
# In this project we run sensors through launch files (same operational pattern used in other sensors),
# so we create a minimal local package 'umx_bringup' under PKGS_DIR to host our launch entry point.
#
# 'umx_bringup' is responsible for:
# - owning and installing 'launch/sensor.launch.py',
# - depending on 'umx_driver',
# - giving us a stable entry point: 'ros2 launch umx_bringup sensor.launch.py'.
#
# This keeps runtime behavior explicit and avoids relying on upstream repository layout details.

local_umx_bringup_repo="${PKGS_DIR}/umx_bringup"

if [ -e "${local_umx_bringup_repo}" ]; then
    log "ERROR: Destination directory already exists: ${local_umx_bringup_repo}" >&2
    exit 1
fi

mkdir -pv "${local_umx_bringup_repo}/launch"

cat >"${local_umx_bringup_repo}/package.xml" <<'EOF_PACKAGE_XML'
<?xml version="1.0"?>
<package format="3">
  <name>umx_bringup</name>
  <version>0.1.0</version>
  <description>Bringup package for UMX sensors using umx_driver.</description>
  <maintainer email="noreply@example.com">noreply</maintainer>
  <license>Apache-2.0</license>

  <buildtool_depend>ament_cmake</buildtool_depend>

  <exec_depend>launch</exec_depend>
  <exec_depend>launch_ros</exec_depend>
  <exec_depend>umx_driver</exec_depend>

  <export>
    <build_type>ament_cmake</build_type>
  </export>
</package>
EOF_PACKAGE_XML

cat >"${local_umx_bringup_repo}/CMakeLists.txt" <<'EOF_CMAKE'
cmake_minimum_required(VERSION 3.8)
project(umx_bringup)

find_package(ament_cmake REQUIRED)

install(DIRECTORY launch
  DESTINATION share/${PROJECT_NAME})

ament_package()
EOF_CMAKE

if [ ! -s "${script_dir}/sensor.launch.py" ]; then
    log "ERROR: Missing file '${script_dir}/sensor.launch.py'" >&2
    exit 1
fi

log "Placing the file 'sensor.launch.py' into '${local_umx_bringup_repo}/launch/sensor.launch.py'"
install -m 0755 "${script_dir}/sensor.launch.py" "${local_umx_bringup_repo}/launch/sensor.launch.py"

# ------------------------------------------------------------------------------
# Cloning 'ros2_launch_helpers' package.
# ------------------------------------------------------------------------------

remote_ros2_launch_helpers_repo="https://github.com/jfrascon/ros2_launch_helpers.git"
local_ros2_launch_helpers_repo="${PKGS_DIR}/ros2_launch_helpers"

# Validate that the requested ref exists in the remote repository before cloning.
if ! git ls-remote --exit-code --heads --tags "${remote_ros2_launch_helpers_repo}" "${ROS2_LAUNCH_HELPERS_REF}" >/dev/null 2>&1; then
    log "ERROR: Remote ref '${ROS2_LAUNCH_HELPERS_REF}' not found in ${remote_ros2_launch_helpers_repo}" >&2
    exit 1
fi

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
