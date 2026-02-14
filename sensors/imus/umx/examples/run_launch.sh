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

# Validate UM_MODEL (allowed values: 6 or 7).
if [ "${um_model}" != "6" ] && [ "${um_model}" != "7" ]; then
    echo "Error: UM_MODEL must be 6 or 7 (got '${um_model}')" >&2
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

# Build launch arguments dynamically to avoid passing empty values that can break ros2 launch parsing.
# robot_name, um_model and params_file are required, so they are always included. The rest are optional and only
# included if not empty.
launch_args=(
    "robot_name:=${robot_name}"
    "um_model:=${um_model}"
    "params_file:=${params_file}"
)

[ -n "${namespace}" ] && launch_args+=("namespace:=${namespace}")
[ -n "${topic_remappings}" ] && launch_args+=("topic_remappings:=${topic_remappings}")
[ -n "${node_options}" ] && launch_args+=("node_options:=${node_options}")
[ -n "${logging_options}" ] && launch_args+=("logging_options:=${logging_options}")

if [ -z "${RMW_IMPLEMENTATION:-}" ]; then
    echo "ERROR: RMW_IMPLEMENTATION is not set or empty" >&2
    exit 1
fi

if [ -z "${ROS_DOMAIN_ID:-}" ]; then
    echo "ERROR: ROS_DOMAIN_ID is not set or empty" >&2
    exit 1
fi

ros2 launch umx_bringup eut_sensor.launch.py "${launch_args[@]}"
