#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

usage() {
    cat <<EOF_INNER
Usage:
  $(basename ${BASH_SOURCE[0]}) PKGS_DIR [--symlink-install --help]

Positional arguments:
  PKGS_DIR  Directory where the ROS packages are located

Options:
  --symlink-install    Build packages with symlink install
   --help              Show this help message and exit
EOF_INNER
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

symlink_install_flag=()

while true; do
    case "${1:-}" in
    --symlink-install)
        symlink_install_flag=(--symlink-install)
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

repo_dir="/tmp/sensor_images"

umx_dir="${repo_dir}/sensors/imus/umx"
livox_gen2_dir="${repo_dir}/sensors/lidars/livox_gen2"
robosense_dir="${repo_dir}/sensors/lidars/robosense"

[ ! -s "${umx_dir}/compile.sh" ] && {
    log "Error: Missing file '${umx_dir}/compile.sh'" >&2
    exit 1
}

[ ! -s "${livox_gen2_dir}/compile.sh" ] && {
    log "Error: Missing file '${livox_gen2_dir}/compile.sh'" >&2
    exit 1
}

[ ! -s "${robosense_dir}/compile.sh" ] && {
    log "Error: Missing file '${robosense_dir}/compile.sh'" >&2
    exit 1
}

log "Compiling UM7/UMX IMU packages"
bash "${umx_dir}/compile.sh" "${symlink_install_flag[@]}" "${PKGS_DIR}"

log "Compiling Livox Gen2 LiDAR packages"
bash "${livox_gen2_dir}/compile.sh" "${symlink_install_flag[@]}" "${PKGS_DIR}"

log "Compiling Robosense LiDAR packages"
bash "${robosense_dir}/compile.sh" "${symlink_install_flag[@]}" "${PKGS_DIR}"
