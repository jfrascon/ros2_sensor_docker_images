#!/usr/bin/env bash

# Install only resolvable Debian packages.
install_pkgs() {
    local pkgs=("$@")
    local valid=()
    local bad=()
    local already=()
    local pkg
    local result

    [ ${#pkgs[@]} -eq 0 ] && {
        log "No packages given" >&2
        return 0
    }

    for pkg in "${pkgs[@]}"; do
        # If it is already installed, skip it.
        if dpkg-query -W -f='${Status}\n' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
            log "Checking package '${pkg}': already installed"
            already+=("${pkg}")
            continue
        fi

        if apt-get --simulate --option=Dpkg::Use-Pty=0 --no-install-recommends install "${pkg}" >/dev/null 2>&1; then
            valid+=("${pkg}")
            verb="installable"
        else
            bad+=("${pkg}")
            verb="not installable"
        fi

        log "Checking package '${pkg}': ${verb}"
    done

    # Every package is already installed, nothing to do.
    if [ ${#already[@]} -eq ${#pkgs[@]} ]; then
        log "All requested packages are already installed"
        return 0
    fi

    # No valid packages to install.
    if [ ${#valid[@]} -eq 0 ]; then
        log "No installable packages" 2
        return 1
    fi

    apt-get install --yes --no-install-recommends "${valid[@]}" || {
        log "Installation failed: ${valid[*]}" >&2
        return 1
    }

    return 0
}

log() { echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')]" "$@"; }

script="${BASH_SOURCE:-${0}}"
script_name="$(basename "${script}")"

# This script must be run by root.
[ "$(id --user)" -ne 0 ] && {
    log "Error: root user must be active to run the script '${script_name}'" 2
    exit 1
}

# Minimum ROS2 installation

ROS_DISTRO="${1}"
ROS_VERSION="${2}"

[ -z "${ROS_DISTRO}" ] && {
    log "Error: ROS_DISTRO not set" >&2
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

log "Installing ROS${ROS_VERSION}-${ROS_DISTRO}"

apt-get update --yes --quiet --quiet || {
    log "apt-get update failed" >&2
    exit 1
}

# Install the apt-utils package first, to avoid warnings when installing packages if this package
# is not installed previously.
install_pkgs apt-utils || {
    log "Installation of apt-utils failed" >&2
    exit 1
}

# Install the software-properties-common package, which provides the add-apt-repository command.
install_pkgs python3-software-properties software-properties-common || {
    log "Installation of software-properties-common failed" >&2
    exit 1
}

# Now add-apt-repository is available, and we can add the universe repository that contains many
# of the packages we need. Next, the index is updated, and the system is upgraded to ensure all packages are up to date.
add-apt-repository --yes universe || {
    log "Adding universe repository failed" >&2
    exit 1
}

apt-get update --yes --quiet --quiet || {
    log "apt-get update failed" >&2
    exit 1
}

install_pkgs curl gpg || {
    log "Installation of curl and gpg failed" >&2
    exit 1
}

gpg_dir="/etc/apt/keyrings"
mkdir --verbose --parent "${gpg_dir}"
gpg_file="${gpg_dir}/ros.gpg"

curl --fail --silent --show-error --location https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | gpg --dearmor --output "${gpg_file}" || {
    log "Downloading or dearmoring the ROS2 GPG key failed" >&2
    exit 1
}

chmod 644 "${gpg_file}"
version_codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
url="http://packages.ros.org/ros2/ubuntu"
ros_deb_line="deb [arch=$(dpkg --print-architecture) signed-by=${gpg_file}] ${url} ${version_codename} main"
ros_list_file="/etc/apt/sources.list.d/ros.list"
echo "${ros_deb_line}" | tee "${ros_list_file}" >/dev/null

# Explanation on the package 'ros2-apt-source':
# The command was introduced in 2025 to mitigate the package repository key expiration issue.
# It automatically updates the GPG keys used to verify the authenticity of packages from the ROS
# repository, ensuring that users can continue to install and update ROS packages without
# encountering key expiration errors.
# But the package has to be installed one first time, and then it can make its job in the future.
# Therefore, we follow the procudere of downloading the key manually, installing the package,
# and then removing the manually downloaded key. After this, the package will take care of the key
# in the future.

apt-get update --yes --quiet --quiet || {
    log "apt-get update failed" >&2
    exit 1
}

install_pkgs ros-${ROS_DISTRO}-ros-core \
    ros2-apt-source \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    ros-${ROS_DISTRO}-rmw-fastrtps-cpp \
    ros-${ROS_DISTRO}-rmw-fastrtps-dynamic-cpp \
    ros-${ROS_DISTRO}-rmw-zenoh-cpp \
    ros-${ROS_DISTRO}-rviz2 \
    python3-colcon-common-extensions \
    python3-colcon-metadata \
    python3-colcon-mixin \
    python3-pip \
    python3-rosdep \
    python3-vcstool || {
    log "Installation of ROS2 core packages failed" >&2
    exit 1
}

rm -rf "${ros_list_file}"
rm -rf "${gpg_file}"

log "Removing installation residues from apt cache"
apt-get autoclean || {
    log "Autoclean failed" >&2
    exit 1
}

apt-get autoremove --purge -y || {
    log "Autoremove failed" >&2
    exit 1
}

apt-get clean || {
    log "Clean failed" >&2
    exit 1
}

rm -rf /var/lib/apt/lists/* &>/dev/null
