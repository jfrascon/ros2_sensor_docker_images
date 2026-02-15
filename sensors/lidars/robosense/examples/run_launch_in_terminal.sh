#!/usr/bin/env bash

# This script is used to launch the ROS2 driver manually inside the container.

[ ! -f "${IMAGE_MAIN_USER_WORKSPACE}/install/setup.bash" ] && {
    echo "ROS2 workspace not found at '${IMAGE_MAIN_USER_WORKSPACE}'" >&2
    exit 1
}

. "${IMAGE_MAIN_USER_WORKSPACE}/install/setup.bash"

bash /tmp/run_launch.sh
