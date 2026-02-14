#!/usr/bin/env bash

# This script launches a Docker container with the RealSense ROS2 driver using Docker compose files.
# If mode is 'automatic', the container will automatically execute the script '/tmp/run_realsense_launch.sh' that
# launches the ROS2 driver, and you can check the logs with 'docker compose logs -f <service_name>'.
# If mode is 'manual', the container will start without executing the ROS2 driver, allowing you to connect to it with
# 'docker compose exec -it <service_name> bash' and launch the ROS2 driver manually by running the script
# '/tmp/run_realsense_launch_in_terminal.sh' from an interactive shell.

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

NAMESPACE_DEF=""
ROBOT_NAME_DEF="robot"
ROS_DOMAIN_ID_DEF="11"
# The default node name intentionally avoids the '_node' suffix because, by default, many RealSense topics are private
# (~) and inherit the node name in their final path. Using 'realsense_camera' keeps topic names focused on the device
# instead of exposing implementation-oriented naming in the topic hierarchy.
# It's better to have
# /myns/myrobot/realsense_camera/color/image_raw
# than
# /myns/myrobot/realsense_camera_node/color/image_raw
NODE_OPTIONS_DEF="name=realsense_camera,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0"
LOGGING_OPTIONS_DEF="log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true"

# For ROS2-Humble, and earlier versions of ROS2, 'ROS_LOCALHOST_ONLY=1|0' can be set to limit the discovery to
# localhost only.
# Since ROS2-Jazzy, more options are available to configure the DDS discovery behaviour:
# - ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT
#   * LOCALHOST means a node will only try to discover other nodes on the same machine.
#   * SUBNET is the default, and for DDS based middleware it means it will discover any node reachable via multicast.
#   * OFF means the node won't discover any other nodes, even on the same machine.
#   * SYSTEM_DEFAULT means 'don't change any discovery settings'.
# - ROS_STATIC_PEERS='192.168.0.1;remote.com'
# Reference: https://docs.ros.org/en/jazzy/Tutorials/Advanced/Improved-Dynamic-Discovery.html

usage() {
    cat <<EOF
Usage:
  $(basename "${BASH_SOURCE[0]}") <img_id> <mode> [--env KEY=VALUE]...
  $(basename "${BASH_SOURCE[0]}") [--help | -h]

Positional arguments:
  img_id        Docker image ID with the RealSense ROS2 driver
  mode          How to run the example: automatic or manual

Options:
  --env KEY=VALUE           Environment variable for the container (repeatable)
                            Common keys:
                            NAMESPACE (default: ${NAMESPACE_DEF})
                            ROBOT_NAME (default: ${ROBOT_NAME_DEF})
                            ROS_DOMAIN_ID (default: ${ROS_DOMAIN_ID_DEF})
                            NODE_OPTIONS (default: ${NODE_OPTIONS_DEF})
                            LOGGING_OPTIONS (default: ${LOGGING_OPTIONS_DEF})
                            ROS_LOCALHOST_ONLY=1|0 (up to ROS2 Humble, not set by default)
                            ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT (since ROS2 Jazzy, not set by default)
                            ROS_STATIC_PEERS='192.168.0.1;remote.com' (since ROS2 Jazzy, not set by default)

  --help, -h                Show this help and exit
EOF
}

SHORT_OPTS="h"
LONG_OPTS="help,env:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

# Parse arguments using getopt and set corresponding variables and flags.
eval set -- "${PARSED_ARGS}"

# After eval set -- ... we get:
# --env env_var_1 --env env_var_2 ... -- img_id mode
# --env may or may not be present; options may appear in any order.
# -- is the end of options marker.

env_vars=()

while true; do
    case "${1:-}" in
    --env)
        env_vars+=("$2")
        shift 2
        ;;
    -h | --help)
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
mode="${2:-}"

# Check positional arguments are provided.
[ -z "${IMG_ID}" ] || [ -z "${mode}" ] && {
    usage
    exit 1
}

shift 2
[ "$#" -gt 0 ] && echo "Warning: unexpected extra arguments: $*"

# Check if the image '${IMG_ID}', used by the Docker compose files, exists locally.

if ! docker image inspect "${IMG_ID}" 1>/dev/null 2>&1; then
    echo "Error: Docker image '${IMG_ID}' not found. Make sure to build it before running this script" >&2
    usage
    exit 1
fi

# Two compose files are passed to docker compose: the base one (always) and the mode-specific one (automatic or manual).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
compose_files=(-f "${SCRIPT_DIR}/docker_compose_base.yaml")

if [ "${mode}" == "automatic" ] || [ "${mode}" == "manual" ]; then
    compose_files+=("-f" "${SCRIPT_DIR}/docker_compose_mode_${mode}.yaml")
else
    echo "Supported modes are 'automatic' and 'manual' only" >&2
    usage
    exit 1
fi

# Assign default values to the environment variables that must be passed to the container, and override them if
# specified in the --env options.
NAMESPACE="${NAMESPACE_DEF}"
ROBOT_NAME="${ROBOT_NAME_DEF}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID_DEF}"
NODE_OPTIONS="${NODE_OPTIONS_DEF}"
LOGGING_OPTIONS="${LOGGING_OPTIONS_DEF}"

