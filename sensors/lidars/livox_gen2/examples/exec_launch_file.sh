#!/usr/bin/env bash

# The launch file uses arguments to receive inputs.
# The way to pass values from the Docker compose file to the container is through environment variables.
# This script adapts the environment variables to the launch file arguments.

namespace="${NAMESPACE:-}"
robot_name="${ROBOT_NAME:-}"
config_file="${CONFIG_FILE:-}" # json file witht the LiDAR(s) configuration
params_file="${PARAMS_FILE:-}" # yaml file with the node parameters
topic_remappings="${TOPIC_REMAPPINGS:-}"
node_options="${NODE_OPTIONS:-}"
logging_options="${LOGGING_OPTIONS:-}"

# If the config_files is not provided, exit with error.
[ -z "${config_file}" ] && {
    echo "Error: The 'config_file' is required but not provided" >&2
    exit 1
}

# The config_file might contain a placeholder '{{robot_prefix}}' that must be replaced
# with the actual robot prefix, which is derived from the robot_name.
# First, validate that robot_name is provided and valid.
[ -z "${robot_name}" ] && {
    echo "Error: ROBOT_NAME environment variable is required" >&2
    exit 1
}

# Ensure the regex checks only ASCII letters and digits, even if the system locale differs.
LC_ALL=C

# A name in ROS2 is valid if:
# - The first character is a letter (a-z, A-Z) or underscore (_), never a number.
# - The rest of the characters can be letters (a-z, A-Z), numbers (0-9) or underscore (_).
if ! [[ ${robot_name} =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "Error: robot_name '${robot_name}' is invalid (first char cannot be a number: a-z, A-Z, _;" \
        "rest: a-z, A-Z, 0-9, _)" >&2
    exit 1
fi

robot_prefix="${robot_name}_"
tmp_config_file="$(mktemp)"
cp "${config_file}" "${tmp_config_file}"
# Allowed chars are [a-zA-Z0-9_], so no extra escaping is needed for sed.
sed -i "s/{{robot_prefix}}/${robot_prefix}/g" "${tmp_config_file}"

# The params_file might contain a placeholder '{{user_config_path}}' that must be replaced
# with the actual path of the config file inside the container, where the 'robot_prefix' has been already replaced.
tmp_params_file="$(mktemp)"
cp "${params_file}" "${tmp_params_file}"
# Use '|' as the separator so paths with '/' don't need escaping.
sed -i "s|{{user_config_path}}|${tmp_config_file}|g" "${tmp_params_file}"

echo $tmp_params_file
cat $tmp_params_file

ros2 launch livox_ros_driver2 eut_sensor.launch.py namespace:=${namespace} robot_name:=${robot_name} params_file:=${tmp_params_file} topic_remappings:="${topic_remappings}" node_options:="${node_options}" logging_options:="${logging_options}"
