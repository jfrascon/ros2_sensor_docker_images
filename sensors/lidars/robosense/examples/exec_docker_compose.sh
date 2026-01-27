#!/usr/bin/env bash

# This script is aimed to launch a Docker container that contains the ROS2 driver for the Robosense LiDARs
# If the mode is 'automatic', this script will start the container and automatically launch the driver. You can start
# another terminal and connect to the container to see the output topics.
# If the mode is 'manual', this script will start the container, but you will need to connect to the container and run
# the script 'exec_manual_launch.sh', to launch the driver.

print_repeats() {
    local -r char="${1}"
    local -r count="${2}"
    local i

    for ((i = 1; i <= count; i++)); do
        echo -n "${char}"
    done

    echo
}

print_banner_text() {
    local -r banner_char="${1}"
    local -r text="${2}"
    local -r pad="${banner_char}${banner_char}"

    print_repeats "${banner_char}" $((${#text} + 6))
    echo "${pad} ${text} ${pad}"
    print_repeats "${banner_char}" $((${#text} + 6))
}

# Regarding the possibility to pass environment variables to the container:
# Depending on the ROS2 distro used, different environment variables can be set.
# For example, for ROS2 Humble 'ROS_LOCALHOST_ONLY: 1/0' can be set to limit the discovery to localhost only.
# Example:
#  ./<this_script> robosense:humble 1 automatic --env ROS_LOCALHOST_ONLY=1
# For ROS2 Jazzy, more options are available to configure the DDS discovery behavior:
# ROS_AUTOMATIC_DISCOVERY_RANGE: LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT
# LOCALHOST means a node will only try to discover other nodes on the same machine.
# SUBNET is the default, and for DDS based middleware it means it will discover any node reachable via multicast.
# OFF means the node won't discover any other nodes, even on the same machine.
# SYSTEM_DEFAULT means 'don't change any discovery settings'.
# ROS_STATIC_PEERS: '192.168.0.1;remote.com'
# Reference: https://docs.ros.org/en/jazzy/Tutorials/Advanced/Improved-Dynamic-Discovery.html
# Example:
#  ./<this_script> robosense:jazzy 2 manual \
#    --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST --env ROS_STATIC_PEERS='192.168.0.1'

usage() {
    cat <<EOF
Usage:
  $(basename ${BASH_SOURCE[0]}) <img_id> <#example> <mode> [options]

Positional arguments:
  img_id        Docker image ID with the Robosense ROS2 driver
  example       Example number: 1 or 2
  mode          How to run the example: automatic or manual

Options:
  --namespace VALUE         Namespace prefix (default: empty)
  --robot-name VALUE        Robot name (default: robot)
  --ros-domain-id VALUE     ROS domain ID (default: 11)
  --rmw-implementation VAL  RMW implementation (default: rmw_zenoh_cpp)
  --env env_var             Additional environment variable in KEY=VALUE format (repeatable)
  --help          Show this help and exit
EOF
    exit 1
}

# Normalize arguments with GNU getopt.
# -o ''     -> no short options
# -l ...    -> long options; ":" ⇒ option requires a value
# --        -> end of getopt's own flags; after this, pass script args to parse
# "$@"      -> forward all original args verbatim (keeps spaces/quotes)
# getopt    -> normalizes: reorders options first, splits values, appends a final "--"
# on error  -> exits non-zero; we show usage and exit 2
PARSED=$(getopt -o h -l env:,help,namespace:,robot-name:,ros-domain-id:,rmw-implementation: -- "$@") || {
    usage
    exit 1
}

# Replace $@ with the normalized list; eval preserves quoting from getopt’s output
eval set -- "${PARSED}"

# After eval set -- ... we get:
# --namespace VALUE --robot-name VALUE --ros-domain-id VALUE --rmw-implementation VALUE --env env_var_1 --env env_var_2 ... -- img_id example mode
# --env may or may not be present; options may appear in any order
# -- is the end of options marker

namespace=""
robot_name="robot"
ros_domain_id="11"
rmw_implementation="rmw_zenoh_cpp"
env_vars=() # optional extra env vars

while true; do
    case "${1:-}" in
    --env)
        env_vars+=("$2")
        shift 2
        ;;
    --namespace)
        namespace="$2"
        shift 2
        ;;
    --robot-name)
        robot_name="$2"
        shift 2
        ;;
    --ros-domain-id)
        ros_domain_id="$2"
        shift 2
        ;;
    --rmw-implementation)
        rmw_implementation="$2"
        shift 2
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;; # end of options, positionals follow
    *)
        usage
        exit 2
        ;;
    esac
