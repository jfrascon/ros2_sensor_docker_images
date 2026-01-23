#!/usr/bin/env bash

# This script is aimed to launch a Docker container that contains the ROS2 driver for the IMU UMX by using a Docker
# compose file.
# If the type is 'automatic', the Docker compose file used executes the launch file 'eut_sensor.launch.py' that runs
# the driver. You can start another terminal and connect to the container to see the output topics.
# If the type is 'manual', the Docker compose file used just starts the container, and you have to manually connect
# to the container and run the script 'exec_manual_launch.sh', to launch the driver.

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
#  ./<this_script> umx:humble 1 automatic --env ROS_LOCALHOST_ONLY=1
# For ROS2 Jazzy, more options are available to configure the DDS discovery behavior:
# ROS_AUTOMATIC_DISCOVERY_RANGE: LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT
# LOCALHOST means a node will only try to discover other nodes on the same machine.
# SUBNET is the default, and for DDS based middleware it means it will discover any node reachable via multicast.
# OFF means the node won't discover any other nodes, even on the same machine.
# SYSTEM_DEFAULT means 'don't change any discovery settings'.
# ROS_STATIC_PEERS: '192.168.0.1;remote.com'
# Reference: https://docs.ros.org/en/jazzy/Tutorials/Advanced/Improved-Dynamic-Discovery.html
# Example:
#  ./<this_script> umx:jazzy 2 manual \
#    --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST --env ROS_STATIC_PEERS='192.168.0.1'

usage() {
    cat <<EOF
Usage:
  $(basename ${BASH_SOURCE[0]}) <img_id> <um_model> <mode> [--env env_var1 --env env_var2 ... --help]

Positional arguments:
  img_id        Docker image ID with the UMX ROS2 driver
  um_model      UM IMU model: 6 or 7
  mode          How to run the example: automatic or manual

Options:
  --env env_var   Environment variable to pass to the container
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
PARSED=$(getopt -o h -l env:,help -- "$@") || {
    usage
    exit 1
}

# Replace $@ with the normalized list; eval preserves quoting from getopt’s output
eval set -- "${PARSED}"

# After eval set -- ... we get:
# --env env_var_1 --env env_var_2 ... -- img_id example mode
# --env may or may not be present
# -- is the end of options marker

env_vars=() # optional

while true; do
    case "${1:-}" in
    --env)
        env_vars+=("$2")
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
UM_MODEL="${2:-}"
mode="${3:-}"

# Check positional arguments are provided.
[ -z "${IMG_ID}" ] || [ -z "${UM_MODEL}" ] || [ -z "${mode}" ] && usage

shift 3
[ "$#" -gt 0 ] && echo "Warning: unexpected extra arguments: $*"

# Check if the image '${IMG_ID}', used by the Docker compose files, exists locally.

if ! docker image inspect "${IMG_ID}" 1>/dev/null 2>&1; then
    echo "Error: Docker image '${IMG_ID}' not found. Make sure to build it before running this script" >&2
    usage
fi

# Some environment variables must be exported because the used Docker compose files relies on them.
export IMG_ID

[ "${UM_MODEL}" != "6" ] && [ "${UM_MODEL}" != "7" ] && {
    echo "Supported UM IMU models 6 and 7 only"
    usage
    exit 1
}

export UM_MODEL

compose_files=(-f "dc_base.yaml")

if [ "${mode}" == "automatic" ] || [ "${mode}" == "manual" ]; then
    compose_files+=("-f" "dc_mode_${mode}.yaml")
else
    echo "Supported modes are 'automatic' and 'manual' only" >&2
    usage
fi

# Create a temporary Docker compose file to pass the environment variables provided by the user to the container.
if [ "${#env_vars[@]}" -gt 0 ]; then
    env_vars_file="$(mktemp)"
    cat <<'EOF' >"${env_vars_file}"
services:
  um_srvc:
    environment:
EOF
    # Build a minimal override with only validated KEY=VALUE entries.
    for env_kv in "${env_vars[@]}"; do
        # If env_kv does not contain '=', or has empty key or value, skip it.

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

        # Escape single quotes for YAML single-quoted scalars.
        # env_val="abc"       -> abc (no changes) -> YAML: 'abc'
        # env_val="O'Reilly"  -> O''Reilly        -> YAML: 'O''Reilly'
        # env_val="it's fine" -> it''s fine       -> YAML: 'it''s fine'
        env_val=${env_val//\'/\'\'}
        printf "      %s: '%s'\n" "${env_key}" "${env_val}" >>"${env_vars_file}"
    done
    # Include the generated override so Compose merges it into the service.
    compose_files+=("-f" "${env_vars_file}")
fi

print_banner_text "=" "Launching the node 'um${UM_MODEL}_driver' in a Docker container of the image '${IMG_ID}' using the example file 'um${UM_MODEL}_params.yaml' in '${mode}' mode"

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
