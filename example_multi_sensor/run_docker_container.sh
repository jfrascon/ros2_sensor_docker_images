#!/usr/bin/env bash

# This script launches Docker containers with ROS2 handlers for:
# - UMX IMU
# - Livox Gen2 LiDAR
# - RoboSense LiDAR
#
# If mode is 'automatic', each container executes '/tmp/run_launch.sh'.
# If mode is 'manual', containers start without launching the drivers; then you can connect and run
# '/tmp/run_launch_in_terminal.sh' manually inside each container.

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

# For ROS2-Humble, and earlier versions of ROS2, 'ROS_LOCALHOST_ONLY=1|0' can be set to limit the discovery to
# localhost only.
# Since ROS2-Jazzy, more options are available to configure the DDS discovery behaviour:
# - ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT
# - ROS_STATIC_PEERS='192.168.0.1;remote.com'
# Reference: https://docs.ros.org/en/jazzy/Tutorials/Advanced/Improved-Dynamic-Discovery.html

usage() {
    cat <<EOF2
Usage:
  $(basename "${BASH_SOURCE[0]}") [--env-file <path>] <img_id> <mode>
  $(basename "${BASH_SOURCE[0]}") [--help | -h]

Positional arguments:
  img_id        Docker image ID with the multi-sensor ROS2 handlers.
  mode          How to run the example: automatic or manual

Options:
  --env-file, -e <path>    Environment file passed to 'docker compose --env-file'
  --help, -h               Show this help and exit
EOF2
}

SHORT_OPTS="he:"
LONG_OPTS="help,env-file:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

eval set -- "${PARSED_ARGS}"

ENV_FILE=""

while true; do
    case "${1:-}" in
    -e | --env-file)
        ENV_FILE="${2:-}"
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

if [ "${mode}" != "automatic" ] && [ "${mode}" != "manual" ]; then
    echo "Supported modes are 'automatic' and 'manual' only" >&2
    usage
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "Error: 'docker' command not found. Please install Docker and ensure it is in PATH" >&2
    exit 1
fi

if ! docker image inspect "${IMG_ID}" 1>/dev/null 2>&1; then
    echo "Error: Docker image '${IMG_ID}' not found. Make sure to build it before running this script" >&2
    usage
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${ENV_FILE}" ]; then
    ENV_FILE="${SCRIPT_DIR}/deployment.env"
fi

if [ ! -f "${ENV_FILE}" ]; then
    echo "Error: Environment file '${ENV_FILE}' does not exist or is not a file" >&2
    exit 1
fi

print_banner_text "=" "Launching multi-sensor drivers in image '${IMG_ID}' in '${mode}' mode"
echo "Using environment file: ${ENV_FILE}"

# The following compose files are required:
# - docker_compose_base.yaml
# - docker_compose_mode_automatic.yaml or docker_compose_mode_manual.yaml
if [ ! -f "${SCRIPT_DIR}/docker_compose_base.yaml" ] || [ ! -f "${SCRIPT_DIR}/docker_compose_mode_${mode}.yaml" ]; then
    echo "Error: Required compose files 'docker_compose_base.yaml' and 'docker_compose_mode_${mode}.yaml' not found in '${SCRIPT_DIR}'" >&2
    exit 1
fi

# Create the array with the docker compose files to be used + the flag -f for each of them.
compose_args=(-f "${SCRIPT_DIR}/docker_compose_base.yaml" -f "${SCRIPT_DIR}/docker_compose_mode_${mode}.yaml")

# Add the GUI compose fragment only if the host exposes DISPLAY.
if [ -n "${DISPLAY:-}" ]; then
    if [ ! -f "${SCRIPT_DIR}/docker_compose_gui.yaml" ]; then
        echo "Error: GUI compose file 'docker_compose_gui.yaml' not found in '${SCRIPT_DIR}'" >&2
        exit 1
    fi

    compose_args+=(-f "${SCRIPT_DIR}/docker_compose_gui.yaml")
    xhost +local:
fi

# --project-directory makes Docker Compose resolve relative paths from SCRIPT_DIR.
# This applies to relative paths found in docker_compose_*.yaml and in values read from --env-file
# (e.g. '../file.yaml', './file.yaml' or 'file.yaml' are all resolved relative to SCRIPT_DIR).
IMG_ID="${IMG_ID}" docker compose --project-directory "${SCRIPT_DIR}" --env-file "${ENV_FILE}" "${compose_args[@]}" up -d
