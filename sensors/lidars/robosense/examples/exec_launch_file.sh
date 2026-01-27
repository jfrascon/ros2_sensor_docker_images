#!/usr/bin/env bash

# The launch file uses arguments to receive inputs.
# The way to pass values from the Docker compose file to the container is through environment variables.
# This script adapts the environment variables to the launch file arguments.

namespace="${NAMESPACE:-}"
robot_name="${ROBOT_NAME:-}"
config_file="${CONFIG_FILE:-}"
node_options="${NODE_OPTIONS:-}"
logging_options="${LOGGING_OPTIONS:-}"

# Validate that robot_name is provided and valid.
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

# If the config_files is not provided, exit with error.
[ -z "${config_file}" ] && {
    echo "Error: The 'config_file' is required but not provided" >&2
    exit 1
}

# If the config_file does not exist or is not a file, exit with error.
[ ! -f "${config_file}" ] && {
    echo "Error: The specified CONFIG_FILE '${config_file}' does not exist or is not a file" >&2
    exit 1
}

# Optionally replace the '{{robot_prefix}}' placeholder with the actual robot prefix ("${robot_name}_").
# Only generate a new config if the placeholder is present.
if grep -q '{{robot_prefix}}' "${config_file}"; then
    robot_prefix="${robot_name}_"
    tmp_config_file="$(mktemp)"
    cp "${config_file}" "${tmp_config_file}"
    # Allowed chars are [a-zA-Z0-9_], so no extra escaping is needed for sed.
    sed -i "s/{{robot_prefix}}/${robot_prefix}/g" "${tmp_config_file}"
    config_file="${tmp_config_file}"
fi

ros2 launch rslidar_sdk eut_sensor.launch.py namespace:="${namespace}" robot_name:="${robot_name}" config_file:="${config_file}" node_options:="${node_options}" logging_options:="${logging_options}"
