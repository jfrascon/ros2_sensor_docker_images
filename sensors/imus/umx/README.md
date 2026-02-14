# UMX ROS2 in Docker

The `umx` folder contains the files required to install the ROS2 packages for CH Robotics UM6/UM7 IMUs, together with their dependencies, in a Docker image.
Both the ROS2 packages and the serial dependency are installed from source code by cloning their official repositories.

Official repositories:
- UM7/UM6 ROS2 packages: `https://github.com/ros-drivers/um7/tree/ros2`
- serial-ros2 library: `https://github.com/RoverRobotics-forks/serial-ros2`

The `setup.sh`, `compile.sh`, and `eut_sensor.launch.py` scripts are designed to be used from a `Dockerfile` and automate image building.

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

Example (if you built with `./build.py jazzy`, the default `img_id` is `umx:jazzy`):

```bash
cd sensors/imus/umx/examples
./run_docker_container.sh umx:jazzy automatic --um-model 7
```

If you prefer manual mode:

```bash
cd sensors/imus/umx/examples
./run_docker_container.sh umx:jazzy manual --um-model 7
docker compose exec -it um_srvc bash
bash /tmp/run_launch_in_terminal.sh
```

This example is also prepared to run graphical applications from the container and display them on the host through X11/XWayland.

The `run_docker_container.sh` script allows configuring variables through `--env KEY=VALUE`.

Variables with default values in this example:

- `NAMESPACE` (default: empty)
- `ROBOT_NAME` (default: `robot`)
- `ROS_DOMAIN_ID` (default: `11`)
- `NODE_OPTIONS` (default: `name=umx,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0`)
- `LOGGING_OPTIONS` (default: `log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true`)

`NODE_OPTIONS` and `LOGGING_OPTIONS` are `kvs` (key-value-string) variables, i.e., a string composed of `key=value` pairs separated by commas.

Additional variables supported by the script:

- `TOPIC_REMAPPINGS`: remapping string in `OLD:=NEW` format, with comma-separated pairs.
- `ROS_LOCALHOST_ONLY=1|0` (ROS2 Humble and earlier, no default value)
- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT` (ROS2 Jazzy and later, no default value)
- `ROS_STATIC_PEERS='192.168.0.1;remote.com'` (ROS2 Jazzy and later, no default value)

In this example, if you do not use `TOPIC_REMAPPINGS`, topic names include the node name. For clearer topic hierarchies, use a node name that represents the physical device (for example `front_imu`, `rear_imu`) instead of implementation-oriented suffixes.

There are variables that cannot be configured with `--env` in this flow:

- `RMW_IMPLEMENTATION`: fixed in `examples/docker_compose_base.yaml` as `rmw_cyclonedds_cpp`.
- `CYCLONEDDS_URI`: fixed in `examples/docker_compose_base.yaml`.
- `PARAMS_FILE`: selected from `--um-model` and fixed in `examples/docker_compose_base.yaml` as `/tmp/params.yaml`.
- `IMG_ID`: taken from the script positional argument `<img_id>`.
- `ENV_FILE`: managed internally by the script. It is the temporary `.env` file that `docker compose` loads through `env_file` (in `examples/docker_compose_base.yaml`) to pass environment variables to the container of service `um_srvc`.

CycloneDDS configuration used in this example is defined in `examples/cyclonedds_config.xml`.

UM model parameter configuration is defined in:
- `examples/um6_params.yaml`
- `examples/um7_params.yaml`

Example execution with overrides:

```bash
./run_docker_container.sh umx:jazzy automatic --um-model 6 \
  --env ROBOT_NAME=imu_front \
  --env ROS_DOMAIN_ID=21 \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

To see all available options:

```bash
./run_docker_container.sh -h
```

For more information on sensor configuration and the driver project:
- https://github.com/ros-drivers/um7/tree/ros2
- https://github.com/RoverRobotics-forks/serial-ros2
