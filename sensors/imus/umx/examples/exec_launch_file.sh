#!/usr/bin/env bash

# The launch file uses arguments to receive inputs.
# The way to pass values from the Docker compose file to the container is through environment variables.
# This script adapts the environment variables to the launch file arguments.

namespace="${NAMESPACE:-}"
robot_name="${ROBOT_NAME:-}"
um_model="${UM_MODEL:-7}"
params_file="${PARAMS_FILE:-}"
topic_remappings="${TOPIC_REMAPPINGS:-}"
node_options="${NODE_OPTIONS:-}"
logging_options="${LOGGING_OPTIONS:-}"

ros2 launch umx_driver eut_sensor.launch.py namespace:=${namespace} robot_name:=${robot_name} um_model:=${um_model} params_file:=${params_file} topic_remappings:="${topic_remappings}" node_options:="${node_options}" logging_options:="${logging_options}"
