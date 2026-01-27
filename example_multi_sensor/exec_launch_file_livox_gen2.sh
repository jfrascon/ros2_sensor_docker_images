#!/usr/bin/env bash

# The launch file uses arguments to receive inputs.
# The way to pass values from the Docker compose file to the container is through environment variables.
# This script adapts the environment variables to the launch file arguments.

namespace="${NAMESPACE:-}"
robot_name="${ROBOT_NAME:-}"
config_file="${CONFIG_FILE:-}" # json file with the LiDAR(s) configuration
params_file="${PARAMS_FILE:-}" # yaml file with the node parameters
topic_remappings="${TOPIC_REMAPPINGS:-}"
node_options="${NODE_OPTIONS:-}"
logging_options="${LOGGING_OPTIONS:-}"

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

# Ensure params file defines the field 'user_config_path', since it is required.
# The field 'user_config_path' in the YAML points to the JSON config file, describing the LiDAR(s) configuration.
if ! grep -q '^[[:space:]]*user_config_path:' "${params_file}"; then
    echo "Error: PARAMS_FILE must declare 'user_config_path' but it was not found" >&2
    exit 1
fi

robot_prefix="${robot_name}_"
config_path="${config_file}"
params_path="${params_file}"

# Variable to track if the JSON was modified (pattern '{{robot_prefix}}' found and replaced).
json_has_robot_prefix=0

# Step 1: If the JSON has the pattern {{robot_prefix}}, generate a new JSON with the substitution 'robot_prefix'.
# If it does not, keep the original JSON path.
if grep -q '{{robot_prefix}}' "${config_file}"; then
    json_has_robot_prefix=1 # Mark a new JSON file is generated with the robot_prefix substituted.
    tmp_config_file="$(mktemp)"
    cp "${config_file}" "${tmp_config_file}"
    # Allowed chars are [a-zA-Z0-9_], so no extra escaping is needed for the 'sed' command.
    sed -i "s/{{robot_prefix}}/${robot_prefix}/g" "${tmp_config_file}"
    config_path="${tmp_config_file}"
fi

# Step 2: Update user_config_path in YAML.
# - If the JSON was modified, always create a new YAML file pointing to the generated JSON
#   (because the value of the field 'user_config_path' is for sure different to the generated JSON path).
# - If the JSON was not modified, only create a new YAML file when the current value in the field 'user_config_path'
# differs from the original JSON path.
if [ "${json_has_robot_prefix}" -eq 1 ]; then
    tmp_params_file="$(mktemp)"
    # Replace the first user_config_path key, preserving indentation.
    sed -e "0,/^[[:space:]]*user_config_path:/s|^\\([[:space:]]*user_config_path:\\).*|\\1 \"${config_path}\"|" \
        "${params_file}" >"${tmp_params_file}"
    params_path="${tmp_params_file}"
else
    # Extract the current user_config_path value from the YAML (first occurrence only).
    current_path="$(sed -n 's/^[[:space:]]*user_config_path:[[:space:]]*//p' "${params_file}" | head -n1)"
    # Drop inline comments and trim whitespace.
    current_path="${current_path%%#*}"
    current_path="$(printf '%s' "${current_path}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    # Strip optional surrounding quotes.
    current_path="${current_path#\"}"
    current_path="${current_path%\"}"
    current_path="${current_path#\'}"
    current_path="${current_path%\'}"

    # Only rewrite the YAML if the current path does not match the original JSON path.
    if [ "${current_path}" != "${config_path}" ]; then
        tmp_params_file="$(mktemp)"
        # Update user_config_path to the original JSON path, keeping YAML indentation intact.
        sed -e "0,/^[[:space:]]*user_config_path:/s|^\\([[:space:]]*user_config_path:\\).*|\\1 \"${config_path}\"|" \
            "${params_file}" >"${tmp_params_file}"
        params_path="${tmp_params_file}"
    fi
fi

ros2 launch livox_ros_driver2 eut_sensor.launch.py namespace:=${namespace} robot_name:=${robot_name} params_file:=${params_path} topic_remappings:="${topic_remappings}" node_options:="${node_options}" logging_options:="${logging_options}"
