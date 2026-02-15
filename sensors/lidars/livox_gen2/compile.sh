#!/usr/bin/env bash
set -euo pipefail

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%d_%H-%M-%S')" "$*"; }

usage() {
    cat <<EOF_USAGE
Usage:
  $(basename "${BASH_SOURCE[0]}") PKGS_DIR [--symlink-install] [--help|-h]

Positional arguments:
  PKGS_DIR  Directory where the ROS packages are located

Options:
  --symlink-install    Build packages with symlink install
  -h, --help           Show this help message and exit
EOF_USAGE
}

SHORT_OPTS="h"
LONG_OPTS="help,symlink-install"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

eval set -- "${PARSED_ARGS}"

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
# Compiling ROS2 packages
# ------------------------------------------------------------------------------

cd "$(dirname "${PKGS_DIR}")"
log "Compiling the package 'livox_ros_driver2'"
colcon build --packages-skip-build-finished --packages-select livox_ros_driver2 "${colcon_flags[@]}"

# ------------------------------------------------------------------------------
# Compiling the 'ros2_launch_helpers' package
# ------------------------------------------------------------------------------

log "Compiling the 'ros2_launch_helpers' package"
colcon build --packages-skip-build-finished --packages-select ros2_launch_helpers "${colcon_flags[@]}"
