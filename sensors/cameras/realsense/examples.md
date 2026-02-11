# Code examples

This file provides example commands to configure the host operating system (**OS**) for RealSense cameras.

In the examples below, `REMOTE_REF` defines which branch or tag of the `librealsense2` repository will be used.

These examples are pinned to [v2.56.5](https://github.com/realsenseai/librealsense/tree/v2.56.5).
Update `REMOTE_REF` as needed for your target branch or tag.

## Common setup for all examples

```bash
log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%d_%H-%M-%S')" "$*"; }

LIBREALSENSE_REPO="https://github.com/realsenseai/librealsense.git"
REMOTE_REF="v2.56.5"
CLONE_DIR="$(mktemp -d /tmp/librealsense2_XXXXXX)"

sudo apt-get update
sudo apt-get install -y --no-install-recommends ca-certificates \
  curl \
  git \
  libssl-dev \
  libusb-1.0-0-dev \
  libudev-dev \
  pkg-config \
  udev \
  v4l-utils

git clone --branch "${REMOTE_REF}" --depth 1 "${LIBREALSENSE_REPO}" "${CLONE_DIR}"
```

## Install udev rules in the host OS to communicate with RealSense cameras

```bash
bash "${CLONE_DIR}/scripts/setup_udev_rules.sh"
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Uninstall udev rules in the host OS to stop communicating with RealSense cameras

```bash
bash "${CLONE_DIR}/scripts/setup_udev_rules.sh" --uninstall
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Patch kernel modules in the host OS for improved RealSense support

```bash
# To patch the kernel of a Jetson device, set USE_L4T to 1. For other devices, set it to 0.
USE_L4T=0

# Ensure this script runs only on an Ubuntu LTS host.
if [ ! -r /etc/os-release ]; then
    log "ERROR: /etc/os-release not found" >&2
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    log "ERROR: Unsupported OS '${ID:-unknown}'. Ubuntu LTS is required" >&2
    exit 1
fi

if [[ "${VERSION:-}" != *"LTS"* ]]; then
    log "ERROR: Ubuntu non-LTS detected (${PRETTY_NAME:-unknown}). Ubuntu LTS is required" >&2
    exit 1
fi

log "Detected host OS: ${PRETTY_NAME:-Ubuntu LTS} (${VERSION_CODENAME:-${UBUNTU_CODENAME:-unknown}}), kernel: $(uname -r)"

if [ "${USE_L4T}" -eq 1 ]; then
    patch_script="${CLONE_DIR}/scripts/patch-realsense-ubuntu-L4T.sh"
    log "Patching kernel modules for Jetson L4T"
else
    patch_script="${CLONE_DIR}/scripts/patch-realsense-ubuntu-lts-hwe.sh"
    log "Patching kernel modules for Ubuntu LTS"
fi

bash "${patch_script}"
log "Restart the system and run: sudo dmesg | tail -n 50 (look for a new uvcvideo driver registration)"
```

## Install librealsense2 library in the host OS

Installing `librealsense2` on the host OS is optional.
Install it if you need host-side tools such as `realsense-viewer`, `depth-quality`, `rs-enumerate-devices`, or `fw-update`.

If kernel modules are already patched on the host OS, the recommended build uses the native backend
(`FORCE_RSUSB_BACKEND=OFF`, without `libuvc`).
You can still build with `FORCE_RSUSB_BACKEND=ON` if needed, but performance is usually lower and some limitations apply.
See [README](./README.md) for details.

The instructions below are only for host-side installation.
If you only need `librealsense2` inside the Docker image, use `setup.sh` during image build.

```bash
# See available build flags in:
# ${CLONE_DIR}/CMake/lrs_options.cmake

# Run this command from the directory where install_librealsense2_from_source.sh is located.
# Each `--option` value must be `ON`, `OFF`, `TRUE`, or `FALSE`.
bash install_librealsense2_from_source.sh \
    --source-dir "${CLONE_DIR}" \
    --option BUILD_WITH_CUDA=OFF \
    --option BUILD_EXAMPLES=OFF \
    --option BUILD_GRAPHICAL_EXAMPLES=ON \
    --option BUILD_TOOLS=ON \
    --option FORCE_RSUSB_BACKEND=OFF
```

---

After finishing, clean up the temporary clone directory:

```bash
rm -rf "${CLONE_DIR}"
```
