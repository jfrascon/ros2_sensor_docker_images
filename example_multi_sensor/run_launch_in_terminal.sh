#!/usr/bin/env bash

# This script is used to launch the ROS2 handler manually inside the container.

[ ! -f "${IMAGE_MAIN_USER_WORKSPACE}/install/setup.bash" ] && {
    echo "ROS2 workspace not found at '${IMAGE_MAIN_USER_WORKSPACE}'" >&2
    exit 1
}

. "${IMAGE_MAIN_USER_WORKSPACE}/install/setup.bash"

# It is assumed that each sensor container maps its launch wrapper script to '/tmp/run_launch.sh'.
[ ! -f "/tmp/run_launch.sh" ] && {
    echo "Launch script '/tmp/run_launch.sh' not found in the container" >&2
    exit 1
}

bash /tmp/run_launch.sh
