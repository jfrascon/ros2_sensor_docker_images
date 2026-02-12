#!/usr/bin/env bash

ws="${IMAGE_MAIN_USER_WORKSPACE:-}"

# -r FILE: True if file is readable by the current user.
# This is used to check if the ROS2 workspace setup script exists and can be sourced.
# If the file is not found or not readable, the script will skip sourcing it and continue without settingup the ROS2
# environment, which may lead to errors when trying to run ROS2 commands later on.
[ -n "${ws}" ] && [ -r "${ws}/install/setup.bash" ] && . "${ws}/install/setup.bash"

# Add ~/.local/bin to PATH if it's not already there, so that user-installed Python packages are found.
# We wrap PATH with ':' and search for ':<path>:' to match whole PATH entries only.
# Examples (user_local_bin=/home/sensor/.local/bin):
#   - Match at beginning:
#       PATH="/home/sensor/.local/bin:/usr/bin"
#       ":$PATH:" -> ":/home/sensor/.local/bin:/usr/bin:" matches "*:/home/sensor/.local/bin:*"
#   - Match in middle:
#       PATH="/usr/local/bin:/home/sensor/.local/bin:/usr/bin"
#       ":$PATH:" -> ":/usr/local/bin:/home/sensor/.local/bin:/usr/bin:" matches
#   - Match at end:
#       PATH="/usr/local/bin:/usr/bin:/home/sensor/.local/bin"
#       ":$PATH:" -> ":/usr/local/bin:/usr/bin:/home/sensor/.local/bin:" matches
#   - Non-match (partial segment only):
#       PATH="/usr/local/bin:/home/sensor/.local/bin-tools:/usr/bin"
#       ":$PATH:" does NOT match "*:/home/sensor/.local/bin:*"
user_local_bin="${HOME}/.local/bin"

if [[ ":$PATH:" != *":${user_local_bin}:"* ]]; then
  PATH="${user_local_bin}:${PATH}"
fi

exec "$@"
