#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

usage() {
    cat <<EOF
Usage:
  $(basename ${BASH_SOURCE[0]}) PKGS_DIR

Positional arguments:
  PKGS_DIR  Directory where the ROS packages are located
EOF
}

[ "$#" -lt 1 ] && {
    log "Error: missing required positionals: PKGS_DIR" >&2
    usage
    exit 1
}

PKGS_DIR="${1}"
shift 1

[ "$#" -gt 0 ] && log "Warning: unexpected extra arguments: $*"

[ -z "${PKGS_DIR}" ] && {
    log "Error: PKGS_DIR is empty" >&2
    exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make sure the "${PKGS_DIR}" directory exists.
mkdir --parent --verbose "${PKGS_DIR}"
cd "${PKGS_DIR}" # Set current directory

# ----------------------------------------------------------------------------------------------------------------------
# Cloning the 'Livox-SDK2' library.
# ----------------------------------------------------------------------------------------------------------------------

remote_livox_sdk2_repo="https://github.com/jfrascon/livox_sdk2.git"
local_livox_sdk2_repo="/tmp/livox_sdk2"

[ -d "${local_livox_sdk2_repo}" ] && rm -rf "${local_livox_sdk2_repo}"

log "Cloning the repository '${remote_livox_sdk2_repo}' into the path '${local_livox_sdk2_repo}'"
git clone --branch main --single-branch "${remote_livox_sdk2_repo}" "${local_livox_sdk2_repo}"

[ -d "${local_livox_sdk2_repo}/build" ] && rm -rf "${local_livox_sdk2_repo}/build"
mkdir -v "${local_livox_sdk2_repo}/build"

cd "${local_livox_sdk2_repo}/build"
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
make install

# Free space.
cd "${PKGS_DIR}" # Get out of the build directory.
rm -rf "${local_livox_sdk2_repo}"

# ----------------------------------------------------------------------------------------------------------------------
# Cloning the 'livox_ros_driver2' package.
# ----------------------------------------------------------------------------------------------------------------------

remote_livox_ros_driver2_repo="https://github.com/jfrascon/livox_ros_driver2.git"
local_livox_ros_driver2_repo="${PKGS_DIR}/livox_ros_driver2"

[ -d "${local_livox_ros_driver2_repo}" ] && rm -rf "${local_livox_ros_driver2_repo}"

log "Cloning the repository '${remote_livox_ros_driver2_repo}' into the path '${local_livox_ros_driver2_repo}'"
git clone --branch main --single-branch "${remote_livox_ros_driver2_repo}" "${local_livox_ros_driver2_repo}"

# Free space.
rm -rf "${local_livox_ros_driver2_repo}/.git"

# ----------------------------------------------------------------------------------------------------------------------
# Installing launch file eut_sensor.launch.py
# ----------------------------------------------------------------------------------------------------------------------

[ -f "${local_livox_ros_driver2_repo}/launch_ROS2/eut_sensor.launch.py" ] && rm -f "${local_livox_ros_driver2_repo}/launch_ROS2/eut_sensor.launch.py"

log "Placing the file 'eut_sensor.launch.py' into '${local_livox_ros_driver2_repo}/launch_ROS2/eut_sensor.launch.py'"
install -m 0755 "${script_dir}/eut_sensor.launch.py" "${local_livox_ros_driver2_repo}/launch_ROS2/eut_sensor.launch.py"

# ------------------------------------------------------------------------------
# Cloning 'ros2_launch_helpers' package.
# ------------------------------------------------------------------------------

remote_ros2_launch_helpers_repo="https://github.com/jfrascon/ros2_launch_helpers.git"
local_ros2_launch_helpers_repo="${PKGS_DIR}/ros2_launch_helpers"

# The ros2_launch_helpers package might have been already cloned when installing other sensors.
# For that reason, we check before cloning if the package is already present.
if [ ! -d "${local_ros2_launch_helpers_repo}" ]; then
    log "Cloning the repository ${remote_ros2_launch_helpers_repo} into the path ${local_ros2_launch_helpers_repo}"
    git clone --branch main --single-branch "${remote_ros2_launch_helpers_repo}" "${local_ros2_launch_helpers_repo}"
fi

# Free space.
[ -d "${local_ros2_launch_helpers_repo}/.git" ] && rm -rf "${local_ros2_launch_helpers_repo}/.git"
