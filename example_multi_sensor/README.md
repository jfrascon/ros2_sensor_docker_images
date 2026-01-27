# Multi-sensor examples (UMX IMU + Livox Gen2 LiDAR + RoboSense LiDAR)

## Objective

This README explains how to build a single Docker image that contains the UMX IMU, Livox Gen2 LiDAR, and RoboSense
LiDAR ROS 2 drivers, along with example configuration files you can reuse in your own deployments.

## File structure

- `Dockerfile`: example image that installs and compiles all three drivers.
- `build.py`: utility to build the Docker image.
- `exec_docker_compose.sh`: starts the containers with Docker Compose in automatic or manual mode.
- `exec_launch_file_umx.sh`: starts the UMX driver inside the container (mounted as `/tmp/exec_launch_file.sh`).
- `exec_launch_file_livox_gen2.sh`: starts the Livox Gen2 driver inside the container (mounted as `/tmp/exec_launch_file.sh`).
- `exec_launch_file_robosense.sh`: starts the RoboSense driver inside the container (mounted as `/tmp/exec_launch_file.sh`).
- `exec_manual_launch.sh`: helper to start the driver inside a manual container.
- `dc_base.yaml`: base compose file (network, volumes, common variables).
- `dc_mode_automatic.yaml`: compose file to start the drivers automatically.
- `dc_mode_manual.yaml`: compose file to start the containers without launching the drivers.
- `imu_params.yaml`: ROS params for the UMX IMU example.
- `livox_config.json`: Livox Gen2 JSON configuration (single sensor).
- `livox_params.yaml`: ROS params for the Livox Gen2 example.
- `robosense_config.yaml`: RoboSense YAML configuration (single sensor).

## Prerequisites

- Docker and Docker Compose v2 available on the host.
- Permissions to run Docker (the `docker` group or sudo).
- Host network connectivity to the sensors (same subnet or reachable route).

## Build the image

The image is built with `build.py`, which uses this folder as the Docker build context. The `Dockerfile` clones the
repository into `/tmp/sensor_images`, then reuses the `install.sh` and `compile.sh` scripts from each sensor package.

Basic build:

```bash
python example_multi_sensor/build.py jazzy
```

Help and options:

```text
usage: build.py [-h] [-c] [-p] [--img-id IMG_ID] [--meta-title META_TITLE]
                [--meta-desc META_DESC] [--meta-authors META_AUTHORS]
                ros_distro

Script to build a ROS2 multi-sensor Docker image (IMU UMX + Livox Gen2 LiDAR + Robosense LiDAR).

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
  --img-id IMG_ID              Built Docker image ID. Default: multi_sensor:<ros_distro>
  --meta-title META_TITLE      Image title for OCI metadata
  --meta-desc META_DESC        Image description for OCI metadata
  --meta-authors META_AUTHORS  Image authors
```

Build considerations:

- `--pull` is recommended to ensure you use the latest base Ubuntu image.
- By default the build uses `--no-cache`; add `--cache` to reuse layers.
- The build runs with `DOCKER_BUILDKIT=1` and `--network=host`.

## Run example (multi-sensor)

Use `exec_docker_compose.sh` to start the containers in automatic or manual mode. The script mounts the example
configuration files; in automatic mode it launches the three drivers.

Help and options:

```text
Usage:
  exec_docker_compose.sh <img_id> <mode> [options]

Positional arguments:
  img_id        Docker image ID with the multi-sensor ROS2 drivers
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
./exec_docker_compose.sh multi_sensor:jazzy automatic
```

How it works:

- Mode: there are two modes, `automatic` and `manual`. In `automatic`, it combines `dc_base.yaml` +
  `dc_mode_automatic.yaml`, where each service runs `/tmp/exec_launch_file.sh` (mapped per service). In `manual`, it
  combines `dc_base.yaml` + `dc_mode_manual.yaml`; then you open a shell in the running container and execute
  `/tmp/exec_manual_launch.sh`.
- The compose file defines three services: `umx_imu_srvc`, `livox_gen2_lidar_srvc`, and `robosense_lidar_srvc`.
- Each service runs with `network_mode: host` and mounts its own example config/params files into `/tmp`.
- The UMX IMU service additionally mounts `/dev` to access the serial device.
- Each service uses the same `NAMESPACE`, `ROBOT_NAME`, `NODE_OPTIONS`, `LOGGING_OPTIONS`, and `TOPIC_REMAPPINGS` naming
  scheme as its sensor-specific examples.

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
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml logs -f umx_imu_srvc
```

And if you used `--env`, include the extra-env file:

```bash
docker compose -f dc_base.yaml -f dc_mode_automatic.yaml -f /tmp/dc_extra_env_ABC123.yaml logs -f umx_imu_srvc
```

Note: the final `-f` in `docker compose logs -f` means "follow" (stream logs).

Example manual flow:

```bash
./exec_docker_compose.sh multi_sensor:jazzy manual
docker compose ps
docker exec -it <container_name> bash
/tmp/exec_manual_launch.sh
```

Repeat the `docker exec` step for each service you want to run in manual mode.

Passing extra environment variables:

Use `--env KEY=VALUE` to inject additional environment variables into all services (for example discovery-related
variables not covered by the explicit flags). When `--env` is used, the script writes a temporary extra-env file under
`/tmp` (the path is printed) so you can reuse it for commands like `docker compose logs -f`.
For per-service environment changes, edit `dc_base.yaml` or create your own Compose extra-env file.
Use `--namespace`, `--robot-name`, `--ros-domain-id`, and `--rmw-implementation` to set common values across all services
and replace the defaults defined in `dc_base.yaml`.

```bash
./exec_docker_compose.sh multi_sensor:jazzy automatic \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST \
  --env ROS_STATIC_PEERS='192.168.0.1'
