# Livox Gen2 examples

## Objective

This README explains how to build and run a Docker example for the Livox Gen2 ROS 2 driver using the included
configuration and parameter files for one or two sensors.

## File structure

- `Dockerfile`: example image that installs dependencies and compiles the driver.
- `build.py`: utility to build the Docker image.
- `exec_docker_compose.sh`: starts the container with Docker Compose in automatic or manual mode.
- `exec_launch_file.sh`: runs the driver launch file inside the container.
- `exec_manual_launch.sh`: helper to start the driver when the container is run in manual mode.
- `dc_base.yaml`: base compose file (network, volumes, common variables).
- `dc_mode_automatic.yaml`: compose file to start the driver automatically.
- `dc_mode_manual.yaml`: compose file to start the container without launching the driver.
- `example_1.front_livox_mid360.json`: configuration for one sensor.
- `example_1.front_livox_mid360.yaml`: ROS parameters for one sensor.
- `example_2.front_back_livox_mid360.json`: configuration for two sensors (front/back).
- `example_2.front_back_livox_mid360.yaml`: ROS parameters for two sensors (front/back).

## Prerequisites

- Docker and Docker Compose v2 available on the host.
- Permissions to run Docker (the `docker` group or sudo).
- Host network connectivity to the sensors (same subnet or reachable route).
- (Optional) X11/XWayland and `xhost` if you plan to run GUI apps inside the container.

## Build the image

The image is built with `build.py`, which prepares a temporary Docker build context with the shared `base_docker_files`
scripts plus the Livox Gen2 `install.sh`, `compile.sh`, and `eut_sensor.launch.py`, and then runs `docker build` using
`sensors/lidars/livox_gen2/Dockerfile`.

Basic build:

```bash
python sensors/lidars/livox_gen2/examples/build.py jazzy
```

Help and options:

```text
usage: build.py [-h] [-c] [-p] [--img-id IMG_ID] [--meta-title META_TITLE]
                [--meta-desc META_DESC] [--meta-authors META_AUTHORS]
                ros_distro

Script to build a Docker image to run the ROS2 driver for the Livox 2nd Gen LiDARs.

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
  --img-id IMG_ID              Built Docker image ID. Default: livox_gen2_lidar:<ros_distro>
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
both the JSON config and the YAML params file, then starts the container.

Help and options:

```text
Usage:
  exec_docker_compose.sh <img_id> <#example> <mode> [options]

Positional arguments:
  img_id        Docker image ID with the Livox Gen2 ROS2 driver
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
./exec_docker_compose.sh livox_gen2_lidar:jazzy 1 automatic
```

Two sensors:

```bash
./exec_docker_compose.sh livox_gen2_lidar:jazzy 2 automatic
```

How it works:

- Example `1` uses `example_1.front_livox_mid360.json` and `example_1.front_livox_mid360.yaml`.
- Example `2` uses `example_2.front_back_livox_mid360.json` and `example_2.front_back_livox_mid360.yaml`.
- Mode: there are two modes, `automatic` and `manual`. In `automatic`, it combines `dc_base.yaml` +
  `dc_mode_automatic.yaml`, where the command is set to run `/tmp/exec_launch_file.sh` (which launches the driver).
  In `manual`, it combines `dc_base.yaml` + `dc_mode_manual.yaml`; then you open a shell in the running container and
  execute `/tmp/exec_manual_launch.sh`. This mode is intended for testing, so you can start the driver manually and see
  node logs in your terminal.
- The container runs with `network_mode: host`, mounts the selected JSON/YAML files to `/tmp/config.json` and
  `/tmp/params.yaml`, and mounts `eut_sensor.launch.py` into the driver workspace.

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
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml logs -f livox_gen2_lidar_srvc
```

If you used `--env`, include the extra-env file:

```bash
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml -f /tmp/dc_extra_env_ABC123.yaml logs -f livox_gen2_lidar_srvc
```

Note: the final `-f` in `docker compose logs -f` means "follow" (stream logs).

Example manual flow:

```bash
./exec_docker_compose.sh livox_gen2_lidar:jazzy 1 manual
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
./exec_docker_compose.sh livox_gen2_lidar:jazzy 1 automatic \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST \
  --env ROS_STATIC_PEERS='192.168.0.1'
```

Examples with ROS distro-specific discovery settings:

```bash
# ROS 2 Humble: limit discovery to localhost
./exec_docker_compose.sh livox_gen2_lidar:humble 1 automatic \
  --env ROS_LOCALHOST_ONLY=1

# ROS 2 Jazzy: limit discovery to localhost
./exec_docker_compose.sh livox_gen2_lidar:jazzy 2 automatic \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

## Middleware selection (Zenoh)

These examples are configured to use Zenoh by default. Feel free to switch the DDS middleware to the option that best
suits your setup. This is set in `dc_base.yaml` via `RMW_IMPLEMENTATION`:

```yaml
      RMW_IMPLEMENTATION: rmw_zenoh_cpp
```

## Environment variables in `dc_base.yaml`

The launch file `eut_sensor.launch.py` accepts `namespace`, `robot_name`, `params_file`, `topic_remappings`,
`node_options`, and `logging_options` as input arguments. In these examples, `dc_base.yaml` defines environment
variables that are then mapped to launch arguments by `exec_launch_file.sh`:

- `NAMESPACE`: optional ROS namespace prefix.
- `ROBOT_NAME`: required robot name used to build node names and frame prefixes.
- `CONFIG_FILE`: path to the JSON config file mounted into the container.
- `PARAMS_FILE`: path to the YAML params file mounted into the container.
- `TOPIC_REMAPPINGS`: optional comma-separated remappings (`/from:=/to,/from2:=/to2`).
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

Placeholder logic in `exec_launch_file.sh`:

- `PARAMS_FILE` must declare the `user_config_path` key. If it does not, the script exits with an error.
- If the JSON file referenced by `CONFIG_FILE` contains `{{robot_prefix}}`, the script generates a new JSON with
  `<robot_name>_` substituted and always writes a temporary params file that sets `user_config_path` to that generated
  JSON, regardless of its previous value.
- If the JSON file referenced by `CONFIG_FILE` does not contain `{{robot_prefix}}`, the original JSON path is used. The
  script updates
  `user_config_path` only when the current value does not match the JSON path.

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
- Container starts but driver exits: check `ROBOT_NAME`, config/params file paths, and substitution logic, then re-run in
  manual mode to see logs.
- Permission errors: ensure your user can run Docker and that `xhost +local:` is set if using GUI tools.
- Container name mismatch: run `docker compose ps` to find the current container name before using `docker exec`.
- Discovery issues: verify `ROS_DOMAIN_ID` and any discovery-related environment variables you set with `--env`.

## References

- `sensors/lidars/livox_gen2/README.md`
- https://github.com/Livox-SDK/livox_ros_driver2
- https://docs.ros.org/en/rolling/Tutorials/Demos/Logging-and-logger-configuration.html
- https://docs.ros.org/en/rolling/Concepts/Intermediate/About-Logging.html
