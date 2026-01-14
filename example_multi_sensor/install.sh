#!/usr/bin/env bash
set -euo pipefail

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

usage() {
    cat <<EOF_INNER
Usage:
  $(basename ${BASH_SOURCE[0]}) PKGS_DIR

Positional arguments:
  PKGS_DIR  Directory where the ROS packages are located
EOF_INNER
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

# Make sure the "${PKGS_DIR}" directory exists.
mkdir --parent --verbose "${PKGS_DIR}"
cd "${PKGS_DIR}" # Set current directory

repo_dir="/tmp/sensor_images"

umx_dir="${repo_dir}/sensors/imus/umx"
livox_gen2_dir="${repo_dir}/sensors/lidars/livox_gen2"
robosense_dir="${repo_dir}/sensors/lidars/robosense"

[ ! -s "${umx_dir}/install.sh" ] && {
    log "Error: Missing file '${umx_dir}/install.sh'" >&2
    exit 1
}

[ ! -s "${livox_gen2_dir}/install.sh" ] && {
    log "Error: Missing file '${livox_gen2_dir}/install.sh'" >&2
    exit 1
}

[ ! -s "${robosense_dir}/install.sh" ] && {
    log "Error: Missing file '${robosense_dir}/install.sh'" >&2
    exit 1
}

# The umx install script expects CMakeLists files next to it.
# In the repo they live under 'extras/', so we copy them locally.
[ ! -s "${umx_dir}/extras/CMakeLists_original.txt" ] && {
    log "Error: Missing file '${umx_dir}/extras/CMakeLists_original.txt'" >&2
    exit 1
}

[ ! -s "${umx_dir}/extras/CMakeLists_modified.txt" ] && {
    log "Error: Missing file '${umx_dir}/extras/CMakeLists_modified.txt'" >&2
    exit 1
}

cp -f "${umx_dir}/extras/CMakeLists_original.txt" "${umx_dir}/CMakeLists_original.txt"
cp -f "${umx_dir}/extras/CMakeLists_modified.txt" "${umx_dir}/CMakeLists_modified.txt"

# ----------------------------------------------------------------------------------------------------------------------
# Installing UM7/UMX IMU driver
# ----------------------------------------------------------------------------------------------------------------------

log "Installing UM7/UMX IMU driver"
bash "${umx_dir}/install.sh" "${PKGS_DIR}"

# ----------------------------------------------------------------------------------------------------------------------
# Installing Livox Gen2 LiDAR driver
# ----------------------------------------------------------------------------------------------------------------------

log "Installing Livox Gen2 LiDAR driver"
bash "${livox_gen2_dir}/install.sh" "${PKGS_DIR}"

# ----------------------------------------------------------------------------------------------------------------------
# Installing Robosense LiDAR driver
# ----------------------------------------------------------------------------------------------------------------------

log "Installing Robosense LiDAR driver"
bash "${robosense_dir}/install.sh" "${PKGS_DIR}"
