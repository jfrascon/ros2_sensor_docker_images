#!/usr/bin/env bash
set -euo pipefail

# Responsibilities:
#  - Install native/SDK packages required by the vendor driver (APT, debs, etc.).
#  - Clone/copy the ROS2 wrapper(s) into ${PKGS_DIR}.
#  - Place eut_sensor.launch.py into the wrapper’s launch directory.
#  - Write rosdep keys to ignore during 'rosdep install', if needed.
#  - DO NOT run 'rosdep install' or 'colcon build' here. The Dockerfile will do that once for the whole workspace.

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

usage() {
    cat <<EOF
Usage:
  ${script_name} PKGS_DIR [--ros-distro <distro> --ignored-keys-file <file> --options-file <file.json> --help]

Positional arguments:
  PKGS_DIR  Directory where the ROS packages are located

Options:
  --ros-distro                   Target ROS2 distribution (e.g., humble, jazzy)
  --ignored-keys-file file       File to write rosdep keys to ignore
  --options-file      file.json  YAML file with extra options for this script
EOF
}

script="${BASH_SOURCE:-${0}}"
script_name="$(basename "${script}")"

# Normalize arguments with GNU getopt.
# -o ''     -> no short options
# -l ...    -> long options; ":" ⇒ option requires a value
# --        -> end of getopt's own flags; after this, pass script args to parse
# "$@"      -> forward all original args verbatim (keeps spaces/quotes)
# getopt    -> normalizes: reorders options first, splits values, appends a final "--"
# on error  -> exits non-zero; we show usage and exit 2
PARSED=$(getopt \
    -o '' \
    -l ros-distro:,ignored-keys-file:,options-file:,help \
    -- "$@") || {
    usage
    exit 1
}

# Replace $@ with the normalized list; eval preserves quoting from getopt’s output.
eval set -- "$PARSED"

# After eval set -- ... we get:
# --ros-distro <distro> --ignored-keys-file <file> --options-file <file.json> -- PKGS_DIR
# -- is the end of options marker

ros_distro="" # ros_ditro might be used if needed and passed
rosdep_ignored_keys_file=""
options_file=""

while true; do
    case "${1:-}" in
    --ros-distro)
        ros_distro="${2}"
        shift 2
        ;;
    --ignored-keys-file)
        rosdep_ignored_keys_file="${2}"
        shift 2
        ;;
    --options-file)
        options_file="${2}"
        shift 2
        ;;
    --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *)
        usage
        exit 2
        ;;
    esac
done

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

script_dir="$(cd "$(dirname "${script}")" && pwd)"

# Make sure the "${PKGS_DIR}" directory exists.
mkdir --parent --verbose "${PKGS_DIR}"
cd "${PKGS_DIR}" # Set current directory

# ----------------------------------------------------------------------------------------------------------------------
# Installing dependencies for 'librealsense2' library.
# ----------------------------------------------------------------------------------------------------------------------
# Links in order.
# Indentation means that each link comes from the previous one.
# If at the same level means they both come from the previous one.
# Reference: https://github.com/IntelRealSense/realsense-ros?tab=readme-ov-file#option-3-build-from-source
#   Reference: https://github.com/IntelRealSense/librealsense?tab=readme-ov-file
#     Reference: https://github.com/IntelRealSense/librealsense/blob/master/doc/distribution_linux.md
#       Reference: https://github.com/IntelRealSense/librealsense/blob/master/doc/installation.md <-- Interesting!
#       Refenrence: https://github.com/IntelRealSense/librealsense/blob/master/scripts/Docker/readme.md#Running-the-Container
#         Reference: https://github.com/IntelRealSense/librealsense/blob/master/scripts/Docker/Dockerfile

# This reference is also worth mentioning:
# https://github.com/2b-t/realsense-ros2-docker?tab=readme-ov-file

# Instructions obtained from reference: https://github.com/IntelRealSense/librealsense/blob/master/scripts/Docker/Dockerfile

apt-get update

log "Installing dependencies required by librealsense2"

# Install the core packages required to build librealsense binaries.
apt-get install --yes --no-install-recommends libssl-dev \
    libusb-1.0-0-dev \
    libgtk-3-dev \
    libudev-dev \
    udev || {
    log "Installation of dependencies required by librealsense2 failed" >&2
    exit 1
}

