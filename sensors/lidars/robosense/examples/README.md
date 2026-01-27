# RoboSense examples

## Objective

This README explains how to build and run a Docker example for the RoboSense ROS 2 driver using the included configurations for one or two sensors.

## File structure

- `Dockerfile`: example image that installs dependencies and compiles the driver.
- `build.py`: utility to build the Docker image.
- `exec_docker_compose.sh`: starts the container with Docker Compose in automatic or manual mode.
- `exec_launch_file.sh`: runs the driver launch file inside the container.
- `exec_manual_launch.sh`: helper to start the driver when the container is run in manual mode.
- `dc_base.yaml`: base compose file (network, volumes, common variables).
- `dc_mode_automatic.yaml`: compose file to start the driver automatically.
- `dc_mode_manual.yaml`: compose file to start the container without launching the driver.
- `example_1.front_robosense_helios_16p_config.yaml`: single-sensor configuration.
- `example_2.front_back_robosense_helios_16p_config.yaml`: two-sensor configuration (front/back).

## Prerequisites

- Docker and Docker Compose v2 available on the host.
- Permissions to run Docker (the `docker` group or sudo).
- Host network connectivity to the sensors (same subnet or reachable route).
- (Optional) X11/XWayland and `xhost` if you plan to run GUI apps inside the container.

## Build the image

The image is built with `build.py`, which prepares a temporary Docker build context with the shared `base_docker_files`
scripts plus the RoboSense `install.sh`, `compile.sh`, and `eut_sensor.launch.py`, and then runs `docker build` using the
`sensors/lidars/robosense/Dockerfile`.

Basic build:

```bash
python sensors/lidars/robosense/examples/build.py jazzy
```

Help and options:

```python
usage: build.py [-h] [-c] [-p] [--img-id IMG_ID] [--meta-title META_TITLE]
                [--meta-desc META_DESC] [--meta-authors META_AUTHORS]
                ros_distro

Script to build a Docker image to run the ROS2 driver for the Robosense LiDARs.

positional arguments:
  ros_distro                   Supported ROS distros: humble, jazzy

options:
  -h, --help                   Show help
  -c, --cache                  Reuse cached layers to optimize the time and resources needed to build the image.
  -p, --pull                   If no local copy of the base image exists, Docker will download it automatically from
                               the proper registry. If there is a local copy of the base image, Docker will get the
                               version available in the proper registry, and if the version from the registry is newer
                               than the local copy, it will be downloaded and used. If the local copy is the latest
                               version, it will not be downloaded again.
                               Without --pull Docker uses the local copy of the base image if it is available on the
                               system. If no local copy exists, Docker will download it automatically.
                               Usage of --pull is recommended to ensure an updated base image is used.
  --img-id IMG_ID              Built Docker image ID. Default: robosense:<ros_distro>
  --meta-title META_TITLE      Image title for OCI metadata
  --meta-desc META_DESC        Image description for OCI metadata
  --meta-authors META_AUTHORS  Image authors
```

Build considerations:

- `--pull` is recommended to ensure you use the latest base Ubuntu image.
- By default the build uses `--no-cache`; add `--cache` to reuse layers.
- The build runs with `DOCKER_BUILDKIT=1` and `--network=host`.

## Run examples (1 or 2 sensors)

Use `exec_docker_compose.sh` to select the example (1 or 2) and the run mode (automatic or manual). The script selects
the config file and the compose files, then starts the container.

Help and options:

```text
Usage:
  exec_docker_compose.sh <img_id> <#example> <mode> [options]

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
```

You can also run `./exec_docker_compose.sh -h` or `./exec_docker_compose.sh --help` to see usage.

Quick start:

```bash
./exec_docker_compose.sh robosense:jazzy 1 automatic
```

Two sensors:

```bash
./exec_docker_compose.sh robosense:jazzy 2 automatic
```

How it works:

- Example `1` uses `example_1.front_robosense_helios_16p_config.yaml`.
- Example `2` uses `example_2.front_back_robosense_helios_16p_config.yaml`.
- Mode: there are two modes, `automatic` and `manual`. In `automatic`, it combines `dc_base.yaml` + `dc_mode_automatic.yaml`, where the command is set to run `/tmp/exec_launch_file.sh` (which launches the driver). In `manual`, it combines `dc_base.yaml` + `dc_mode_manual.yaml`; then you open a shell in the running container and execute `/tmp/exec_manual_launch.sh`. This mode is intended for testing, so you can start the driver manually and see node logs in your terminal.
- The container runs with `network_mode: host` and mounts the selected config file (`example_1.front_...` or `example_2.front_back_...`) to `/tmp/config.yaml`.

Automatic mode logs:

Run these commands in another host terminal. If you did not use `--env`, follow all driver output with:

```bash
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml logs -f
```

If you used `--env`, the script prints the extra-env file path (for example `/tmp/dc_extra_env_ABC123.yaml`). Include it
so Compose reads the same configuration:

```bash
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml -f /tmp/dc_extra_env_ABC123.yaml logs -f
```

