#!/usr/bin/env bash

ROS_DISTRO="${1}"
BUILD_W_CUDA="${2:-no}" # yes|no

script="${BASH_SOURCE:-${0}}"
script_name="$(basename "${script}")"
script_dir="$(cd "$(dirname "${script}")" && pwd)"
lidars_dir="$(dirname "${script_dir}")"
sensors_dir="$(dirname "${lidars_dir}")"
sensor_imgs_dir="$(dirname "${sensors_dir}")"

if [ -z "${ROS_DISTRO}" ]; then
    echo "Usage: ${script_name} <ros_distro> [build_with_cuda (yes|no, default no)]"
    exit 1
fi

extra_args=()

# If we want to use the compilation flag -DBUILD_WITH_CUDA=ON when compiling the librealsense2 library, if we
# use a host machine with an NVIDIA GPU and the NVIDIA Container Toolkit installed, we have to use a json file with the
# option build_with_cuda set to true, and pass it to the build.py script.

build_with_cuda="false"

[ "${BUILD_W_CUDA}" == "yes" ] && build_with_cuda="true"

options_file="$(mktemp /tmp/realsense_build_opts_XXXXXX.json)"

cat >"${options_file[0]}" <<JSON
{
  "realsense": {
      "build_with_cuda": ${build_with_cuda},
      "keep_src_code": true
  }
}
JSON

chmod 666 "${options_file}"

extra_args+=(--file "${options_file}")

echo "Building realsense image for ROS distro ${ROS_DISTRO} with BUILD_W_CUDA=${BUILD_W_CUDA}"
sleep 5
python ${sensor_imgs_dir}/build.py realsense "${ROS_DISTRO}" "realsense:${ROS_DISTRO}" --pull "${extra_args[@]}"
