#!/usr/bin/env bash

# The launch file uses arguments to receive inputs.
# The way to pass values from the Docker compose file to the container is through environment variables.
# This script adapts the environment variables to the launch file arguments.

namespace="${NAMESPACE:-}"
robot_name="${ROBOT_NAME:-}"
config_file="${CONFIG_FILE:-}"
node_options="${NODE_OPTIONS:-}"
logging_options="${LOGGING_OPTIONS:-}"

abort_w_error() {
    echo "[$(date --utc '+%Y-%m-%d_%H-%M-%S')] Error: $*" >&2
    exit 1
}

# Validate that robot_name is provided and valid.
if [ -z "${robot_name}" ]; then
    abort_w_error "ROBOT_NAME environment variable is required"
fi

# Ensure the regex checks only ASCII letters and digits, even if the system locale differs.
LC_ALL=C

# A name in ROS2 is valid if:
# - The first character is a letter (a-z, A-Z) or underscore (_), never a number.
# - The rest of the characters can be letters (a-z, A-Z), numbers (0-9) or underscore (_).
if ! [[ ${robot_name} =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    abort_w_error "robot_name '${robot_name}' is invalid (first char cannot be a number: a-z, A-Z, _; rest: a-z, A-Z, 0-9, _)"
fi

# If the config_file is not provided, exit with error.
if [ -z "${config_file}" ]; then
    abort_w_error "The 'config_file' is required but not provided"
fi

# If the config_file does not exist or is not a file, exit with error.
if [ ! -f "${config_file}" ]; then
    abort_w_error "The specified CONFIG_FILE '${config_file}' does not exist or is not a file"
fi

# Optionally replace the '{{robot_prefix}}' placeholder with the actual robot prefix.
if grep -q '{{robot_prefix}}' "${config_file}"; then
    robot_prefix="${robot_name}_"

    if ! tmp_config_file="$(mktemp "/tmp/robosense_config_$(date +%Y%m%d_%H%M%S)_XXXXXX.yaml")"; then
        abort_w_error "Failed to allocate temporary CONFIG_FILE in /tmp"
    fi

    if ! cp "${config_file}" "${tmp_config_file}"; then
        abort_w_error "Failed to copy CONFIG_FILE '${config_file}' to temporary file"
    fi

    # Allowed chars are [a-zA-Z0-9_], so no extra escaping is needed for sed replacement.
    if ! sed -i "s/{{robot_prefix}}/${robot_prefix}/g" "${tmp_config_file}"; then
        abort_w_error "Failed to substitute '{{robot_prefix}}' in temporary file '${tmp_config_file}'"
    fi

    config_file="${tmp_config_file}"
fi

# Keep CONFIG_FILE aligned with the effective config file actually used at launch time.
export CONFIG_FILE="${config_file}"

# Build launch arguments dynamically to avoid passing empty values that can break ros2 launch parsing.
# robot_name and config_file are required, so they are always included. The rest are optional and only included if not
# empty.
launch_args=(
    "robot_name:=${robot_name}"
    "config_file:=${config_file}"
)

if [ -n "${namespace}" ]; then
    launch_args+=("namespace:=${namespace}")
fi

if [ -n "${node_options}" ]; then
    launch_args+=("node_options:=${node_options}")
fi

if [ -n "${logging_options}" ]; then
    launch_args+=("logging_options:=${logging_options}")
fi

if [ -z "${RMW_IMPLEMENTATION:-}" ]; then
    abort_w_error "RMW_IMPLEMENTATION is not set or empty"
fi

if [ -z "${ROS_DOMAIN_ID:-}" ]; then
    abort_w_error "ROS_DOMAIN_ID is not set or empty"
fi

ros2 launch rslidar_sdk eut_sensor.launch.py "${launch_args[@]}"
