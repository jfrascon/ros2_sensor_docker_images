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
cd "${CLONE_DIR}"
bash "./scripts/setup_udev_rules.sh"
sudo udevadm control --reload-rules
sudo udevadm trigger
```

## Uninstall udev rules in the host OS to stop communicating with RealSense cameras

```bash
cd "${CLONE_DIR}"
bash "./scripts/setup_udev_rules.sh" --uninstall
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
    patch_script="./scripts/patch-realsense-ubuntu-L4T.sh"
    log "Patching kernel modules for Jetson L4T"
else
    patch_script="./scripts/patch-realsense-ubuntu-lts-hwe.sh"
    log "Patching kernel modules for Ubuntu LTS"
fi
cd "${CLONE_DIR}"
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
    --option BUILD_EXAMPLES=ON \
    --option BUILD_GRAPHICAL_EXAMPLES=ON \
    --option BUILD_TOOLS=ON \
    --option FORCE_RSUSB_BACKEND=OFF
```

- Las herramientas extras se describen en la URL:
[https://github.com/realsenseai/librealsense/tree/master/tools](https://github.com/realsenseai/librealsense/blob/master/tools/readme.md).
- Los ejemplos se describen en la URL:
[https://github.com/realsenseai/librealsense/tree/master/examples](https://github.com/realsenseai/librealsense/tree/master/examples/readme.md).

Si `BUILD_EXAMPLES=ON`, se construyen los binarios `rs-callback`, `rs-color`, `rs-depth`, `rs-distance`, `rs-embedded-filter`, `rs-eth-config`, `rs-infrared`, `rs-hello-realsense`, `rs-on-chip-calib` y `rs-save-to-disk`.
Si además `BUILD_GRAPHICAL_EXAMPLES=ON`, también se generan `realsense-viewer`, `rs-align`, `rs-align-gl`, `rs-align-advanced`, `rs-benchmark`, `rs-capture`, `rs-data-collect`, `rs-depth-quality`, `rs-gl`, `rs-hdr`, `rs-labeled-pointcloud`, `rs-measure`, `rs-motion`, `rs-multicam`, `rs-pointcloud`, `rs-post-processing`, `rs-record-playback`, `rs-rosbag-inspector`, `rs-sensor-control` y `rs-software-device`.
Si `BUILD_EXAMPLES=OFF`, no se construye ninguno de los binarios anteriores, ni los gráficos ni los no gráficos, aunque `BUILD_GRAPHICAL_EXAMPLES` esté a `ON`.
Si sólo quieres los ejemplos no gráficos, usa `BUILD_EXAMPLES=ON` y `BUILD_GRAPHICAL_EXAMPLES=OFF`.
Si quieres los ejemplos gráficos, usa `BUILD_EXAMPLES=ON` y `BUILD_GRAPHICAL_EXAMPLES=ON`, lo que implica que también tendrás los ejemplos no gráficos.

Si `BUILD_TOOLS=ON`, se construyen los binarios `rs-convert`, `rs-enumerate-devices`, `rs-fw-logger`, `rs-terminal`, `rs-record`, `rs-fw-update` y `rs-embed`.
Si además `BUILD_WITH_DDS=ON`, también se generan `rs-dds-adapter`, `rs-dds-config` y `rs-dds-sniffer`.
Si `BUILD_TOOLS=OFF`, no se construye ninguno de los binarios anteriores, ni los DDS ni los no-DDS, aunque `BUILD_WITH_DDS` esté a `ON`.
Si sólo quieres las herramientas base, usa `BUILD_TOOLS=ON` y `BUILD_WITH_DDS=OFF`.
Si quieres las herramientas DDS, usa `BUILD_TOOLS=ON` y `BUILD_WITH_DDS=ON`, lo que implica que también tendrás las herramientas base.

---

After finishing, clean up the temporary clone directory:

```bash
rm -rf "${CLONE_DIR}"
```
