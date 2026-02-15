#!/usr/bin/env bash

# The launch file uses arguments to receive inputs.
# The way to pass values from the Docker compose file to the container is through environment variables.
# This script adapts the environment variables to the launch file arguments.

namespace="${NAMESPACE:-}"
robot_name="${ROBOT_NAME:-}"
params_file="${PARAMS_FILE:-}" # YAML file with node parameters.
topic_remappings="${TOPIC_REMAPPINGS:-}"
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
    abort_w_error "ROBOT_NAME='${robot_name}' is invalid (first char cannot be a number: a-z, A-Z, _; rest: a-z, A-Z, 0-9, _)"
fi

# If the params_file is not provided, exit with error.
if [ -z "${params_file}" ]; then
    abort_w_error "The 'params_file' is required but not provided"
fi

# If the params_file does not exist or is not a file, exit with error.
if [ ! -f "${params_file}" ]; then
    abort_w_error "The specified PARAMS_FILE '${params_file}' does not exist or is not a file"
fi

# Ensure params file defines the field 'user_config_path', since it is required and is the source
# of truth for the JSON config path inside the container.
user_config_path_count="$(grep -c '^[[:space:]]*user_config_path:' "${params_file}" || true)"

if [ "${user_config_path_count}" -eq 0 ]; then
    abort_w_error "PARAMS_FILE must declare 'user_config_path' but it was not found"
fi

if [ "${user_config_path_count}" -gt 1 ]; then
    abort_w_error "PARAMS_FILE has multiple 'user_config_path' entries; expected exactly one"
fi

# Extract user_config_path value from PARAMS_FILE.
user_config_path="$(sed -n 's/^[[:space:]]*user_config_path:[[:space:]]*//p' "${params_file}" | head -n1)"

if [ -z "${user_config_path}" ]; then
    abort_w_error "user_config_path is present but has no value in PARAMS_FILE"
fi

# Remove inline comments from the extracted value (everything after '#').
user_config_path="${user_config_path%%#*}"
# Trim leading and trailing whitespace.
user_config_path="$(printf '%s' "${user_config_path}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
# Remove an optional leading double quote.
user_config_path="${user_config_path#\"}"
# Remove an optional trailing double quote.
user_config_path="${user_config_path%\"}"
# Remove an optional leading single quote.
user_config_path="${user_config_path#\'}"
# Remove an optional trailing single quote.
user_config_path="${user_config_path%\'}"

if [ -z "${user_config_path}" ]; then
    abort_w_error "user_config_path is empty after parsing in PARAMS_FILE"
fi

if [ ! -f "${user_config_path}" ]; then
    abort_w_error "user_config_path '${user_config_path}' does not exist or is not a file in the container"
fi

robot_prefix="${robot_name}_"

# Step 1: If the JSON has the pattern {{robot_prefix}}, generate a new JSON with the substitution 'robot_prefix'.
# If it does not, keep the original JSON path and the original params file.
if grep -q '{{robot_prefix}}' "${user_config_path}"; then
    if ! tmp_config_file="$(mktemp "/tmp/livox_config_$(date +%Y%m%d_%H%M%S)_XXXXXX.json")"; then
        abort_w_error "Failed to allocate temporary JSON file in /tmp"
    fi

    if ! cp "${user_config_path}" "${tmp_config_file}"; then
        abort_w_error "Failed to copy JSON config file '${user_config_path}' to temporary file"
    fi

    # Allowed chars are [a-zA-Z0-9_], so no extra escaping is needed for the sed replacement.
    if ! sed -i "s/{{robot_prefix}}/${robot_prefix}/g" "${tmp_config_file}"; then
        abort_w_error "Failed to substitute '{{robot_prefix}}' in temporary JSON file '${tmp_config_file}'"
    fi

    # Step 2: Update user_config_path in YAML because JSON was modified.
    if ! tmp_params_file="$(mktemp "/tmp/livox_params_$(date +%Y%m%d_%H%M%S)_XXXXXX.yaml")"; then
        abort_w_error "Failed to allocate temporary PARAMS file in /tmp"
    fi

    if ! sed -e "0,/^[[:space:]]*user_config_path:/s|^\\([[:space:]]*user_config_path:\\).*|\\1 \"${tmp_config_file}\"|" \
        "${params_file}" >"${tmp_params_file}"; then
        abort_w_error "Failed to generate temporary PARAMS file '${tmp_params_file}'"
    fi

    params_file="${tmp_params_file}"
fi

# Keep PARAMS_FILE aligned with the effective params file actually used at launch time.
export PARAMS_FILE="${params_file}"

# Build launch arguments dynamically to avoid passing empty values that can break ros2 launch parsing.
# robot_name and params_file are required, so they are always included. The rest are optional and only included if not
# empty.
launch_args=(
    "robot_name:=${robot_name}"
    "params_file:=${params_file}"
)

if [ -n "${namespace}" ]; then
    launch_args+=("namespace:=${namespace}")
fi

if [ -n "${topic_remappings}" ]; then
    launch_args+=("topic_remappings:=${topic_remappings}")
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

ros2 launch livox_ros_driver2 eut_sensor.launch.py "${launch_args[@]}"
