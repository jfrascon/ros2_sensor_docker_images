#!/usr/bin/env bash

# Reference: https://github.com/realsenseai/realsense-ros?tab=readme-ov-file#option-3-build-from-source

# udev rules must be installed on the host system, not inside containers.
bash install_udev_rules_in_host.sh
