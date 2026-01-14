#!/usr/bin/env bash

# This script is aimed to launch an execution example of a Livox LiDAR generation 2 (HAP, MID360) inside a docker
# container by executing a docker compose file.
# To validate it is working, you have several options:
# 1. Open shell inside the container and run 'ros2 topic list' to see if the topics are being published. Use also
#    'ros2 topic echo <topic_name>' to see the data being published.
# 2. Since the container where the LiDAR binary runs does not have GUI support you can't use 'rviz2' to visualize the
#    data. You can use another container that you may have at hand that has GUI support, so you can run 'rviz2' there
#    and visualize the data.
#    Remember to use the same DDS middleware and ROS_DOMAIN_ID in both containers so they can communicate.

check_compose_service() {
    local service="${1:?SERVICE required}"
    local docker_compose_file="${2:?COMPOSE_FILE required}"

    [ ! -f "${docker_compose_file}" ] && echo "Compose file '${docker_compose_file}' not found" >&2 && return 1

    local ids

    ids="$(docker compose -f "${docker_compose_file}" ps -q "${service}")"

    [ -z "${ids}" ] && echo "No container for service '${service}'" >&2 && return 1

    local bad=0

    while read -r state health; do
        if [ "${state}" != "running" ] || { [ -n "${health}" ] && [ "${health}" != "healthy" ]; }; then
            bad=1
            break
        fi
    done < <(docker inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' ${ids})

    if [ "${bad}" -eq 0 ]; then
        echo "Service '${service}' running and healthy"
        return 0
    else
        echo "Service '${service}' not running or not healthy" >&2
        return 1
    fi
}

print_repeats() {
    local -r char="${1}" count="${2}"
    local i
    for ((i = 1; i <= count; i++)); do echo -n "${char}"; done
    echo
}

print_banner_text() {
    # $1: Banner char
    # $2: Text
    local banner_char="${1}"
    local -r text="${2}"
    local pad="${banner_char}${banner_char}"
    print_repeats "${banner_char}" $((${#text} + 6))
    echo "${pad} ${text} ${pad}"
    print_repeats "${banner_char}" $((${#text} + 6))
}

usage() {
    echo "Usage: ${script_name} <#example> <ros_distro>" >&2
    exit 1
}

script="${BASH_SOURCE:-${0}}"
script_name="$(basename "${script}")"

example="${1}"
ros_distro="${2}"

[ -z "${example}" ] && echo "Error: Example number not provided" >&2 && usage
[ -z "${ros_distro}" ] && echo "Error: ROS distro not specified" >&2 && usage

if [ "${example}" = "1" ]; then
    compose_file="example_1.front_livox_mid360_docker_compose_${ros_distro}.yaml"
elif [ "${example}" = "2" ]; then
    compose_file="example_2.front_back_livox_mid360_docker_compose_${ros_distro}.yaml"
else
    echo "Invalid example number. Please provide 1 or 2."
    exit 1
fi

# Check if the image 'livox_gen2:${ros_distro}' is present locally in the host.

if ! docker image inspect livox_gen2:${ros_distro} 1>/dev/null 2>&1; then
    echo "Error: Docker image 'livox_gen2:${ros_distro}' not found. Make sure to build it before running this script"
    exit 1
fi

print_banner_text "=" "Launching example ${example} with ROS distro ${ros_distro}"

docker compose -f "${compose_file}" up -d

# Check if the service is running and healthy.
check_compose_service livox_gen2_srvc "${compose_file}"

cat <<'EOF'
If you want to see the topics being published, you can open a shell inside the container and run 'ros2 topic list'.
If you want to use the rviz2 tool to visualize the data, you can use another container that has GUI support, and run
'rviz2' there.
Remember to use the same DDS middleware, ROS_DOMAIN_ID and possible other DDS-related variables in both containers so
they can communicate.
EOF
