#!/usr/bin/env bash

# The launch file uses arguments to receive inputs.
# The way to pass values from the Docker compose file to the container is through environment variables.
# This script adapts the environment variables to the launch file arguments.

namespace="${NAMESPACE:-}"
robot_name="${ROBOT_NAME:-}"
params_file="${PARAMS_FILE:-}"
topic_remappings="${TOPIC_REMAPPINGS:-}"
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

# If the params_file is not provided, exit with error.
[ -z "${params_file}" ] && {
    echo "Error: The 'params_file' is required but not provided" >&2
    exit 1
}

# If the params_file does not exist or is not a file, exit with error.
[ ! -f "${params_file}" ] && {
    echo "Error: The specified PARAMS_FILE '${params_file}' does not exist or is not a file" >&2
    exit 1
}

# The params file can use the placeholder '$(var robot_prefix)' (for example in frame_id).
# The launch file resolves it using ROBOT_NAME. If it is not present, no prefix substitution occurs.
if ! grep -q '\$(var robot_prefix)' "${params_file}"; then
    echo "Warning: PARAMS_FILE does not use '\$(var robot_prefix)';" \
        "frame_id values will not be prefixed with ROBOT_NAME" >&2
fi

ros2 launch realsense2_camera eut_sensor.launch.py namespace:="${namespace}" robot_name:="${robot_name}" params_file:="${params_file}" topic_remappings:="${topic_remappings}" node_options:="${node_options}" logging_options:="${logging_options}"
