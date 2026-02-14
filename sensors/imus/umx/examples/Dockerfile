# syntax=docker/dockerfile:1

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION}

# The following labels adhere to the OCI Image Specification for standardized metadata.
# Reference: https://github.com/opencontainers/image-spec/blob/main/annotations.md
LABEL org.opencontainers.image.title="UMX IMU Docker image" \
  org.opencontainers.image.description="A Docker image to run the ROS2 driver for UMX IMUs" \
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
RUN tee /etc/apt/apt.conf.d/99norecommends.conf >/dev/null <<'EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

RUN --mount=type=bind,source=.,target=/tmp/context <<'EOF'
set -euo pipefail

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

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

# Check that all the required files are present in the build context.
required_context_files=(
  install_base_system.sh
  install_ros.sh
  rosdep_init_update_install.sh
  colcon_mixin_metadata.sh
  entrypoint.sh
  refs.txt
  setup.sh
  compile.sh
  eut_sensor.launch.py
)

for file in "${required_context_files[@]}"; do
  if [ ! -f "/tmp/context/${file}" ]; then
    log "Error: Missing '${file}' in the build context" >&2
    exit 1
  fi
done

# ------------------------------------------------------------------------------
# Base system installation
# ------------------------------------------------------------------------------

# By using the command 'bash' explicitly it does not matter if the script has or not the execution permission.
bash /tmp/context/install_base_system.sh "${IMAGE_MAIN_USER}" || {
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

bash /tmp/context/install_ros.sh "${ROS_DISTRO}" "${ROS_VERSION}" || {
    log "Error: Failed to run 'install_ros.sh'" 1>&2
    exit 1
}

# Configure rosdep to avoid installing certain DDS packages which are not needed.
etc_rosdep_dir="/etc/ros/rosdep"
etc_rosdep_sources_dir="${etc_rosdep_dir}/sources.list.d"
mkdir --verbose --parent "${etc_rosdep_sources_dir}"

# The approach followed is to saved all the rosdep keys to skip in a single file, '${rosdep_ignored_keys_file}', and
# then add a line to the rosdep sources index file, '${rosdep_ignored_keys_index_file}', pointing to
# '${rosdep_ignored_keys_file}'.
rosdep_ignored_keys_file="${etc_rosdep_dir}/rosdep_ignored_keys.yaml"

# Initial rosdep keys to skip.
rosdep_ignored_keys=(
"rmw_connextdds: {ubuntu: []}"
"rmw_connextdds_common: {ubuntu: []}"
"rti-connext-dds-cmake-module: {ubuntu: []}"
"rmw_gurumdds_cpp: {ubuntu: []}"
"gurumdds_cmake_module: {ubuntu: []}"
)

# Write the rosdep keys to skip to the file specified by '${rosdep_ignored_keys_file}'.
for key in "${rosdep_ignored_keys[@]}"; do
    printf '%s\n' "${key}" >>"${rosdep_ignored_keys_file}"
    log "Added rosdep key to ignore, '${key}', to file '${rosdep_ignored_keys_file}'"
done

# '${rosdep_ignored_keys_index_file}' is the index file listing the files with rosdep keys to skip, and read by rosdep.
# Therefore, a line 'yaml file://${rosdep_ignored_keys_file}' must be added, if not already present, to the index file.
# Note, it does not matter if the file "${rosdep_ignored_keys_file}" is pointed in the index file but does not exist
# when executing 'rosdep install ...', since rosdep will just ignore it
rosdep_ignored_keys_index_file="${etc_rosdep_sources_dir}/00-rosdep-ignored-keys.list"
line="yaml file://${rosdep_ignored_keys_file}"
echo "${line}" >>"${rosdep_ignored_keys_index_file}"
log "Added line '${line}' to file '${rosdep_ignored_keys_index_file}'"


# --------------------------------------------------------------------------------------
# Sensor installation
# --------------------------------------------------------------------------------------

log "Executing script 'setup.sh'"

# Path to the directory where the repositories will be cloned.
pkgs_dir="${IMAGE_MAIN_USER_WORKSPACE}/src"
mkdir --verbose --parent "${pkgs_dir}"

bash /tmp/context/setup.sh "${pkgs_dir}" "/tmp/context/refs.txt" || {
    log "Error: Failed to run 'setup.sh'" 1>&2
    exit 1
}

# -------------------------------------------- End of sensor installation ----------------------------------------------

rosdep_args=("${ROS_DISTRO}" "${IMAGE_MAIN_USER}" --pkgs-dir "${pkgs_dir}")
bash /tmp/context/rosdep_init_update_install.sh "${rosdep_args[@]}" || {
    log "Error: Failed to run 'rosdep_init_update_install.sh'" 1>&2
    exit 1
}

bash /tmp/context/colcon_mixin_metadata.sh "${IMAGE_MAIN_USER}" || {
  log "Error: Failed to run 'colcon_mixin_metadata.sh'" 1>&2
  exit 1
}

log "Installing entrypoint script to /usr/local/bin/entrypoint.sh"
install -D -m 0755 /tmp/context/entrypoint.sh /usr/local/bin/entrypoint.sh

# Set ownership of the user´s home directory and workspace.
log "Setting ownership of path '${image_main_user_home}' to user '${IMAGE_MAIN_USER}' (UID '${image_main_user_id}') and primary group '${image_main_user_pri_group}' (GID '${image_main_user_pri_group_id}')"
chown --recursive "${IMAGE_MAIN_USER}":"${image_main_user_pri_group}" "${image_main_user_home}"

# Debugging info; uncomment if needed.
# echo '#########################################################################################################'
# ls -la "${image_main_user_home}"
# echo '---------------------------------------------------------------------------------------------------------'
# ls -la "${image_main_user_ros_home}"
# echo '---------------------------------------------------------------------------------------------------------'
# ls -la "${image_main_user_ros_home}/rosdep"
# echo '---------------------------------------------------------------------------------------------------------'
# ls -la "${image_main_user_ros_home}/rosdep/meta.cache"
# echo '---------------------------------------------------------------------------------------------------------'
# ls -la "${image_main_user_colcon_home}"
# echo '#########################################################################################################'

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

source /opt/ros/${ROS_DISTRO}/setup.bash

pkgs_dir="${IMAGE_MAIN_USER_WORKSPACE}/src"

log "Executing script 'compile.sh'"

# If the flag --symlink-install is used, the source code folders cannot be removed after compilation. However,
# if the flag is omitted, the source code folders can be removed after compilation to save space.
# In this example Dockerfile, we use the flag --symlink-install.
bash /tmp/context/compile.sh --symlink-install "${pkgs_dir}" || {
    log "Error: Failed to run 'compile.sh'" 1>&2
    exit 1
}
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