# pkg-config already installed in the base image.

# The following packages are required for development environment.
# libglfw3-dev \
# libgl1-mesa-dev \
# libglu1-mesa-dev \
# python3-dev \

# ----------------------------------------------------------------------------------------------------------------------
# Setting up 'librealsense2' library.
# ----------------------------------------------------------------------------------------------------------------------

remote_librealsense2_repo="https://github.com/IntelRealSense/librealsense.git"
local_librealsense2_repo="/tmp/librealsense2"

[ -d "${local_librealsense2_repo}" ] && rm -rf "${local_librealsense2_repo}"

log "Cloning the repository '${remote_librealsense2_repo}' into the path '${local_librealsense2_repo}'"
git clone "${remote_librealsense2_repo}" "${local_librealsense2_repo}"

# This script builds docker image of the latest librealsense github tag #
# Get the latest git TAG version
lib_git_tag="$(git -C "${local_librealsense2_repo}" describe --abbrev=0 --tags)"
log "Building librealsense2 version ${lib_git_tag}"
git -C "${local_librealsense2_repo}" checkout "${lib_git_tag}"

[ -d "${local_librealsense2_repo}/build" ] && rm -rf "${local_librealsense2_repo}/build"
mkdir -v "${local_librealsense2_repo}/build"

build_with_cuda=OFF

if [ -n "${options_file}" ]; then
    if [ -s "${options_file}" ]; then
        log "Reading options from file '${options_file}'"

        # If key does not exist or it is false, it returns "OFF".
        # If the key is true, it returns "ON".
        build_with_cuda="$(jq -r 'if .realsense.build_with_cuda then "ON" else "OFF" end' ${options_file})"
    else
        log "Warning: Options file '${options_file}' is empty. Using default options."
    fi
fi

cd "${local_librealsense2_repo}/build"
# Read notes below regarding RSUSB vs V4L2 backends.
cmake -DBUILD_EXAMPLES=OFF \
    -DBUILD_GRAPHICAL_EXAMPLES=OFF \
    -DFORCE_RSUSB_BACKEND=ON \
    -DBUILD_WITH_CUDA="${build_with_cuda}" \
    -DCMAKE_BUILD_TYPE=Release ..
# -DBUILD_PYTHON_BINDINGS=ON necessary for a development environment.
make -j$(($(nproc) - 1)) all
make install

# Free space.
cd "${PKGS_DIR}" # Get out of the build directory.
rm -rf "${local_librealsense2_repo}"

remote_realsense_ros="https://github.com/IntelRealSense/realsense-ros.git"
local_realsense_ros="${PKGS_DIR}/realsense-ros"

[ -d "${local_realsense_ros}" ] && rm -rf "${local_realsense_ros}"

log "Cloning the repository '${remote_realsense_ros}' into the path '${local_realsense_ros}'"
git clone "${remote_realsense_ros}" "${local_realsense_ros}"

# Free space.
rm -rf "${local_realsense_ros}/.git"

# ----------------------------------------------------------------------------------------------------------------------
# Installing launch file eut_sensor.launch.py
# ----------------------------------------------------------------------------------------------------------------------

[ -f "${local_realsense_ros}/launch/eut_sensor.launch.py" ] && rm -f "${local_realsense_ros}/launch/eut_sensor.launch.py"

log "Placing eut_sensor.launch.py into ${local_realsense_ros}/realsense2_camera/launch/eut_sensor.launch.py"
install -m 0755 "${script_dir}/eut_sensor.launch.py" "${local_realsense_ros}/realsense2_camera/launch/eut_sensor.launch.py"

# ----------------------------------------------------------------------------------------------------------------------
# Write rosdep keys to ignore during 'rosdep install', if needed.
# ----------------------------------------------------------------------------------------------------------------------

[ -z "${rosdep_ignored_keys_file}" ] && {
    log "No rosdep ignored keys file provided. Skipping writing rosdep ignored keys."
    return 0
}

# Ref: https://github.com/ros-infrastructure/rosdep/issues/649
# Locally ignore rosdep keys using empty list of packages: https://github.com/ros-infrastructure/rosdep/issues/649
rosdep_ignored_keys=("librealsense2: {ubuntu: []}")