To scope logs to a single service, append the service name:

```bash
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml logs -f robosense_lidar_srvc
```

If you used `--env`, include the extra-env file:

```bash
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml -f /tmp/dc_extra_env_ABC123.yaml logs -f robosense_lidar_srvc
```

Note: the final `-f` in `docker compose logs -f` means "follow" (stream logs).

Example manual flow:

```bash
./exec_docker_compose.sh robosense:jazzy 1 manual
docker compose ps
docker exec -it <container_name> bash
/tmp/exec_manual_launch.sh
```

Passing extra environment variables:

Use `--env KEY=VALUE` to inject additional environment variables not covered by the explicit flags.
For persistent changes, edit `dc_base.yaml` or create your own Compose extra-env file.
Use `--namespace`, `--robot-name`, `--ros-domain-id`, and `--rmw-implementation` to set common values and replace the
defaults in `dc_base.yaml`.
When `--env` is used, the script writes a temporary extra-env file under `/tmp` (the path is printed) so you can reuse
it for commands like `docker compose logs -f`.

```bash
./exec_docker_compose.sh robosense:jazzy 1 automatic \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST \
  --env ROS_STATIC_PEERS='192.168.0.1'
```

Examples with ROS distro-specific discovery settings:

```bash
# ROS 2 Humble: limit discovery to localhost
./exec_docker_compose.sh robosense:humble 1 automatic \
  --env ROS_LOCALHOST_ONLY=1

# ROS 2 Jazzy: limit discovery to localhost
./exec_docker_compose.sh robosense:jazzy 2 automatic \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

## Middleware selection (Zenoh)

These examples are configured to use Zenoh by default. Feel free to switch the DDS middleware to the option that best suits your setup. This is set in `dc_base.yaml` via `RMW_IMPLEMENTATION`:

```yaml
      RMW_IMPLEMENTATION: rmw_zenoh_cpp
```

## Environment variables in `dc_base.yaml`

The launch file `eut_sensor.launch.py` accepts `namespace`, `robot_name`, `config_file`, `node_options`, and
`logging_options` as input arguments. In these examples, `dc_base.yaml` defines environment variables that are then
mapped to launch arguments by `exec_launch_file.sh`:

- `NAMESPACE`: optional ROS namespace prefix.
- `ROBOT_NAME`: required robot name used to build node names and frame prefixes.
- `CONFIG_FILE`: path to the YAML config for the LiDAR(s) mounted into the container.
- `NODE_OPTIONS`: comma-separated `key=value` list passed to the launch file. In this example it uses
  `name`, `output`, `emulate_tty`, `respawn`, and `respawn_delay`.
- `LOGGING_OPTIONS`: comma-separated `key=value` list passed to the launch file. In this example it uses
  `log-level`, `disable-stdout-logs`, `disable-rosout-logs`, and `disable-external-lib-logs`.
- `RCUTILS_LOGGING_BUFFERED_STREAM`: set to `0` for unbuffered console logging.
- `RCUTILS_LOGGING_USE_STDOUT`: set to `1` to send logs to stdout.
- `RCUTILS_COLORIZED_OUTPUT`: set to `1` to enable colorized output.
- `RCUTILS_CONSOLE_OUTPUT_FORMAT`: printf-style format string for console logs (see advanced logging references below).
- `ROS_DOMAIN_ID`: ROS 2 domain isolation ID.
- `RMW_IMPLEMENTATION`: selected middleware implementation (Zenoh by default).

If the config file contains `{{robot_prefix}}`, `exec_launch_file.sh` replaces it with `<robot_name>_` and passes the
generated file to the launch. If the placeholder is not present, the original config file is used as-is.

## Utility scripts and typical flow

Scripts:

- `exec_docker_compose.sh`: main entry point to run example 1 or 2 in automatic/manual mode.
- `exec_launch_file.sh`: launches the ROS 2 driver inside the container using environment variables.
- `exec_manual_launch.sh`: sources the workspace and then calls `exec_launch_file.sh` for manual runs.

Typical flow:

```text
build.py -> exec_docker_compose.sh -> (automatic) exec_launch_file.sh
                                   -> (manual) docker exec + exec_manual_launch.sh
```

## Troubleshooting

- No data/topics: confirm the host can reach the sensor IPs and that the container uses `network_mode: host`.
- Container starts but driver exits: check `ROBOT_NAME` and config file placeholders, then re-run in manual mode to see logs.
- Permission errors: ensure your user can run Docker and that `xhost +local:` is set if using GUI tools.
- Container name mismatch: run `docker compose ps` to find the current container name before using `docker exec`.
- Discovery issues: verify `ROS_DOMAIN_ID` and any discovery-related environment variables you set with `--env`.

## References

- `sensors/lidars/robosense/README.md`
- https://github.com/RoboSense-LiDAR/rslidar_sdk
- https://docs.ros.org/en/rolling/Tutorials/Demos/Logging-and-logger-configuration.html
- https://docs.ros.org/en/rolling/Concepts/Intermediate/About-Logging.html