extra_env_vars=()

# Process --env KEY=VALUE options.
# Recognized keys (NAMESPACE, ROBOT_NAME, ROS_DOMAIN_ID, NODE_OPTIONS, LOGGING_OPTIONS) are
# assigned to specific variables, while unrecognized ones are collected in 'extra_env_vars' to be passed as-is to the
# container.
for env_kv in "${env_vars[@]}"; do
    # Reject entries without '=' to enforce KEY=VALUE format.
    if [[ ${env_kv} != *"="* ]]; then
        echo "Warning: ignoring env var '${env_kv}' (expected KEY=VALUE)" >&2
        continue
    fi

    env_key="${env_kv%%=*}"
    env_val="${env_kv#*=}"

    # if env_key is empty or does not match the regex for valid environment variable names, ignore it with a warning.
    if [[ -z "${env_key}" ]] || [[ ! "${env_key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "Warning: ignoring env var '${env_kv}' (invalid key, expected [A-Za-z_][A-Za-z0-9_]*)" >&2
        continue
    fi

    # Reject values that contain newlines to avoid issues when writing them to the env file for docker compose.
    if [[ "${env_val}" == *$'\n'* ]] || [[ "${env_val}" == *$'\r'* ]]; then
        echo "Warning: ignoring env var '${env_kv}' (value must be single-line)" >&2
        continue
    fi

    case "${env_key}" in
    NAMESPACE)
        NAMESPACE="${env_val}"
        ;;
    ROBOT_NAME)
        ROBOT_NAME="${env_val}"
        ;;
    ROS_DOMAIN_ID)
        ROS_DOMAIN_ID="${env_val}"
        ;;
    RMW_IMPLEMENTATION)
        echo "Error: --env RMW_IMPLEMENTATION is not allowed; it is fixed in docker_compose_base.yaml" >&2
        exit 1
        ;;
    CYCLONEDDS_URI)
        echo "Error: --env CYCLONEDDS_URI is not allowed; it is fixed in docker_compose_base.yaml" >&2
        exit 1
        ;;
    PARAMS_FILE)
        echo "Error: --env PARAMS_FILE is not allowed; it is fixed in docker_compose_base.yaml" >&2
        exit 1
        ;;
    NODE_OPTIONS)
        NODE_OPTIONS="${env_val}"
        ;;
    LOGGING_OPTIONS)
        LOGGING_OPTIONS="${env_val}"
        ;;
    IMG_ID)
        echo "Warning: ignoring --env IMG_ID=... (image is taken from <img_id> positional argument)" >&2
        ;;
    ENV_FILE)
        echo "Warning: ignoring --env ENV_FILE=... (managed internally by this script)" >&2
        ;;
    *)
        extra_env_vars+=("${env_key}=${env_val}")
        ;;
    esac
done

# Create a temporary env file for docker compose with the required environment variables for the container, and add any
# extra ones specified via --env.
# The file will be automatically deleted on script exit thanks to the trap command.
env_file="$(mktemp -p /tmp realsense_env_XXXXXX.env)"
trap 'rm -f "${env_file}"' EXIT

# Write environment variables to the env file in KEY=VALUE format.
# This file is mounted into the service environment through:
#   env_file:
#     - ${ENV_FILE:?ENV_FILE is required}
# in docker_compose_base.yaml.
{
    printf "NAMESPACE=%s\n" "${NAMESPACE}"
    printf "ROBOT_NAME=%s\n" "${ROBOT_NAME}"
    printf "ROS_DOMAIN_ID=%s\n" "${ROS_DOMAIN_ID}"
    printf "NODE_OPTIONS=%s\n" "${NODE_OPTIONS}"
    printf "LOGGING_OPTIONS=%s\n" "${LOGGING_OPTIONS}"

    for env_kv in "${extra_env_vars[@]}"; do
        printf "%s\n" "${env_kv}"
    done
} >"${env_file}"

echo "Generated env file: ${env_file}"

print_banner_text "=" "Launching RealSense in a Docker container of image '${IMG_ID}' in '${mode}' mode"

# This line allows graphical applications inside the container to be displayed on the screen you have connected.
# If you are in an X11 session, nothing else is required.
# If you are in a Wayland session, XWayland (the compatibility layer for X11 applications) should already be active.
# If you want to verify it, run 'pgrep Xwayland' in a terminal.
# If it is not active in your Wayland session, you will need to enable it.
# Remember that you must uncomment the line like `/tmp/.X11-unix:/tmp/.X11-unix` in the volumes section of the
# docker compose base file 'docker_compose_base.yaml' to mount the X11 socket inside the container.
# Warning: 'xhost +local:' is an effective way to visualize graphical applications on the host, but
# it allows any local user to access the X server. This might be a security risk on multi-user systems.
# Therefore, you can run inside the container rviz2 or rqt to visualize the camera data.
xhost +local:

IMG_ID="${IMG_ID}" ENV_FILE="${env_file}" docker compose "${compose_files[@]}" up -d

# if [ "${mode}" == "automatic" ]; then
# IMG_ID="${IMG_ID}" ENV_FILE="${env_file}" docker compose "${compose_files[@]}" up -d
# fi
