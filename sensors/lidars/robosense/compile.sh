#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

usage() {
    cat <<EOF
Usage:
  $(basename ${BASH_SOURCE[0]}) PKGS_DIR [--symlink-install --help]

Positional arguments:
  PKGS_DIR  Directory where the ROS packages are located

Options:
  --symlink-install    Build packages with symlink install
   --help              Show this help message and exit
EOF
}

# Normalize arguments with GNU getopt.
# -o ''     -> no short options
# -l ...    -> long options; ":" -> option requires a value
# --        -> end of getopt's own flags; after this, pass script args to parse
# "$@"      -> forward all original args verbatim (keeps spaces/quotes)
# getopt    -> normalizes: reorders options first, splits values, appends a final "--"
# on error  -> exits non-zero; we show usage and exit 2
PARSED=$(getopt \
    -o '' \
    -l symlink-install,help \
    -- "$@") || {
    usage
    exit 1
}

# Replace $@ with the normalized list; eval preserves quoting from getopt’s output.
eval set -- "$PARSED"

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

colcon_flags+=(
    --merge-install
    --mixin release
    --cmake-args
    -DCMAKE_CXX_FLAGS="-Wall -Wextra -Wpedantic -Wnon-virtual-dtor -Woverloaded-virtual -Wnull-dereference -Wunused-parameter"
    -Wno-dev
)

[ "$#" -lt 1 ] && {
    log "Error: missing required positionals: PKGS_DIR" >&2
    usage
    exit 1
}

PKGS_DIR="${1}"
shift

[ -z "${PKGS_DIR}" ] && {
    log "Error: PKGS_DIR is empty" >&2
    exit 1
}

[ ! -d "${PKGS_DIR}" ] && {
    log "Error: PKGS_DIR '${PKGS_DIR}' does not exist or is not a directory" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Compiling the 'rslidar_msg' package
# ------------------------------------------------------------------------------

cd "$(dirname "${PKGS_DIR}")" # Go to parent of PKGS_DIR
log "Compiling the 'rslidar_msg' package"
colcon build --packages-skip-build-finished --packages-select rslidar_msg "${colcon_flags[@]}"

# ------------------------------------------------------------------------------
# Compiling the 'rslidar_sdk' package
# ------------------------------------------------------------------------------

# Options present in the files 'rslidar_sdk/CMakeLists.txt' and 'rs_driver/CMakeLists.txt':
# -----------------------------------------------------------------------------------------
# ENABLE_DIFOP_PARSE: ON (rslidar_sdk) OFF (rs_driver)    # Enable parsing DFOP Packet
# ENABLE_EPOLL_RECEIVE: OFF                               # Receive packets with epoll() instead of select()
# ENABLE_MODIFY_RECVBUF: ON (rslidar_sdk) OFF (rs_driver) # Enable modify size of RECVBUF
# ENABLE_STAMP_WITH_LOCAL: OFF                            # Enable stamp point cloud with local time
# ENABLE_TRANSFORM: OFF                                   # Enable transform functions
# ENABLE_WAIT_IF_QUEUE_EMPTY: OFF                         # Enable waiting for a while in handle thread if the queue is
#                                                         # empty

# Options only present in the file 'rslidar_sdk/CMakeLists.txt':
# --------------------------------------------------------------
# ENABLE_IMU_DATA_PARSE: OFF        # Enable imu data parse
# ENABLE_SOURCE_PACKET_LEGACY: OFF  # Enable ROS Source of MSOP/DIFOP Packet v1.3.x

# Options only present in the file 'rs_driver/CMakeLists.txt':
# ------------------------------------------------------------
# COMPILE_DEMOS: OFF          # Build rs_driver demos
# COMPILE_TESTS: OFF          # Build rs_driver unit tests
# COMPILE_TOOL_PCDSAVER: OFF  # Build point cloud pcd saver tool
# COMPILE_TOOL_VIEWER: OFF    # Build point cloud visualization tool
# COMPILE_TOOLS: OFF          # Build rs_driver tools
# DISABLE_PCAP_PARSE: OFF     # Disable PCAP file parse
# ENABLE_CRC32_CHECK: OFF     # Enable CRC32 Check on MSOP Packet
# ENABLE_PCL_POINTCLOUD: OFF  # Enable PCL Point Cloud

# For the common options, we use the values defined in the file 'rslidar_sdk/CMakeLists.txt' as default values,
# since some of these common options have different default values in each file, and we consider the values defined in
# the file 'rslidar_sdk/CMakeLists.txt' the valid ones.

# The option ENABLE_TRANSFORM allows the transformation of the acquired point cloud to a different position with the
# built-in transform function.
# IT COSTS MUCH CPU RESOURCES. THIS FUNCTION IS ONLY FOR TEST PURPOSE. NEVER ENABLE THIS FUNCTION IN PRODUCTION.

# The option COMPILE_TOOL_PCDSAVER is disabled since we can save a pcd from a ROS topic using the pcl_ros package.

# The option COMPILE_TOOL_VIEWER is disabled because you can visualize the point cloud using RViz2.
# If you ever want to enable it, you have to install the dependencies 'libboost-dev' and 'libpcl-dev' in the setup.sh
# script.

# POINT_TYPE: XYZI (default) XYZIRT XYZIF XYZIRTF
# The ability to set the point type was added to Eurecat's fork of the rslidar_sdk repository.

colcon_flags_rslidar_sdk=("${colcon_flags[@]}")
colcon_flags_rslidar_sdk+=(
    --cmake-args
    -DPOINT_TYPE="XYZIRT"
    -DENABLE_DIFOP_PARSE=ON
    -DENABLE_EPOLL_RECEIVE=OFF
    -DENABLE_MODIFY_RECVBUF=ON
    -DENABLE_STAMP_WITH_LOCAL=OFF
    -DENABLE_TRANSFORM=OFF
    -DENABLE_WAIT_IF_QUEUE_EMPTY=OFF
    -DENABLE_SOURCE_PACKET_LEGACY=OFF
    -DENABLE_IMU_DATA_PARSE=ON
    -DCOMPILE_DEMOS=OFF
    -DCOMPILE_TESTS=OFF
    -DCOMPILE_TOOL_PCDSAVER=OFF
    -DCOMPILE_TOOL_VIEWER=OFF
    -DCOMPILE_TOOLS=OFF
    -DDISABLE_PCAP_PARSE=OFF
    -DENABLE_CRC32_CHECK=OFF
    -DENABLE_PCL_POINTCLOUD=OFF
)

log "Compiling the 'rslidar_sdk' package"
colcon build --packages-skip-build-finished --packages-select rslidar_sdk "${colcon_flags_rslidar_sdk[@]}"

# ------------------------------------------------------------------------------
# Compiling the 'ros2_launch_helpers' package
# ------------------------------------------------------------------------------

log "Compiling the 'ros2_launch_helpers' package"
colcon build --packages-skip-build-finished --packages-select ros2_launch_helpers "${colcon_flags[@]}"
