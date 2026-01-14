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
# Compiling ROS2 packages
# ------------------------------------------------------------------------------

cd "$(dirname "${PKGS_DIR}")" # Go to parent of PKGS_DIR
log "Compiling the packages 'serial' and 'umx_driver'"
colcon build --packages-skip-build-finished --packages-select serial umx_driver "${colcon_flags[@]}"

# ------------------------------------------------------------------------------
# Compiling the 'ros2_launch_helpers' package
# ------------------------------------------------------------------------------

log "Compiling the 'ros2_launch_helpers' package"
colcon build --packages-skip-build-finished --packages-select ros2_launch_helpers "${colcon_flags[@]}"