done

IMG_ID="${1:-}"
example="${2:-}"
mode="${3:-}"

# Check positional arguments are provided.
[ -z "${IMG_ID}" ] || [ -z "${example}" ] || [ -z "${mode}" ] && usage

shift 3
[ "$#" -gt 0 ] && echo "Warning: unexpected extra arguments: $*"

# Check if the image '${IMG_ID}', used by the Docker compose files, exists locally.

if ! docker image inspect "${IMG_ID}" 1>/dev/null 2>&1; then
    echo "Error: Docker image '${IMG_ID}' not found. Make sure to build it before running this script" >&2
    usage
fi

# Some environment variables must be exported because the used Docker compose files relies on them.
export IMG_ID
export NAMESPACE="${namespace}"
export ROBOT_NAME="${robot_name}"
export ROS_DOMAIN_ID="${ros_domain_id}"
export RMW_IMPLEMENTATION="${rmw_implementation}"

if [ "${example}" == "1" ]; then
    export CONFIG_FILE="example_${example}.front_robosense_helios_16p_config.yaml"
elif [ "${example}" == "2" ]; then
    export CONFIG_FILE="example_${example}.front_back_robosense_helios_16p_config.yaml"
else
    echo "Invalid example number. Please provide 1 or 2." >&2
    usage
fi

compose_files=(-f "dc_base.yaml")

if [ "${mode}" == "automatic" ] || [ "${mode}" == "manual" ]; then
    compose_files+=("-f" "dc_mode_${mode}.yaml")
else
    echo "Supported modes are 'automatic' and 'manual' only" >&2
    usage
fi

# Create a temporary Docker compose file to pass extra environment variables to the service.
env_lines=()

escape_env_val() {
    local val="$1"
    val=${val//\'/\'\'}
    printf "%s" "${val}"
}

for env_kv in "${env_vars[@]}"; do
    # Reject entries without '=' to enforce KEY=VALUE format.
    if [[ ${env_kv} != *"="* ]]; then
        echo "Warning: ignoring env var '${env_kv}' (expected KEY=VALUE)" >&2
        continue
    fi

    env_key="${env_kv%%=*}"
    env_val="${env_kv#*=}"

    # Skip empty keys or values to avoid invalid env entries.
    if [ -z "${env_key}" ] || [ -z "${env_val}" ]; then
        echo "Warning: ignoring env var '${env_kv}' (empty key or value)" >&2
        continue
    fi

    env_val="$(escape_env_val "${env_val}")"
    env_lines+=("      ${env_key}: '${env_val}'")
done

if [ "${#env_lines[@]}" -gt 0 ]; then
    env_vars_file="$(mktemp -p /tmp dc_extra_env_XXXXXX.yaml)"
    printf "services:\n  robosense_lidar_srvc:\n    environment:\n" >"${env_vars_file}"
    for line in "${env_lines[@]}"; do
        printf "%s\n" "${line}" >>"${env_vars_file}"
    done
    echo "Generated extra env file: ${env_vars_file}"
    # Include the generated extra-env file so Compose merges it into the service.
    compose_files+=("-f" "${env_vars_file}")
fi

print_banner_text "=" "Launching the node 'rslidar_sdk_node' in a Docker container of the image '${IMG_ID}' using the example file '${CONFIG_FILE}' in '${mode}' mode"

# This line allows graphical applications inside the container to be displayed on the screen you have connected.
# If you are in an X11 session, nothing else is required.
# If you are in a Wayland session, XWayland (the compatibility layer for X11 applications) should already be active.
# If you want to verify it, run 'pgrep Xwayland' in a terminal.
# If it is not active in your Wayland session, you will need to enable it.
# Remember that you must uncomment the line like `/tmp/.X11-unix:/tmp/.X11-unix` in the volumes section of the
# docker compose base file 'dc_base.yaml' to mount the X11 socket inside the container.
# Warning: 'xhost +local:' is an effective way to visualize graphical applications on the host, but
# it allows any local user to access the X server. This might be a security risk on multi-user systems.
# Therefore, you can run inside the container rviz2 or rqt to visualize the LiDAR data.
xhost +local:

docker compose "${compose_files[@]}" up -d
