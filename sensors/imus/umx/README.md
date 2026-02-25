# UMX ROS2 in Docker

The `umx` folder contains the files required to install the ROS2 packages for CH Robotics UM6/UM7 IMUs, together with their dependencies, in a Docker image.
Both the ROS2 packages and the serial dependency are installed from source code by cloning their official repositories.

Official repositories:
- UM7/UM6 ROS2 packages: `https://github.com/ros-drivers/um7/tree/ros2`
- serial-ros2 library: `https://github.com/RoverRobotics-forks/serial-ros2`

The `setup.sh`, `compile.sh`, and `sensor.launch.py` scripts are designed to be used from a `Dockerfile` and automate image building.

## Usage example

To illustrate how to use the files mentioned above, an example is provided in the `examples/` folder, where a `Dockerfile` is included to build an image that allows running the ROS2 packages for UM6/UM7 IMUs inside a Docker container.

The process is designed to be convenient for the user: run `examples/build.py` and indicate the ROS2 distro you want to use (`humble` or `jazzy`).

Example:
```bash
cd sensors/imus/umx/examples
./build.py jazzy
```

The script includes optional flags that may be useful (for example, cache control, base image pull, metadata, or image name). To see them:
```bash
./build.py -h
```

In `examples/`, the file `refs.txt` defines the remote references (tags/branches) cloned for:
- `serial-ros2`
- `um7`
- `ros2_launch_helpers`

Expected format:
```txt
serial-ros2 master
um7 ros2
ros2_launch_helpers main
```

Once the image is built with `examples/build.py`, you can start the container in two modes using `examples/run_docker_container.sh`:

- `automatic` mode: the container starts and automatically runs the ROS2 driver launch.
- `manual` mode: the container starts without launching the driver, so you can enter a shell and run it manually.

Scope note for these example files:
- `run_docker_container.sh` and the split compose fragments (`docker_compose_mode_automatic.yaml`, `docker_compose_mode_manual.yaml`, `docker_compose_gui.yaml`) are meant to help users test and experiment quickly.
- In production, the common approach is to maintain a single custom `docker compose` with the sensor configuration, startup command, and GUI settings (if needed).
- In that setup, you do not need `run_docker_container.sh` nor separate `automatic/manual/gui` compose fragments.

The script only takes positional arguments:
- `<img_id>`
- `<mode>` (`automatic` or `manual`)

UMX params are selected in `examples/docker_compose_base.yaml`:
- Default (already enabled): `um7_params.yaml`.
- Alternative: uncomment `um6_params.yaml` and comment the `um7` line.

Example (if you built with `./build.py jazzy`, the default `img_id` is `umx:jazzy`):

```bash
cd sensors/imus/umx/examples
./run_docker_container.sh umx:jazzy automatic
```

If you prefer manual mode (UM6 as example):

```bash
cd sensors/imus/umx/examples
# In docker_compose_base.yaml:
# - comment the um7_params volume line
# - uncomment the um6_params volume line
# - set UM_MODEL to \"6\"
# - adjust TOPIC_REMAPPINGS to use um6/... topics
./run_docker_container.sh umx:jazzy manual
docker compose exec -it umx_srvc bash
ros2 launch umx_bringup sensor.launch.py
```

The GUI flow is automatic:
- If `DISPLAY` is set on the host, `run_docker_container.sh` adds `docker_compose_gui.yaml` and runs `xhost +local:`.
- If `DISPLAY` is not set, the container is started in headless mode (no X11 mount).

Runtime variables are defined in `examples/docker_compose_base.yaml` under `environment`.
In particular, `sensor.launch.py` uses:
- `ROBOT_NAME` (required by launch)
- `PARAMS_FILE` (required by launch; set to `/tmp/params.yaml` in compose)
- `NAMESPACE` (optional)
- `UM_MODEL` (optional, default `7`, allowed values: `6` or `7`)
- `TOPIC_REMAPPINGS` (optional remapping string `OLD:=NEW,OLD:=NEW,...`)
- `NODE_OPTIONS` (optional `kvs`: `key=value,key=value,...`)
- `LOGGING_OPTIONS` (optional `kvs`: `key=value,key=value,...`)

Additional variables used in this example include:
- `ROS_DOMAIN_ID`
- `RMW_IMPLEMENTATION` (fixed as `rmw_cyclonedds_cpp`)
- `CYCLONEDDS_URI` (fixed to `examples/cyclonedds_config.xml`)

CycloneDDS configuration used in this example is defined in `examples/cyclonedds_config.xml`.

UM model parameter configuration is defined in:
- `examples/um6_params.yaml`
- `examples/um7_params.yaml`

To see all available options:

```bash
./run_docker_container.sh -h
```

For more information on sensor configuration and the driver project:
- https://github.com/ros-drivers/um7/tree/ros2
- https://github.com/RoverRobotics-forks/serial-ros2
