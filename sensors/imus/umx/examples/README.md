# UMX IMU examples

## Objective

This README explains how to build and run a Docker example for the UM6/UM7 ROS 2 driver using the included parameter
files.

## File structure

- `Dockerfile`: example image that installs dependencies and compiles the driver.
- `build.py`: utility to build the Docker image.
- `exec_docker_compose.sh`: starts the container with Docker Compose in automatic or manual mode.
- `exec_launch_file.sh`: runs the driver launch file inside the container.
- `exec_manual_launch.sh`: helper to start the driver when the container is run in manual mode.
- `dc_base.yaml`: base compose file (network, volumes, common variables).
- `dc_mode_automatic.yaml`: compose file to start the driver automatically.
- `dc_mode_manual.yaml`: compose file to start the container without launching the driver.
- `um6_params.yaml`: parameter file for UM6.
- `um7_params.yaml`: parameter file for UM7.

## Prerequisites

- Docker and Docker Compose v2 available on the host.
- Permissions to run Docker (the `docker` group or sudo).
- Access to the IMU serial device on the host (for example `/dev/ttyUSB*`).
- (Optional) X11/XWayland and `xhost` if you plan to run GUI apps inside the container.

## Build the image

The image is built with `build.py`, which prepares a temporary Docker build context with the shared `base_docker_files`
scripts plus the UMX `install.sh`, `compile.sh`, `eut_sensor.launch.py`, and the patched CMakeLists files, and then
runs `docker build` using the `sensors/imus/umx/Dockerfile`.

Basic build:

```bash
python sensors/imus/umx/examples/build.py jazzy
```

Help and options:

```text
usage: build.py [-h] [-c] [-p] [--img-id IMG_ID] [--meta-title META_TITLE]
                [--meta-desc META_DESC] [--meta-authors META_AUTHORS]
                ros_distro

Script to build a Docker image to run the ROS2 driver for the UM6 and UM7 IMU sensors.

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
  --img-id IMG_ID              Built Docker image ID. Default: umx:<ros_distro>
  --meta-title META_TITLE      Image title for OCI metadata
  --meta-desc META_DESC        Image description for OCI metadata
  --meta-authors META_AUTHORS  Image authors
```

Build considerations:

- `--pull` is recommended to ensure you use the latest base Ubuntu image.
- By default the build uses `--no-cache`; add `--cache` to reuse layers.
- The build runs with `DOCKER_BUILDKIT=1` and `--network=host`.

## Run examples (UM6 or UM7)

Use `exec_docker_compose.sh` to select the UM model (6 or 7) and the run mode (automatic or manual). The script
selects the parameter file and the compose files, then starts the container.

Help and options:

```text
Usage:
  exec_docker_compose.sh <img_id> <um_model> <mode> [options]

Positional arguments:
  img_id        Docker image ID with the UMX ROS2 driver
  um_model      UM IMU model: 6 or 7
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

Quick start (UM7):

```bash
./exec_docker_compose.sh umx:jazzy 7 automatic
```

UM6:

```bash
./exec_docker_compose.sh umx:jazzy 6 automatic
```

How it works:

- UM model `6` uses `um6_params.yaml`.
- UM model `7` uses `um7_params.yaml`.
- Mode: there are two modes, `automatic` and `manual`. In `automatic`, it combines `dc_base.yaml` +
  `dc_mode_automatic.yaml`, where the command is set to run `/tmp/exec_launch_file.sh` (which launches the driver).
  In `manual`, it combines `dc_base.yaml` + `dc_mode_manual.yaml`; then you open a shell in the running container and
  execute `/tmp/exec_manual_launch.sh`. This mode is intended for testing, so you can start the driver manually and see
  node logs in your terminal.
- The container runs with `network_mode: host`, mounts `/dev`, and mounts the selected params file to `/tmp/params.yaml`.
- USB device access: `device_cgroup_rules: ["c 188:* rwm"]` grants access to ttyUSB devices. Together with the `/dev` mount, the IMU can be connected after the container is running. It is still recommended to start with the IMU connected, but if it disconnects you can plug it back in without restarting the container.
- The `sensor` user inside the image belongs to the `dialout` group to access `/dev/ttyUSB*`.

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
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml logs -f um_srvc
```

If you used `--env`, include the extra-env file:

```bash
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml -f /tmp/dc_extra_env_ABC123.yaml logs -f um_srvc
```

Note: the final `-f` in `docker compose logs -f` means "follow" (stream logs).

Example manual flow:

```bash
./exec_docker_compose.sh umx:jazzy 7 manual
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
./exec_docker_compose.sh umx:jazzy 7 automatic \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST \
  --env ROS_STATIC_PEERS='192.168.0.1'
```

Examples with ROS distro-specific discovery settings:

```bash
# ROS 2 Humble: limit discovery to localhost
./exec_docker_compose.sh umx:humble 7 automatic \
  --env ROS_LOCALHOST_ONLY=1

# ROS 2 Jazzy: limit discovery to localhost
./exec_docker_compose.sh umx:jazzy 6 automatic \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

## Middleware selection (Zenoh)

These examples are configured to use Zenoh by default. Feel free to switch the DDS middleware to the option that best
suits your setup. This is set in `dc_base.yaml` via `RMW_IMPLEMENTATION`:

```yaml
      RMW_IMPLEMENTATION: rmw_zenoh_cpp
```

## Environment variables in `dc_base.yaml`

The launch file `eut_sensor.launch.py` accepts `namespace`, `robot_name`, `um_model`, `params_file`,
`topic_remappings`, `node_options`, and `logging_options` as input arguments. In these examples, `dc_base.yaml` defines
environment variables that are then mapped to launch arguments by `exec_launch_file.sh`:

- `NAMESPACE`: optional ROS namespace prefix.
- `ROBOT_NAME`: required robot name used to build node names and frame prefixes.
- `UM_MODEL`: UM model to run (`6` or `7`). The script validates this value and exits on invalid input.
- `PARAMS_FILE`: path to the YAML params file mounted into the container. The file can use `$(var robot_prefix)` (for
  example in `frame_id`), which is derived from `ROBOT_NAME` by the launch file. If the placeholder is not present,
  no prefix substitution occurs and `exec_launch_file.sh` prints a warning.
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

## Utility scripts and typical flow

Scripts:

- `exec_docker_compose.sh`: main entry point to run UM6 or UM7 in automatic/manual mode.
- `exec_launch_file.sh`: launches the ROS 2 driver inside the container using environment variables.
- `exec_manual_launch.sh`: sources the workspace and then calls `exec_launch_file.sh` for manual runs.

Typical flow:

```text
build.py -> exec_docker_compose.sh -> (automatic) exec_launch_file.sh
                                   -> (manual) docker exec + exec_manual_launch.sh
```

## Troubleshooting

- No data/topics: verify the IMU is connected and visible as `/dev/ttyUSB*` on the host.
- Container starts but driver exits: check `ROBOT_NAME`, `UM_MODEL`, and parameter file path, then re-run in manual
  mode to see logs.
- Permission errors: ensure your user can run Docker and the container can access `/dev`.
- Container name mismatch: run `docker compose ps` to find the current container name before using `docker exec`.
- Discovery issues: verify `ROS_DOMAIN_ID` and any discovery-related environment variables you set with `--env`.

## References

- `sensors/imus/umx/README.md`
- https://github.com/ros-drivers/um7/tree/ros2
- https://docs.ros.org/en/rolling/Tutorials/Demos/Logging-and-logger-configuration.html
- https://docs.ros.org/en/rolling/Concepts/Intermediate/About-Logging.html
