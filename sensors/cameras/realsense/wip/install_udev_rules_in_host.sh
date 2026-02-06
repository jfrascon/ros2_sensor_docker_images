#!/usr/bin/env bash
# =============================================================================
# Udev rules must be installed on the host system, not inside containers.
#
# This script fetches and runs librealsense's official setup_udev_rules.sh and reloads udev rules so that RealSense
# devices get proper permissions and symlinks.
#
# udev runs on the HOST. Rules are evaluated when the kernel announces a device and the HOST's udevd creates/labels
# nodes under /dev.
# Containers inherit /dev from the host (bind-mount /dev/bus/usb and /dev/video* with proper cgroup permissions).
# Copying rules into a container is mostly cosmetic and does NOT replace installing them on the host where udev
# actually runs.
# For Docker runtime, grant device access (cgroup majors 81=V4L2, 189=USB) when launching the container. Device
# arbitration lives outside Docker.
#
# Always install RealSense udev rules on the HOST. Copying them into a container will not solve permissions nor
# hotplug if the host is not set.
#
# Requires: git, sudo, udevadm.
# =============================================================================

set -euo pipefail

script_name="$(basename "${BASH_SOURCE[0]}")"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%d_%H-%M-%S')" "$*"; }

# Detect likely container environment to avoid confusion
if [ -f "/.dockerenv" ] || [ -f "/run/.containerenv" ]; then
    log "ERROR: This must be run on the HOST, not inside a container." >&2
    exit 1
fi

# Check for required commands.
if ! command -v udevadm >/dev/null 2>&1; then
    log "ERROR: udevadm not found."
    exit 1
fi

TMP_DIR="$(mktemp --directory -t rs-udev-XXXXXX)"

# Remove temp dir on exit.
#trap 'cd "${script_dir}" && rm -rf "${TMP_DIR}"' EXIT

log "Cloning the librealsense repo (shallow) into the path ${TMP_DIR}"
git clone --depth=1 https://github.com/IntelRealSense/librealsense "${TMP_DIR}/librealsense"
cd "${TMP_DIR}/librealsense"
setup_udev_rules_script="scripts/setup_udev_rules.sh"

if [ ! -s "${setup_udev_rules_script}" ]; then
    log "ERROR: Script '${setup_udev_rules_script}' not found" >&2
    exit 1
fi

chmod +x "${setup_udev_rules_script}"

log "Installing RealSense udev rules into the host"

# Install dependencies for setup_udev_rules.sh
sudo apt-get install --yes v4l-utils || {
    log "ERROR: Package v4l-utils was not installed successfully."
    exit 1
}

bash "${setup_udev_rules_script}" || {
    log "ERROR: setup_udev_rules.sh failed."
    exit 1
}

sudo udevadm control --reload-rules || {
    log "ERROR: udevadm control failed."
    exit 1
}

sudo udevadm trigger || {
    log "ERROR: udevadm trigger failed."
    exit 1
}

log "Done. Replug your RealSense device(s) if needed."
