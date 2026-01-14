#!/usr/bin/env bash

ws="${IMAGE_MAIN_USER_WORKSPACE:-}"

# -r FILE: True if file is readable by you.
[ -n "${ws}" ] && [ -r "${ws}/install/setup.bash" ] && . "${ws}/install/setup.bash"

exec "$@"
