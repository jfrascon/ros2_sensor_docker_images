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
# Installing dependencies for 'rslidar_sdk' and 'rs_driver' packages.
# ----------------------------------------------------------------------------------------------------------------------

# Dependencies required by the rs_driver:
# (https://github.com/RoboSense-LiDAR/rs_driver?tab=readme-ov-file#14-dependency-libraries)
# libpcap-dev: optional, needed to parse PCAP files.
# libeigen3-dev: optional, needed to use the internal transformation function.
# libboost-dev: optional, needed to build the visualization tool.
# libpcl-dev: optional, needed to build the visualization tool.

# Dependency required by rslidar_sdk ros package:
# (https://github.com/RoboSense-LiDAR/rslidar_sdk?tab=readme-ov-file#33-yaml-essential)
# (https://github.com/RoboSense-LiDAR/rslidar_sdk?tab=readme-ov-file#34-libpcap-essential)
# libpcap-dev (essential): version: >= v1.7.4.
# libyaml-cpp-dev (essential), version: >= v0.5.2.

apt-get update

log "Installing dependencies required by rslidar_sdk"

# Since the package 'libeigen3-dev' is not installed, the internal transformation function will not be built in the
# compilation stage.
# Since the packages 'libboost-dev' and 'libpcl-dev' are not installed, the visualization tool will not be built in the
# compilation stage.
apt-get install --yes --no-install-recommends \
    libpcap-dev \
    libyaml-cpp-dev || {
    log "Installation of dependencies required by rslidar_sdk failed" >&2
    exit 1
}

# ----------------------------------------------------------------------------------------------------------------------
# Cloning the 'rslidar_sdk' package.
# ----------------------------------------------------------------------------------------------------------------------

remote_rslidar_sdk_repo="https://github.com/jfrascon/rslidar_sdk.git"
local_rslidar_sdk_repo="${PKGS_DIR}/rslidar_sdk"

[ -d "${local_rslidar_sdk_repo}" ] && rm -rf "${local_rslidar_sdk_repo}"

log "Cloning the repository ${remote_rslidar_sdk_repo} into the path ${local_rslidar_sdk_repo}"
git clone --branch main --single-branch "${remote_rslidar_sdk_repo}" "${local_rslidar_sdk_repo}"

# Synchronize subdmodules' URLs.
git -C "${local_rslidar_sdk_repo}" submodule sync --recursive
git -C "${local_rslidar_sdk_repo}" submodule update --init --recursive --checkout --jobs 4

# Free space.
rm -rf "${local_rslidar_sdk_repo}/.git"
rm -rf "${local_rslidar_sdk_repo}/src/rs_driver/.git"

# PRs to consider in the 'rslidar_sdk' repo.
#-------------------------------------------------------------------------------
# As of 2025-09-13, there are 4 PRs open in the rslidar_sdk repo:
# PR #171: Fix SI units as per ROS convention (fixes #165), opened on Apr 8 by MCFurry.
# PR #175: [feat]: Add ROS2 component, opened on May 9 by georgflick.
# PR #191: enable IMU, opened on Jul 7 by asiagkri.
# PR #195: feat: enable IMU, opened on Jul 22 by wenli7363.

# PR #171: Fix SI units as per ROS convention (fixes #165), opened on Apr 8 by MCFurry
# One could be very tempted to merge this PR, but it has some issues:
# Last comment August 5, 2025 says:
# "Might be bit more problematic, the E1 seems to send data in m/s2 where Airy sends in G:s so these would need per
# "model specification or FW update to stay consistent."

# So, I will not merge this PR for now, until RoboSense clarifies this point.
# For now, if I use a Robosense lidar that sends the acceleration in G, like the Airy model, I can set up a
# man-in-the-middle ROS2 node that converts the acceleration from G to m/s^2.
# If I use a Robosense lidar that sends the acceleration in m/s^2, like the E1 model, then I do not need to do
# anything.

# PR #175: [feat]: Add ROS2 component, opened on May 9 by georgflick.
# For the time being, I can ignore this PR. It's nice to have a component, but not essential.

# PR #191 and #195,refer to the same feature, IMU support.
# I will activate IMU processing by using '-DENABLE_IMU_DATA_PARSE=ON' when compiling the 'rslidar_sdk' package with
# colcon.

# ------------------------------------------------------------------------------
# Installing launch file eut_sensor.launch.py
# ------------------------------------------------------------------------------

[ ! -s "${script_dir}/eut_sensor.launch.py" ] && {
    log "Error: Missing file '${script_dir}/eut_sensor.launch.py'" >&2
    exit 1
}

log "Placing eut_sensor.launch.py into ${local_rslidar_sdk_repo}/launch/eut_sensor.launch.py"
install -m 0755 "${script_dir}/eut_sensor.launch.py" "${local_rslidar_sdk_repo}/launch/eut_sensor.launch.py"

# ------------------------------------------------------------------------------
# Cloning 'rslidar_msg' package.
# ------------------------------------------------------------------------------

# RobotnikAutomation fork is more up-to-date than the original one.
# Specifically, the Robotnik repo support both ROS and ROS2 environments in the rslidar_msg project. The most important
# changes include modifications to the CMakeLists.txt and package.xml files to conditionally handle dependencies and
# configurations for ROS and ROS2, as well as cleanup of redundant files.
remote_rslidar_msg_repo="https://github.com/RobotnikAutomation/rslidar_msg.git"
local_rslidar_msg_repo="${PKGS_DIR}/rslidar_msg"

[ -d "${local_rslidar_msg_repo}" ] && rm -rf "${local_rslidar_msg_repo}"

log "Cloning the repository ${remote_rslidar_msg_repo} into the path ${local_rslidar_msg_repo}"
git clone --branch main --single-branch "${remote_rslidar_msg_repo}" "${local_rslidar_msg_repo}"

# Free space.
rm -rf "${local_rslidar_msg_repo}/.git"

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