```

## Environment variables in `dc_base.yaml`

Each service reads environment variables for its driver and maps them to launch arguments:

UMX IMU:

- `NAMESPACE`: optional namespace prefix.
- `ROBOT_NAME`: required robot name used to build node names and frame prefixes.
- `UM_MODEL`: required UM model (`6` or `7`). This example uses `7`.
- `PARAMS_FILE`: path to the YAML params file mounted into the container.
- `TOPIC_REMAPPINGS`: optional comma-separated remappings (`/from:=/to,/from2:=/to2`).
- `NODE_OPTIONS`: comma-separated `key=value` list passed to the launch file.
- `LOGGING_OPTIONS`: comma-separated `key=value` list passed to the launch file.

Livox Gen2:

- `NAMESPACE`: optional namespace prefix.
- `ROBOT_NAME`: required robot name used to build node names and frame prefixes.
- `CONFIG_FILE`: path to the JSON config file mounted into the container.
- `PARAMS_FILE`: path to the YAML params file mounted into the container.
- `TOPIC_REMAPPINGS`: optional comma-separated remappings (`/from:=/to,/from2:=/to2`).
- `NODE_OPTIONS`: comma-separated `key=value` list passed to the launch file.
- `LOGGING_OPTIONS`: comma-separated `key=value` list passed to the launch file.

RoboSense:

- `NAMESPACE`: optional namespace prefix.
- `ROBOT_NAME`: required robot name used to build node names and frame prefixes.
- `CONFIG_FILE`: path to the YAML config file mounted into the container.
- `NODE_OPTIONS`: comma-separated `key=value` list passed to the launch file.
- `LOGGING_OPTIONS`: comma-separated `key=value` list passed to the launch file.

Shared:

- `NAMESPACE`, `ROBOT_NAME`, `ROS_DOMAIN_ID`, `RMW_IMPLEMENTATION`: defaulted in `dc_base.yaml` and replaceable via
  `exec_docker_compose.sh` flags.
- `RCUTILS_LOGGING_BUFFERED_STREAM`: set to `0` for unbuffered console logging.
- `RCUTILS_LOGGING_USE_STDOUT`: set to `1` to send logs to stdout.
- `RCUTILS_COLORIZED_OUTPUT`: set to `1` to enable colorized output.
- `RCUTILS_CONSOLE_OUTPUT_FORMAT`: printf-style format string for console logs.
- `ROS_DOMAIN_ID`: ROS 2 domain isolation ID.
- `RMW_IMPLEMENTATION`: selected middleware implementation (Zenoh by default).

Placeholder logic in the Livox and RoboSense `exec_launch_file_*.sh` scripts:

- If the Livox JSON file contains `{{robot_prefix}}`, the script generates a new JSON with `<robot_name>_` substituted
  and updates `user_config_path` in the params file to point at it.
- If the Livox JSON does not contain `{{robot_prefix}}`, the original JSON is used and `user_config_path` is only
  updated when its current value differs from the JSON path.
- If the RoboSense config contains `{{robot_prefix}}`, the script generates a new YAML with `<robot_name>_`
  substituted; otherwise it uses the original config file.

## Utility scripts and typical flow

Scripts:

- `exec_docker_compose.sh`: main entry point to run the multi-sensor example in automatic/manual mode.
- `exec_launch_file_*.sh`: per-sensor launch scripts mounted into `/tmp/exec_launch_file.sh`.
- `exec_manual_launch.sh`: calls `/tmp/exec_launch_file.sh` in manual mode.

Typical flow:

```text
build.py -> exec_docker_compose.sh -> (automatic) /tmp/exec_launch_file.sh
                                   -> (manual) docker exec + /tmp/exec_manual_launch.sh
```

## Troubleshooting

- No data/topics: confirm the host can reach the sensor IPs and that the container uses `network_mode: host`.
- Container starts but a driver exits: check the per-sensor config/params files and the placeholder logic.
- IMU serial errors: verify `/dev/ttyUSB*` access and the `device_cgroup_rules` entry.
- Container name mismatch: run `docker compose ps` to find the current container name before using `docker exec`.

## References

- `sensors/imus/umx/examples/README.md`
- `sensors/lidars/livox_gen2/examples/README.md`
- `sensors/lidars/robosense/examples/README.md`
