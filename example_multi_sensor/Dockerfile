# syntax=docker/dockerfile:1

ARG BASE_IMG=ubuntu:24.04
FROM ${BASE_IMG}

# The following labels adhere to the OCI Image Specification for standardized metadata.
# Reference: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="Multi-sensor Docker image" \
  org.opencontainers.image.description="A Docker image to run ROS2 sensor handlers" \
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

# Avoid installing recommended and suggested packages when using 'apt-get install'.
RUN tee /etc/apt/apt.conf.d/99norecommends.conf >/dev/null <<'EOF_NORECOMMENDS'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF_NORECOMMENDS

RUN <<'EOF_SETUP'
set -euo pipefail

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }
readonly sensor_images_repo_url="https://github.com/jfrascon/ros2_sensor_docker_images.git"

# Optionally set a branch or tag from the sensor repository.
# If left blank, the repository default branch is used.
readonly sensor_images_repo_ref=""

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

# Clone the sensors repository to mimic the workflow users will apply in their own projects:
# clone once, then reuse setup/compile/launch helper files from each sensor directory.
log "Installing prerequisites required to clone '${sensor_images_repo_url}'"
apt-get update
apt-get install --yes --no-install-recommends ca-certificates git
rm -rf /var/lib/apt/lists/*

sensor_images_dir="/tmp/sensor_images"
rm -rf "${sensor_images_dir}"

if [ -n "${sensor_images_repo_ref}" ]; then
  log "Cloning sensor repository '${sensor_images_repo_url}' (ref '${sensor_images_repo_ref}') into '${sensor_images_dir}'"
  git clone --depth 1 --branch "${sensor_images_repo_ref}" "${sensor_images_repo_url}" "${sensor_images_dir}"
else
  log "Cloning sensor repository '${sensor_images_repo_url}' (default branch) into '${sensor_images_dir}'"
  git clone --depth 1 "${sensor_images_repo_url}" "${sensor_images_dir}"
fi

base_dir="${sensor_images_dir}/base_docker_files"
umx_dir="${sensor_images_dir}/sensors/imus/umx"
livox_gen2_dir="${sensor_images_dir}/sensors/lidars/livox_gen2"
robosense_dir="${sensor_images_dir}/sensors/lidars/robosense"

required_files=(
  "${base_dir}/install_base_system.sh"
  "${base_dir}/install_ros.sh"
  "${base_dir}/rosdep_init_update_install.sh"
  "${base_dir}/colcon_mixin_metadata.sh"
  "${base_dir}/entrypoint.sh"
  "${umx_dir}/setup.sh"
  "${umx_dir}/compile.sh"
  "${umx_dir}/eut_sensor.launch.py"
  "${umx_dir}/examples/refs.txt"
  "${livox_gen2_dir}/setup.sh"
  "${livox_gen2_dir}/compile.sh"
  "${livox_gen2_dir}/eut_sensor.launch.py"
  "${livox_gen2_dir}/examples/refs.txt"
  "${robosense_dir}/setup.sh"
  "${robosense_dir}/compile.sh"
  "${robosense_dir}/eut_sensor.launch.py"
  "${robosense_dir}/examples/refs.txt"
)

for file in "${required_files[@]}"; do
  if [ ! -f "${file}" ]; then
    log "Error: Missing '${file}' in cloned repository '${sensor_images_dir}'" >&2
    exit 1
  fi
done

# ------------------------------------------------------------------------------
# Base system installation
# ------------------------------------------------------------------------------

# By using the command 'bash' explicitly it does not matter if the script has or not the execution permission.
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

# ------------------------------------------------------------------------------
# ROS installation
# ------------------------------------------------------------------------------

bash "${base_dir}/install_ros.sh" "${ROS_DISTRO}" "${ROS_VERSION}" || {
    log "Error: Failed to run 'install_ros.sh'" 1>&2
    exit 1
}

# Configure rosdep to avoid installing certain DDS packages which are not needed.
etc_rosdep_dir="/etc/ros/rosdep"
etc_rosdep_sources_dir="${etc_rosdep_dir}/sources.list.d"
mkdir --verbose --parent "${etc_rosdep_sources_dir}"

rosdep_ignored_keys_file="${etc_rosdep_dir}/rosdep_ignored_keys.yaml"

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

rosdep_ignored_keys_index_file="${etc_rosdep_sources_dir}/00-rosdep-ignored-keys.list"
line="yaml file://${rosdep_ignored_keys_file}"
echo "${line}" >>"${rosdep_ignored_keys_index_file}"
log "Added line '${line}' to file '${rosdep_ignored_keys_index_file}'"

# ------------------------------------------------------------------------------
# Sensor setup
# ------------------------------------------------------------------------------

log "Executing sensor setup scripts from cloned repository"

pkgs_dir="${IMAGE_MAIN_USER_WORKSPACE}/src"
mkdir --verbose --parent "${pkgs_dir}"

setup_steps=(
  "UMX IMU:${umx_dir}/setup.sh:${umx_dir}/examples/refs.txt"
  "Livox Gen2 LiDAR:${livox_gen2_dir}/setup.sh:${livox_gen2_dir}/examples/refs.txt"
  "RoboSense LiDAR:${robosense_dir}/setup.sh:${robosense_dir}/examples/refs.txt"
)

for step in "${setup_steps[@]}"; do
  IFS=':' read -r sensor_name setup_script refs_file <<< "${step}"
  log "Running setup for ${sensor_name}"
  bash "${setup_script}" "${pkgs_dir}" "${refs_file}" || {
      log "Error: Failed setup for ${sensor_name}" 1>&2
      exit 1
  }
done

# -------------------------------------------- End of sensor setup ----------------------------------------------

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

# Set ownership of the user's home directory and workspace.
log "Setting ownership of path '${image_main_user_home}' to user '${IMAGE_MAIN_USER}' (UID '${image_main_user_id}') and primary group '${image_main_user_pri_group}' (GID '${image_main_user_pri_group_id}')"
chown --recursive "${IMAGE_MAIN_USER}":"${image_main_user_pri_group}" "${image_main_user_home}"

log "Removing installation residues from apt cache"
apt-get autoclean
apt-get autoremove --purge -y
apt-get clean
rm -rf /var/lib/apt/lists/*  &>/dev/null
EOF_SETUP

USER "${IMAGE_MAIN_USER}"
WORKDIR "/home/${IMAGE_MAIN_USER}"

RUN <<'EOF_COMPILE'
set -euo pipefail

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

source /opt/ros/${ROS_DISTRO}/setup.bash || {
  log "Error: Failed to source ROS setup for '${ROS_DISTRO}'" >&2
  exit 1
}

sensor_images_dir="/tmp/sensor_images"
umx_dir="${sensor_images_dir}/sensors/imus/umx"
livox_gen2_dir="${sensor_images_dir}/sensors/lidars/livox_gen2"
robosense_dir="${sensor_images_dir}/sensors/lidars/robosense"
pkgs_dir="${IMAGE_MAIN_USER_WORKSPACE}/src"

compile_steps=(
  "UMX IMU:${umx_dir}/compile.sh"
  "Livox Gen2 LiDAR:${livox_gen2_dir}/compile.sh"
  "RoboSense LiDAR:${robosense_dir}/compile.sh"
)

log "Executing sensor compile scripts from cloned repository"
for step in "${compile_steps[@]}"; do
  IFS=':' read -r sensor_name compile_script <<< "${step}"
  log "Compiling ${sensor_name}"
  bash "${compile_script}" --symlink-install "${pkgs_dir}" || {
      log "Error: Failed compile for ${sensor_name}" >&2
      exit 1
  }
done
EOF_COMPILE

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
