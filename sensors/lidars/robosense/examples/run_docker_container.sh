#!/usr/bin/env bash

# This script launches a Docker container with the RoboSense ROS2 driver using Docker compose files.
# If mode is 'automatic', the container will automatically execute '/tmp/run_launch.sh'.
# If mode is 'manual', the container will start without launching the driver; then you can connect to
# it and run '/tmp/run_launch_in_terminal.sh' manually.

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
EXAMPLE_DEF="1"
NODE_OPTIONS_DEF="name=robosense_lidar_ros2_handler,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0"
LOGGING_OPTIONS_DEF="log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true"

# For ROS2-Humble, and earlier versions of ROS2, 'ROS_LOCALHOST_ONLY=1|0' can be set to limit the discovery to
# localhost only.
# Since ROS2-Jazzy, more options are available to configure the DDS discovery behaviour:
# - ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT
# - ROS_STATIC_PEERS='192.168.0.1;remote.com'
# Reference: https://docs.ros.org/en/jazzy/Tutorials/Advanced/Improved-Dynamic-Discovery.html

usage() {
    cat <<EOF2
Usage:
  $(basename "${BASH_SOURCE[0]}") <img_id> <mode> [--example 1|2] [--env KEY=VALUE]...
  $(basename "${BASH_SOURCE[0]}") [--help | -h]

Positional arguments:
  img_id        Docker image ID with the RoboSense ROS2 driver
  mode          How to run the example: automatic or manual

Options:
  --example VALUE           Example number: 1 or 2 (default: ${EXAMPLE_DEF})
  --env KEY=VALUE           Environment variable for the container (repeatable)
                            Common keys:
                            NAMESPACE (default: ${NAMESPACE_DEF})
                            ROBOT_NAME (default: ${ROBOT_NAME_DEF})
                            ROS_DOMAIN_ID (default: ${ROS_DOMAIN_ID_DEF})
                            NODE_OPTIONS (default: ${NODE_OPTIONS_DEF})
                            LOGGING_OPTIONS (default: ${LOGGING_OPTIONS_DEF})
                            TOPIC_REMAPPINGS is not supported in RoboSense (set topics in config file)
                            ROS_LOCALHOST_ONLY=1|0 (up to ROS2 Humble, not set by default)
                            ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT (since ROS2 Jazzy, not set by default)
                            ROS_STATIC_PEERS='192.168.0.1;remote.com' (since ROS2 Jazzy, not set by default)

  --help, -h                Show this help and exit
EOF2
}

SHORT_OPTS="h"
LONG_OPTS="help,env:,example:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

eval set -- "${PARSED_ARGS}"

EXAMPLE="${EXAMPLE_DEF}"
env_vars=()

while true; do
    case "${1:-}" in
    --env)
        env_vars+=("$2")
        shift 2
        ;;
    --example)
        EXAMPLE="$2"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Error: unexpected option '${1}'" >&2
        usage
        exit 2
        ;;
    esac
done

IMG_ID="${1:-}"
mode="${2:-}"

[ -z "${IMG_ID}" ] || [ -z "${mode}" ] && {
    usage
    exit 1
}

shift 2
[ "$#" -gt 0 ] && echo "Warning: unexpected extra arguments: $*"

if [ "${EXAMPLE}" != "1" ] && [ "${EXAMPLE}" != "2" ]; then
    echo "Supported example values are 1 and 2 only" >&2
    usage
    exit 1
fi

if ! docker image inspect "${IMG_ID}" 1>/dev/null 2>&1; then
    echo "Error: Docker image '${IMG_ID}' not found. Make sure to build it before running this script" >&2
    usage
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
compose_files=(-f "${SCRIPT_DIR}/docker_compose_base.yaml")

if [ "${mode}" == "automatic" ] || [ "${mode}" == "manual" ]; then
    compose_files+=("-f" "${SCRIPT_DIR}/docker_compose_mode_${mode}.yaml")
else
    echo "Supported modes are 'automatic' and 'manual' only" >&2
    usage
    exit 1
fi

if [ "${EXAMPLE}" == "1" ]; then
    CONFIG_FILE_HOST="${SCRIPT_DIR}/example_1.front_robosense_helios_16p_config.yaml"
else
    CONFIG_FILE_HOST="${SCRIPT_DIR}/example_2.front_back_robosense_helios_16p_config.yaml"
fi

[ ! -f "${CONFIG_FILE_HOST}" ] && {
    echo "Error: Configuration file '${CONFIG_FILE_HOST}' does not exist or is not a file" >&2
    exit 1
}

NAMESPACE="${NAMESPACE_DEF}"
ROBOT_NAME="${ROBOT_NAME_DEF}"
ROS_DOMAIN_ID="${ROS_DOMAIN_ID_DEF}"
NODE_OPTIONS="${NODE_OPTIONS_DEF}"
LOGGING_OPTIONS="${LOGGING_OPTIONS_DEF}"

extra_env_vars=()

for env_kv in "${env_vars[@]}"; do
    if [[ ${env_kv} != *"="* ]]; then
        echo "Warning: ignoring env var '${env_kv}' (expected KEY=VALUE)" >&2
        continue
    fi

    env_key="${env_kv%%=*}"
    env_val="${env_kv#*=}"

    if [[ -z "${env_key}" ]] || [[ ! "${env_key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
        echo "Warning: ignoring env var '${env_kv}' (invalid key, expected [A-Za-z_][A-Za-z0-9_]*)" >&2
        continue
    fi

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
    CONFIG_FILE_HOST)
        echo "Warning: ignoring --env CONFIG_FILE_HOST=... (selected internally from --example)" >&2
        ;;
    CONFIG_FILE)
        echo "Error: --env CONFIG_FILE is not allowed; it is fixed in docker_compose_base.yaml" >&2
        exit 1
        ;;
    NODE_OPTIONS)
        NODE_OPTIONS="${env_val}"
        ;;
    LOGGING_OPTIONS)
        LOGGING_OPTIONS="${env_val}"
        ;;
    TOPIC_REMAPPINGS)
        echo "Error: --env TOPIC_REMAPPINGS is not supported in RoboSense; remappings are defined in the config file" >&2
        exit 1
        ;;
    IMG_ID)
        echo "Warning: ignoring --env IMG_ID=... (image is taken from <img_id> positional argument)" >&2
        ;;
    ENV_FILE)
        echo "Warning: ignoring --env ENV_FILE=... (managed internally by this script)" >&2
        ;;
    EXAMPLE)
        echo "Warning: ignoring --env EXAMPLE=... (example is taken from --example)" >&2
        ;;
    *)
        extra_env_vars+=("${env_key}=${env_val}")
        ;;
    esac
done

env_file="$(mktemp -p /tmp robosense_env_XXXXXX.env)"
trap 'rm -f "${env_file}"' EXIT

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

print_banner_text "=" "Launching RoboSense in a Docker container of image '${IMG_ID}' (example ${EXAMPLE}) in '${mode}' mode"

xhost +local:

IMG_ID="${IMG_ID}" \
    CONFIG_FILE_HOST="${CONFIG_FILE_HOST}" \
    ENV_FILE="${env_file}" \
    docker compose "${compose_files[@]}" up -d