# -q, --quiet: Suppress normal output.
# -x, --line-regexp: Select only those matches that exactly match the whole line.
# -F, --fixed-strings: Interpret the pattern as fixed strings, not regular expressions.
for key in "${rosdep_ignored_keys[@]}"; do
    if ! grep -qxF -- "${key}" -- "${rosdep_ignored_keys_file}"; then
        printf '%s\n' "${key}" >>"${rosdep_ignored_keys_file}"
        log "Added rosdep key to ignore, '${key}', to file '${rosdep_ignored_keys_file}'"
    else
        log "Rosdep key to ignore '${key}' already exists in file '${rosdep_ignored_keys_file}'. Skipping adding it again."
    fi
done

# Context: RealSense backends (RSUSB/libuvc vs V4L2) and Docker implications
#
# - Choosing RSUSB/libuvc avoids kernel patching on the host, but performance/latency can be worse in some
#   pipelines. On Jetson, you can mitigate with -DBUILD_WITH_CUDA=ON.
# - Choosing the native V4L2 backend typically requires host kernel patches (PC Ubuntu via
#   patch-realsense-ubuntu-*.sh; Jetson via patch-realsense-ubuntu-L4T.sh).
# - Docker does NOT change the backend’s nature. You still must expose host devices and grant permissions
#   properly to the container.
#
# What are RSUSB and V4L2?
# - V4L2 (native kernel backend):
#   * librealsense uses kernel UVC/V4L2 drivers for the camera.
#   * Enabling the full feature set (e.g., hardware timestamps, D4xx metadata) historically required kernel
#     modules/patches provided by librealsense scripts.
#   * This must be done on the host: install/update the kernel modules on the computer
#     where the camera is physically connected (Ubuntu PC or Jetson L4T).
#
# - RSUSB (user-space backend over libusb):
#   * librealsense implements its own user-space backend (libusb), avoiding kernel version dependencies and
#     kernel patching.
#   * Pros: portable across heterogeneous kernels/SoCs (useful with Jetson and ARM64 PCs), simpler deployment.
#   * Cons: historically higher latency or reduced performance in some cases (many are now mitigated). In
#     summary: no kernel patches required, more portable.
#
# How this applies when using Docker
# - The RSUSB vs V4L2 choice is about how librealsense is built and run. Docker does not change that choice;
#   it only adds the requirement to pass host devices and permissions through to the container.
#
# If you choose native V4L2:
# - HOST: install udev rules and (if needed) apply kernel patches compatible with your distro.
#   On Ubuntu PCs use ./scripts/patch-realsense-ubuntu-*.sh; on Jetson Orin Nano use
#   ./scripts/patch-realsense-ubuntu-L4T.sh on the HOST.
# - CONTAINER: install librealsense2 (binaries) and mount /dev/video* and /dev/bus/usb with appropriate
#   device-cgroup rules.
#
# If you choose RSUSB:
# - HOST: you still need udev rules for permissions, but no kernel patches.
# - CONTAINER: build librealsense with -DFORCE_RSUSB_BACKEND=ON (and on Jetson you may add
#   -DBUILD_WITH_CUDA=ON). Mount USB/V4L2 devices as with V4L2.
#
# In BOTH cases, Docker needs access to host devices:
#   -v /dev/bus/usb:/dev/bus/usb
#   -v /run/udev:/run/udev:ro
#   --device /dev/video*
#   --device-cgroup-rule 'c 189:* rmw'   # USB
#   --device-cgroup-rule 'c 81:* rmw'    # V4L2
# This is what many guides describe as “grant access to the USB and UVC resources of the host PC”.
#
# Practical checklist
# HOST (always):
# - Install librealsense udev rules (permissions/symlinks).
# - Only for native V4L2: apply the corresponding kernel patch script (Ubuntu LTS/HWE on PC; L4T on Jetson).
# - Verify on the HOST before Docker: `rs-enumerate-devices --compact` and `ls -l /dev/video* /dev/bus/usb/*/*`.
#
# DOCKERFILE / CONTAINER:
# - Build/install librealsense:
#   * RSUSB: use -DFORCE_RSUSB_BACKEND=ON (portability; no host patches).
#   * V4L2: build without FORCE_RSUSB assuming the HOST kernel is already patched.
# - Build/install realsense-ros wrapper as needed.
