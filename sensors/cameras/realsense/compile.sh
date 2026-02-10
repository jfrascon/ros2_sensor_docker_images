#!/usr/bin/env bash
set -euo pipefail

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%d_%H-%M-%S')" "$*"; }

usage() {
    cat <<EOF
Usage:
  $(basename "${BASH_SOURCE[0]}") PKGS_DIR [--symlink-install] [--help|-h]

Positional arguments:
  PKGS_DIR  Directory where the ROS packages are located

Options:
  --symlink-install    Build packages with symlink install
  -h, --help           Show this help message and exit
EOF
}

SHORT_OPTS="h"
LONG_OPTS="help,symlink-install"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

# Replace $@ with the normalized list; eval preserves quoting from getopt's output.
eval set -- "${PARSED_ARGS}"

# After eval set -- ... we get:
# --symlink-install -- PKGS_DIR
# -- is the end of options marker

colcon_flags=()

while true; do
    case "${1:-}" in
    --symlink-install)
        colcon_flags+=(--symlink-install)
        shift 1
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

colcon_flags+=(
    --merge-install
    --mixin release
    --cmake-args
    -DCMAKE_CXX_FLAGS="-Wall -Wextra -Wpedantic -Wnon-virtual-dtor -Woverloaded-virtual -Wnull-dereference -Wunused-parameter"
    -Wno-dev
)

[ "$#" -lt 1 ] && {
    log "ERROR: missing required positionals: PKGS_DIR" >&2
    usage
    exit 1
}

PKGS_DIR="${1}"
shift

if [ "$#" -ne 0 ]; then
    log "ERROR: Unexpected positional arguments: $*" >&2
    usage
    exit 2
fi

if [ -z "${PKGS_DIR}" ]; then
    log "ERROR: PKGS_DIR is empty" >&2
    exit 1
fi

if [ ! -d "${PKGS_DIR}" ]; then
    log "ERROR: PKGS_DIR '${PKGS_DIR}' does not exist or is not a directory" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Compiling the 'realsense2_camera_msgs' package.
# ------------------------------------------------------------------------------

cd "$(dirname "${PKGS_DIR}")" # Go to parent of PKGS_DIR
log "Compiling the 'realsense2_camera_msgs' package"
colcon build --packages-skip-build-finished --packages-select realsense2_camera_msgs "${colcon_flags[@]}"

# ------------------------------------------------------------------------------
# Compiling the 'realsense2_camera' package.
# ------------------------------------------------------------------------------
# Note on using ROS2 LifeCycle node:
# Reference: https://github.com/IntelRealSense/realsense-ros?tab=readme-ov-file#ros2-lifecyclenode
# The USE_LIFECYCLE_NODE cmake flag enables ROS2 Lifecycle Node (rclcpp_lifecycle::LifecycleNode) in the Realsense SDK,
# providing better node management and explicit state transitions.
# However, enabling this flag introduces a limitation where Image Transport functionality (image_transport) is disabled
# when USE_LIFECYCLE_NODE=ON.
# This means that compressed image topics (e.g., JPEG, PNG, Theora) will not be available and subscribers must use raw
# image topics, which may increase bandwidth usage.

#  Note: Users who do not depend on image_transport will not be affected by this change and can safely enable Lifecycle
#  Node without any impact on their workflow.

# Why This Limitation?

#At the time Lifecycle Node support was added, image_transport did not support rclcpp_lifecycle::LifecycleNode.
# ROS2 image_transport does not support Lifecycle Node.

# To build the SDK with Lifecycle Node enabled:
# colcon build --cmake-args -DUSE_LIFECYCLE_NODE=ON

# To use standard ROS2 node (default behavior) and retain image_transport functionality:
# colcon build --cmake-args -DUSE_LIFECYCLE_NODE=OFF

log "Compiling the 'realsense2_camera' package"
colcon build --packages-skip-build-finished --packages-select realsense2_camera "${colcon_flags[@]}" --cmake-args -DUSE_LIFECYCLE_NODE=OFF

# ------------------------------------------------------------------------------
# Compiling the 'ros2_launch_helpers' package
# ------------------------------------------------------------------------------

log "Compiling the 'ros2_launch_helpers' package"
colcon build --packages-skip-build-finished --packages-select ros2_launch_helpers "${colcon_flags[@]}"
