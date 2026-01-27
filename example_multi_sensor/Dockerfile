# syntax=docker/dockerfile:1

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

# The following labels adhere to the OCI Image Specification for standardized metadata.
# Reference: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="Multi-sensor example image" \
  org.opencontainers.image.description="Example Docker image to run ROS2 drivers for UMX IMU, Livox Gen2 LiDAR, and Robosense LiDAR" \
  org.opencontainers.image.authors="anon"

ARG ROS_DISTRO=jazzy
ARG ROS_VERSION=2

ENV IMAGE_MAIN_USER="sensor" \
  IMAGE_MAIN_USER_WORKSPACE="/home/sensor/workspace" \
  ROS_DISTRO="${ROS_DISTRO}" \
  ROS_VERSION="${ROS_VERSION}" \
  DEBIAN_FRONTEND="noninteractive"

USER root
WORKDIR /root

SHELL ["/bin/bash", "-c"]

# Avoid installing recommended and suggested packages.
RUN tee /etc/apt/apt.conf.d/99norecommends.conf >/dev/null <<'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

# Minimal tooling to allow cloning the sensors repository.
RUN --mount=type=bind,source=.,target=/tmp/context <<'EOF'
set -euo pipefail
apt-get update
apt-get install --yes --no-install-recommends ca-certificates git
rm -rf /var/lib/apt/lists/*

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

repo_url="https://github.com/jfrascon/ros2_sensor_docker_images"
log "Cloning sensors repository '${repo_url}' into /tmp/sensor_images"
rm -rf /tmp/sensor_images
git clone "${repo_url}" /tmp/sensor_images

# Checks.
[ -z "${ROS_DISTRO}" ] && {
  log "Error: ROS_DISTRO not set" >&2
  exit 1
}

[ "${ROS_DISTRO}" != "humble" ] && [ "${ROS_DISTRO}" != "jazzy" ] && {
  log "Error: Unsupported ROS_DISTRO '${ROS_DISTRO}'. Only 'humble' and 'jazzy' are supported." >&2
  exit 1
}

[ -z "${ROS_VERSION}" ] && {
  log "Error: ROS_VERSION not set" >&2
  exit 1
}

[ "${ROS_VERSION}" -lt 2 ] && {
  log "Error: ROS_VERSION must be > 1" >&2
  exit 1
}

base_dir="/tmp/sensor_images/base_docker_files"

[ ! -s "${base_dir}/install_base_system.sh" ] && {
  log "Error: Missing 'install_base_system.sh' in ${base_dir}" >&2
  exit 1
}

[ ! -s "${base_dir}/install_ros.sh" ] && {
  log "Error: Missing 'install_ros.sh' in ${base_dir}" >&2
  exit 1
}

[ ! -s "${base_dir}/rosdep_init_update_install.sh" ] && {
  log "Error: Missing 'rosdep_init_update_install.sh' in ${base_dir}" >&2
  exit 1
}

[ ! -s "${base_dir}/colcon_mixin_metadata.sh" ] && {
  log "Error: Missing 'colcon_mixin_metadata.sh' in ${base_dir}" >&2
  exit 1
}

[ ! -s "${base_dir}/entrypoint.sh" ] && {
  log "Error: Missing 'entrypoint.sh' in ${base_dir}" >&2
  exit 1
}

# --------------------------------------------------------------------------------------
# BASE SYSTEM installation
# --------------------------------------------------------------------------------------

# By using bash it does not matter if the script has or not the execution permission.
bash "${base_dir}/install_base_system.sh" "${IMAGE_MAIN_USER}" || {
    log "Error: Failed to run 'install_base_system.sh'" 1>&2
    exit 1
}

image_main_user_entry="$(getent passwd "${IMAGE_MAIN_USER}")"
image_main_user_id="$(echo "${image_main_user_entry}" | cut -d: -f3)"
image_main_user_pri_group_id="$(echo "${image_main_user_entry}" | cut -d: -f4)"
image_main_user_pri_group="$(getent group "${image_main_user_pri_group_id}" | cut -d: -f1)"
image_main_user_home="$(echo "${image_main_user_entry}" | cut -d: -f6)"

if [ "${image_main_user_home}" != "/home/${IMAGE_MAIN_USER}" ]; then
  log "Error: Home directory for user '${IMAGE_MAIN_USER}' is set to '${image_main_user_home}' instead of '/home/${IMAGE_MAIN_USER}'" 1>&2
  exit 1
fi

# --------------------------------------------------------------------------------------
# ROS installation
# --------------------------------------------------------------------------------------

bash "${base_dir}/install_ros.sh" "${ROS_DISTRO}" "${ROS_VERSION}" || {
    log "Error: Failed to run 'install_ros.sh'" 1>&2
    exit 1
}

etc_rosdep_dir="/etc/ros/rosdep"
etc_rosdep_sources_dir="${etc_rosdep_dir}/sources.list.d"
mkdir --verbose --parent "${etc_rosdep_sources_dir}"

# File where rosdep keys to skip are saved.
rosdep_ignored_keys_file="${etc_rosdep_dir}/rosdep_ignored_keys.yaml"

# Initial rosdep keys to skip.
rosdep_ignored_keys=(
"rmw_connextdds: {ubuntu: []}"
"rmw_connextdds_common: {ubuntu: []}"
"rti-connext-dds-cmake-module: {ubuntu: []}"
"rmw_gurumdds_cpp: {ubuntu: []}"
"gurumdds_cmake_module: {ubuntu: []}"
)

for key in "${rosdep_ignored_keys[@]}"; do
    printf '%s\n' "${key}" >>"${rosdep_ignored_keys_file}"
    log "Added rosdep key to ignore, '${key}', to file '${rosdep_ignored_keys_file}'"
done

# Index file listing the files with rosdep keys to skip, and read by rosdep.
# In this case we have opted to save all the keys to skip in a single file, '${rosdep_ignored_keys_file}'.
# Therefore, a line 'yaml file://${rosdep_ignored_keys_file}' must be added, if not already present, to the index file.
# Note, it does not matter if the file "${rosdep_ignored_keys_file}" does not exist when executing 'rosdep install ...'
rosdep_ignored_keys_index_file="${etc_rosdep_sources_dir}/00-rosdep-ignored-keys.list"
line="yaml file://${rosdep_ignored_keys_file}"
echo "${line}" >>"${rosdep_ignored_keys_index_file}"
log "Added line '${line}' to file '${rosdep_ignored_keys_index_file}'"

# --------------------------------------------------------------------------------------
# Sensor installation
# --------------------------------------------------------------------------------------

log "Executing install scripts for multi-sensor image"

# Path to the directory where the repositories will be cloned.
pkgs_dir="${IMAGE_MAIN_USER_WORKSPACE}/src"
mkdir --verbose --parent "${pkgs_dir}"

repo_dir="/tmp/sensor_images"
umx_dir="${repo_dir}/sensors/imus/umx"
livox_gen2_dir="${repo_dir}/sensors/lidars/livox_gen2"
robosense_dir="${repo_dir}/sensors/lidars/robosense"

sensors=(
  "UMX IMU:${umx_dir}"
  "Livox Gen2 LiDAR:${livox_gen2_dir}"
  "Robosense LiDAR:${robosense_dir}"
)

for sensor in "${sensors[@]}"; do
  sensor_name="${sensor%%:*}"
  sensor_dir="${sensor#*:}"

  [ ! -s "${sensor_dir}/install.sh" ] && {
    log "Error: Missing 'install.sh' in ${sensor_dir}" >&2
    exit 1
  }

  log "Installing ${sensor_name} driver"
  bash "${sensor_dir}/install.sh" "${pkgs_dir}"
done

# -------------------------------------------- End of sensor installation ----------------------------------------------

rosdep_args=("${ROS_DISTRO}" "${IMAGE_MAIN_USER}" --pkgs-dir "${pkgs_dir}")
bash "${base_dir}/rosdep_init_update_install.sh" "${rosdep_args[@]}" || {
    log "Error: Failed to run 'rosdep_init_update_install.sh'" 1>&2
    exit 1
}

bash "${base_dir}/colcon_mixin_metadata.sh" "${IMAGE_MAIN_USER}" || {
  log "Error: Failed to run 'colcon_mixin_metadata.sh'" 1>&2
  exit 1
}

log "Installing entrypoint script to /usr/local/bin/entrypoint.sh"
install -D -m 0755 "${base_dir}/entrypoint.sh" /usr/local/bin/entrypoint.sh

# Set ownership of the user´s home directory and workspace.
log "Setting ownership of path '${image_main_user_home}' to user '${IMAGE_MAIN_USER}' (UID '${image_main_user_id}') and primary group '${image_main_user_pri_group}' (GID '${image_main_user_pri_group_id}')"
chown --recursive "${IMAGE_MAIN_USER}":"${image_main_user_pri_group}" "${image_main_user_home}"

log "Removing installation residues from apt cache"
apt-get autoclean
apt-get autoremove --purge -y
apt-get clean
rm -rf /var/lib/apt/lists/*  &>/dev/null
EOF

USER "${IMAGE_MAIN_USER}"
WORKDIR "/home/${IMAGE_MAIN_USER}"

RUN --mount=type=bind,source=.,target=/tmp/context <<'EOF'

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

source /opt/ros/${ROS_DISTRO}/setup.bash || {
  log "Error: Failed to source ROS setup for '${ROS_DISTRO}'" >&2
  exit 1
}

pkgs_dir="${IMAGE_MAIN_USER_WORKSPACE}/src"

log "Compiling packages for multi-sensor image"

repo_dir="/tmp/sensor_images"
umx_dir="${repo_dir}/sensors/imus/umx"
livox_gen2_dir="${repo_dir}/sensors/lidars/livox_gen2"
robosense_dir="${repo_dir}/sensors/lidars/robosense"

compile_sensors=(
  "UMX IMU:${umx_dir}"
  "Livox Gen2 LiDAR:${livox_gen2_dir}"
  "Robosense LiDAR:${robosense_dir}"
)

for sensor in "${compile_sensors[@]}"; do
  sensor_name="${sensor%%:*}"
  sensor_dir="${sensor#*:}"

  [ ! -s "${sensor_dir}/compile.sh" ] && {
    log "Error: Missing 'compile.sh' in ${sensor_dir}" >&2
    exit 1
  }

  log "Compiling ${sensor_name} packages"
  bash "${sensor_dir}/compile.sh" --symlink-install "${pkgs_dir}" || {
    log "Error: Failed to compile ${sensor_name}" >&2
    exit 1
  }
done
EOF

# Configure timezone and localization settings.
# - TZ: Set the timezone to UTC to ensure consistent time handling across environments.
# - LC_ALL, LANG, LANGUAGE: Configure localization to US English and UTF-8 encoding, which helps
#   avoiding issues with character encoding and ensures compatibility with most tools and libraries.
ENV TZ="Etc/UTC" \
  LC_ALL="en_US.UTF-8" \
  LANG="en_US.UTF-8" \
  LANGUAGE="en_US:en" \
  ROS_HOME="/home/${IMAGE_MAIN_USER}/.ros" \
  ROS_LOG_DIR="/home/${IMAGE_MAIN_USER}/.ros/log" \
  ROS_TEST_RESULTS_DIR="/home/${IMAGE_MAIN_USER}/.ros/tests" \
  ROS_CONFIG_HOME="/home/${IMAGE_MAIN_USER}/.config/ros.org"
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
