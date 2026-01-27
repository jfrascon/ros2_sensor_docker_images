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
# Setting up 'serial-ros2' package.
# ----------------------------------------------------------------------------------------------------------------------

remote_serial_repo="https://github.com/RoverRobotics-forks/serial-ros2.git"
local_serial_repo="${PKGS_DIR}/serial-ros2"

[ -d "${local_serial_repo}" ] && rm -rf "${local_serial_repo}"

log "Cloning the repository '${remote_serial_repo}' into the path '${local_serial_repo}'"
# --branch <branch> --single-branch: just clone that branch.
git clone --branch master --single-branch "${remote_serial_repo}" "${local_serial_repo}"

# Free space.
rm -rf "${local_serial_repo}/.git"

# ------------------------------------------------------------------------------
# Setting up 'um7' package.
# ------------------------------------------------------------------------------

remote_um7_repo="https://github.com/ros-drivers/um7.git"
local_um7_repo="${PKGS_DIR}/um7" # For um6 and um7 imus.

[ -d "${local_um7_repo}" ] && rm -rf "${local_um7_repo}"

log "Cloning the repository '${remote_um7_repo}' into the path '${local_um7_repo}'"
# --branch <branch> --single-branch: just clone that branch.
git clone --branch ros2 --single-branch "${remote_um7_repo}" "${local_um7_repo}"

# Free space.
rm -rf "${local_um7_repo}/.git"

# ------------------------------------------------------------------------------
# A bit of a hack to place the launch file in the right place.
# ------------------------------------------------------------------------------

# The package 'umx_driver' does not have a folder called 'launch' or similar with launch files.
# The repository 'https://github.com/ros-drivers/um7/tree/ros2' states that in order to run the node, you must use:
#
# Run the Driver
#
# For UM7:
# source install/setup.bash
# ros2 run umx_driver um7_driver --ros-args -p port:=/dev/ttyUSB0
#
# For UM6:
#
# source install/setup.bash
# ros2 run umx_driver um6_driver --ros-args -p port:=/dev/ttyUSB0

# We want to use the launch file 'eut_sensor.launch.py' to launch the node, as we do with other sensors.
# To overcome that situation we have a strategy where:
# We keep 2 files under extras/:
# cmakelists_original="${script_dir}/extras/CMakeLists_original.txt"
# cmakelists_modified="${script_dir}/extras/CMakeLists_modified.txt"
# cmakelists_downloaded="${local_um7_repo}/CMakeLists.txt"
#
# Goal:
# We only replace the downloaded CMakeLists.txt file with our modified version if (and only if) the downloaded
# CMakeLists.txt file is byte-for-byte identical to the original CMakeLists.txt file.
#
# Why:
# If the CmakeLists.txt file in the repository changes, we do not want to blindly overwrite it with our modified version
# and require a manual review of the changes and possible regeneration of the modified version.

cmakelists_downloaded="${local_um7_repo}/CMakeLists.txt"
cmakelists_dir="${script_dir}/extras"
cmakelists_original="${cmakelists_dir}/CMakeLists_original.txt"
cmakelists_modified="${cmakelists_dir}/CMakeLists_modified.txt"

[ ! -s "${cmakelists_original}" ] && {
    log "Error: Missing file '${cmakelists_original}'" >&2
    exit 1
}

[ ! -s "${cmakelists_modified}" ] && {
    log "Error: Missing file '${cmakelists_modified}'" >&2
    exit 1
}

log "Substituting the CMakeLists.txt file in the repository '${remote_um7_repo}' with our modified version"

if cmp -s "${cmakelists_downloaded}" "${cmakelists_original}"; then
    # This is an atomic replace via temporary file and mv.
    # # Use tmp + mv (rename) on the same filesystem for atomic replace: readers see either the old or the new file,
    # never a half-written one.
    # A direct 'cp -f' can leave a partially written destination if the process dies mid-write (signal, I/O error,
    # disk full).
    tmp="$(mktemp "${cmakelists_downloaded}.XXXXXX")"
    cp -f -- "${cmakelists_modified}" "${tmp}"
    mv -f -- "${tmp}" "${cmakelists_downloaded}"
    echo "Swap done."
else
    echo "CMakeLists.txt file in repository '${remote_um7_repo}' differs from our copy of the CMakeLists.txt file" >&2
    echo "Refusing to overwrite it. Please review the changes manually." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# Installing launch file eut_sensor.launch.py
# ------------------------------------------------------------------------------

log "Creating folder '${local_um7_repo}/launch'"
mkdir -pv ${local_um7_repo}/launch

[ ! -s "${script_dir}/eut_sensor.launch.py" ] && {
    log "Error: Missing file '${script_dir}/eut_sensor.launch.py'" >&2
    exit 1
}

log "Placing the file 'eut_sensor.launch.py' into '${local_um7_repo}/launch/eut_sensor.launch.py'"
install -m 0755 "${script_dir}/eut_sensor.launch.py" "${local_um7_repo}/launch/eut_sensor.launch.py"

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
