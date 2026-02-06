#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

usage() {
    cat <<EOF
Usage:
  ${script_name} PKGS_DIR [--ros-distro <distro> --options-file <file.json> --help]

Positional arguments:
  PKGS_DIR  Directory where the ROS packages are located

Options:
  --ros-distro              Target ROS2 distribution (e.g., humble, jazzy)
  --options-file file.json  YAML file with extra options for this script
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
    -l ros-distro:,options-file:,help \
    -- "$@") || {
    usage
    exit 1
}

# Replace $@ with the normalized list; eval preserves quoting from getopt’s output
eval set -- "$PARSED"

# After eval set -- ... we get:
# --ros-distro <distro> --options-file <file.json> -- PKGS_DIR
# -- is the end of options marker

ros_distro="" # ros_ditro might be used if needed and passed
options_file=""

while true; do
    case "${1:-}" in
    --ros-distro)
        ros_distro="${2}"
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
    log "Error: --pkgs-dir is required" >&2
    exit 1
}

[ ! -d "${PKGS_DIR}" ] && {
    log "Error: PKGS_DIR '${PKGS_DIR}' does not exist or is not a directory" >&2
    exit 1
}

# ----------------------------------------------------------------------------------------------------------------------
# Compiling the 'realsense-ros' package.
# ----------------------------------------------------------------------------------------------------------------------

cd "$(dirname "${PKGS_DIR}")" # Go to parent of PKGS_DIR
cxx_flags="-Wall -Wextra -Wpedantic -Wnon-virtual-dtor -Woverloaded-virtual -Wnull-dereference -Wunused-parameter"

# If packages must be removed, then we don't use --symlink-install, we copy the packages to the install space,
# and then we delete the source code after a successful build.
symlink_install_flag=()

# Condition: succeeds only if .realsense.keep_src_code is explicitly true.
# - '.realsense?.keep_src_code?' -> optional traversal; missing keys yield null (no error).
# - 'X // Y'                -> default operator; if X is null, use Y.
if [ -n "${options_file}" ] && [ -s "${options_file}" ] && jq -e '.realsense?.keep_src_code? // false' "${options_file}" >/dev/null; then
    symlink_install_flag=(--symlink-install)
    verb="Keeping"
else
    verb="Removing"
fi

log "${verb} the directory '${PKGS_DIR}/realsense-ros after build"
log "Compiling the 'realsense2_camera_msgs' package"

colcon build --packages-skip-build-finished --packages-select realsense2_camera_msgs \
    "${symlink_install_flag[@]}" \
    --merge-install \
    --mixin release \
    --cmake-args -DCMAKE_CXX_FLAGS="${cxx_flags}"

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

colcon build --packages-skip-build-finished --packages-select realsense2_camera \
    "${symlink_install_flag[@]}" \
    --merge-install \
    --mixin release \
    --cmake-args -DCMAKE_CXX_FLAGS="${cxx_flags}" -DUSE_LIFECYCLE_NODE=OFF

[ -z "${symlink_install_flag[*]}" ] && {
    log "Removing source directory '${PKGS_DIR}/realsense-ros"
    rm -rf "${PKGS_DIR}/realsense-ros"
}
