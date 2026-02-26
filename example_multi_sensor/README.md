# Multi-sensor Docker example (UMX + Livox Gen2 + RoboSense)

This folder provides a practical example of how to build one Docker image with ROS2 handlers and run a multi-sensor deployment with three containers:

- UMX IMU
- Livox Gen2 LiDAR
- RoboSense LiDAR

The layout is intended as a reference you can adapt, not a mandatory template.

## What this example shows

- How to build a single image that includes all sensor handlers.
- How to run one container per sensor.
- How to compose deployment modes with multiple `docker compose` files.
- How to define shared runtime values once and reuse them with YAML anchors.

## Key files and responsibilities

- [`build.py`](build.py): helper to build the Docker image.
- [`Dockerfile`](Dockerfile): main installation logic.
- [`run_docker_container.sh`](run_docker_container.sh): helper to run the example in `automatic` or `manual` mode.
- [`docker_compose_base.yaml`](docker_compose_base.yaml): base services, mounts, and common runtime environment.
- [`docker_compose_mode_automatic.yaml`](docker_compose_mode_automatic.yaml): automatic launch commands.
- [`docker_compose_mode_manual.yaml`](docker_compose_mode_manual.yaml): manual mode (`bash` in each container).
- [`docker_compose_gui.yaml`](docker_compose_gui.yaml): optional GUI fragment, added only when `DISPLAY` is available.

## Compose structure

The deployment is created by combining compose files:

- Base compose: [`docker_compose_base.yaml`](docker_compose_base.yaml)
- Mode compose: [`docker_compose_mode_automatic.yaml`](docker_compose_mode_automatic.yaml) or [`docker_compose_mode_manual.yaml`](docker_compose_mode_manual.yaml)
- Optional GUI compose: [`docker_compose_gui.yaml`](docker_compose_gui.yaml)

In this example, up to three compose files are chained (`base + mode + optional gui`) so users can experiment with different run styles.

[`run_docker_container.sh`](run_docker_container.sh) assembles these files automatically.

## Runtime variables

### Common variables in the anchor

[`docker_compose_base.yaml`](docker_compose_base.yaml) defines shared values in `x-common-environment`:

- `NAMESPACE=multisensor`
- `ROBOT_NAME=robot`
- `ROS_DOMAIN_ID=11`
- ROS2 logging variables (`RCUTILS_*`)

Edit the anchor if you want different common defaults.

### Sensor-specific variables per service

The same compose file defines sensor-specific values directly in each service:

- `umx_srvc`:
  - `UM_MODEL=7`
  - `PARAMS_FILE=/tmp/params.yaml`
- `livox_gen2_srvc`:
  - `PARAMS_FILE=/tmp/params.yaml`
- `robosense_srvc`:
  - `CONFIG_FILE=/tmp/config.yaml`

Those runtime values are coupled to the files mounted in each service (`./*.yaml`/`./*.json` -> `/tmp/...`).

Note on naming:

- `PARAMS_FILE` is used for a YAML file that follows the ROS2 parameters convention (parameters declared under `ros__parameters`).
- `CONFIG_FILE` (for example in `robosense_srvc`) is used for a sensor vendor configuration YAML that does not follow ROS2 parameter-file conventions; it is simply a YAML file in the format required by that vendor driver.

## Build and run

Build image:

```bash
python example_multi_sensor/build.py ubuntu:24.04 jazzy multi_sensor:jazzy
```

Run automatic mode:

```bash
cd example_multi_sensor
./run_docker_container.sh multi_sensor:jazzy automatic
```

Run manual mode:

```bash
./run_docker_container.sh multi_sensor:jazzy manual
```

## Manual launch inside containers

In manual mode, connect to each container and launch the sensor explicitly:

UMX:

```bash
docker compose exec -it umx_srvc bash
ros2 launch umx_bringup sensor.launch.py
```

Livox Gen2:

```bash
docker compose exec -it livox_gen2_srvc bash
ros2 launch livox_ros_driver2 sensor.launch.py
```

RoboSense:

```bash
docker compose exec -it robosense_srvc bash
ros2 launch rslidar_sdk sensor.launch.py
```

## About GUI support

If `DISPLAY` is present on the host, [`run_docker_container.sh`](run_docker_container.sh) adds [`docker_compose_gui.yaml`](docker_compose_gui.yaml) and runs:

```bash
xhost +local:
```

If `DISPLAY` is not set, the deployment runs headless.

## Production note

Note on the scope of these example files:

- [`run_docker_container.sh`](run_docker_container.sh) and the split compose files ([`docker_compose_mode_automatic.yaml`](docker_compose_mode_automatic.yaml), [`docker_compose_mode_manual.yaml`](docker_compose_mode_manual.yaml), [`docker_compose_gui.yaml`](docker_compose_gui.yaml)) are intended for testing and experimentation.
- In production, the typical approach is to define your own compose setup with your final sensor configuration, startup command, and GUI settings (if needed).
- In that case, you usually do not need [`run_docker_container.sh`](run_docker_container.sh) or a split by `automatic/manual/gui` modes.

## References

- [UMX README](../sensors/imus/umx/README.md)
- [Livox Gen2 README](../sensors/lidars/livox_gen2/README.md)
- [RoboSense README](../sensors/lidars/robosense/README.md)
