# RoboSense ROS2 in Docker

The `robosense` folder contains the files required to install the ROS2 packages for RoboSense LiDARs, together with their dependencies, in a Docker image.
The ROS2 packages are installed from source code by cloning repositories.

Official repositories:
- RoboSense ROS2 packages: `https://github.com/RoboSense-LiDAR/rslidar_sdk`
- `rs_driver` core driver: `https://github.com/RoboSense-LiDAR/rs_driver`

This project currently uses maintained forks for `rslidar_sdk`, `rslidar_msg`, and `ros2_launch_helpers`, selected in `examples/refs.txt`.

The `setup.sh`, `compile.sh`, and `eut_sensor.launch.py` scripts are designed to be used from a `Dockerfile` and automate image building.

## Usage example

To illustrate how to use the files mentioned above, an example is provided in the `examples/` folder, where a `Dockerfile` is included to build an image that allows running the ROS2 packages for RoboSense LiDARs inside a Docker container.

The process is designed to be convenient for the user: run `examples/build.py` and indicate the ROS2 distro you want to use (`humble` or `jazzy`).

Example:
```bash
cd sensors/lidars/robosense/examples
./build.py jazzy
```

The script includes optional flags that may be useful (for example, cache control, base image pull, metadata, or image name). To see them:
```bash
./build.py -h
```

In `examples/`, the file `refs.txt` defines the remote references (tags/branches) cloned for:
- `rslidar_sdk`
- `rslidar_msg`
- `ros2_launch_helpers`

Expected format:
```txt
rslidar_sdk main
rslidar_msg main
ros2_launch_helpers main
```

The RoboSense example supports two configurations:
- `example 1`: one front LiDAR (`example_1.front_robosense_helios_16p_config.yaml`)
- `example 2`: front and rear LiDARs (`example_2.front_back_robosense_helios_16p_config.yaml`)

Once the image is built with `examples/build.py`, you can start the container in two modes using `examples/run_docker_container.sh`:

- `automatic` mode: the container starts and automatically runs the ROS2 driver launch.
- `manual` mode: the container starts without launching the driver, so you can enter a shell and run it manually.

Example (if you built with `./build.py jazzy`, the default `img_id` is `robosense:jazzy`):

```bash
cd sensors/lidars/robosense/examples
./run_docker_container.sh robosense:jazzy automatic --example 1
```

If you prefer manual mode:

```bash
cd sensors/lidars/robosense/examples
./run_docker_container.sh robosense:jazzy manual --example 2
docker compose exec -it robosense_srvc bash
bash /tmp/run_launch_in_terminal.sh
```

This example is also prepared to run graphical applications from the container and display them on the host through X11/XWayland.

The `run_docker_container.sh` script allows configuring variables through `--env KEY=VALUE`.

Variables with default values in this example:

- `NAMESPACE` (default: empty)
- `ROBOT_NAME` (default: `robot`)
- `ROS_DOMAIN_ID` (default: `11`)
- `NODE_OPTIONS` (default: `name=robosense_lidar_ros2_handler,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0`)
- `LOGGING_OPTIONS` (default: `log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true`)

`NODE_OPTIONS` and `LOGGING_OPTIONS` are `kvs` (key-value-string) variables, i.e., a string composed of `key=value` pairs separated by commas.

Additional variables supported by the script:

- `ROS_LOCALHOST_ONLY=1|0` (ROS2 Humble and earlier, no default value)
- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT` (ROS2 Jazzy and later, no default value)
- `ROS_STATIC_PEERS='192.168.0.1;remote.com'` (ROS2 Jazzy and later, no default value)

There are variables that cannot be configured with `--env` in this flow:

- `RMW_IMPLEMENTATION`: fixed in `examples/docker_compose_base.yaml` as `rmw_cyclonedds_cpp`.
- `CYCLONEDDS_URI`: fixed in `examples/docker_compose_base.yaml`.
- `TOPIC_REMAPPINGS`: not supported in RoboSense; remappings are defined directly in the selected config file.
- `CONFIG_FILE`: fixed in `examples/docker_compose_base.yaml`. It points to the selected config file mounted as `/tmp/config.yaml`.
- `CONFIG_FILE_HOST`: selected internally by `run_docker_container.sh` from `--example`.
- `IMG_ID`: taken from the script positional argument `<img_id>`.
- `ENV_FILE`: managed internally by the script. It is the temporary `.env` file that `docker compose` loads through `env_file` (in `examples/docker_compose_base.yaml`) to pass environment variables to the container of service `robosense_srvc`.

CycloneDDS configuration used in this example is defined in `examples/cyclonedds_config.xml`.

The launch flow keeps the current config placeholder replacement behavior:
- Config files can contain `{{robot_prefix}}`.
- in this flow, `run_docker_container.sh` mounts the selected config file as `/tmp/config.yaml` according to `--example`.
- `run_launch.sh` resolves `{{robot_prefix}}` in the config file and launches the driver using the effective config path.

Example execution with overrides:

```bash
./run_docker_container.sh robosense:jazzy automatic --example 2 \
  --env ROBOT_NAME=robot1 \
  --env ROS_DOMAIN_ID=21 \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

To see all available options:

```bash
./run_docker_container.sh -h
```

For more information on sensor configuration and the driver project:
- https://github.com/RoboSense-LiDAR/rslidar_sdk
