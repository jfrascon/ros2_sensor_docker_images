# RoboSense ROS2 in Docker

The `robosense` folder contains the files required to install the ROS2 packages for RoboSense LiDARs, together with their dependencies, in a Docker image.
The ROS2 packages are installed from source code by cloning repositories.

Official repositories:
- RoboSense ROS2 packages: [https://github.com/RoboSense-LiDAR/rslidar_sdk](https://github.com/RoboSense-LiDAR/rslidar_sdk)
- `rs_driver` core driver: [https://github.com/RoboSense-LiDAR/rs_driver](https://github.com/RoboSense-LiDAR/rs_driver)

This project currently uses maintained forks for `rslidar_sdk`, `rslidar_msg`, and `ros2_launch_helpers`, selected in [`examples/refs.txt`](examples/refs.txt).

The [`setup.sh`](setup.sh), [`compile.sh`](compile.sh), and [`sensor.launch.py`](sensor.launch.py) scripts are designed to be used from a `Dockerfile` and automate image building.

## Usage example

To illustrate how to use the files mentioned above, an example is provided in the `examples/` folder, where a `Dockerfile` is included to build an image that allows running the ROS2 packages for RoboSense LiDARs inside a Docker container.

The process is designed to be convenient for the user: run [`examples/build.py`](examples/build.py) and indicate the ROS2 distro you want to use (`humble` or `jazzy`).

Example:
```bash
cd sensors/lidars/robosense/examples
./build.py jazzy
```

The script includes optional flags that may be useful (for example, cache control, base image pull, metadata, or image name). To see them:
```bash
./build.py -h
```

In `examples/`, the file [`refs.txt`](examples/refs.txt) defines the remote references (tags/branches) cloned for:
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
- `example 1`: one front LiDAR ([`example_1.front_robosense_helios_16p_config.yaml`](examples/example_1.front_robosense_helios_16p_config.yaml))
- `example 2`: front and rear LiDARs ([`example_2.front_back_robosense_helios_16p_config.yaml`](examples/example_2.front_back_robosense_helios_16p_config.yaml))

Once the image is built with [`examples/build.py`](examples/build.py), you can start the container in two modes using [`examples/run_docker_container.sh`](examples/run_docker_container.sh):

- `automatic` mode: the container starts and automatically runs the ROS2 driver launch.
- `manual` mode: the container starts without launching the driver, so you can enter a shell and run it manually.

Scope note for these example files:
- [`run_docker_container.sh`](examples/run_docker_container.sh) and the split compose fragments ([`docker_compose_mode_automatic.yaml`](examples/docker_compose_mode_automatic.yaml), [`docker_compose_mode_manual.yaml`](examples/docker_compose_mode_manual.yaml), [`docker_compose_gui.yaml`](examples/docker_compose_gui.yaml)) are meant to help users test and experiment quickly.
- In production, the common approach is to maintain a single custom `docker compose` with the sensor configuration, startup command, and GUI settings (if needed).
- In that setup, you do not need [`run_docker_container.sh`](examples/run_docker_container.sh) nor separate `automatic/manual/gui` compose fragments.

The script only takes positional arguments:
- `<img_id>`
- `<mode>` (`automatic` or `manual`)

The RoboSense config file is selected in [`examples/docker_compose_base.yaml`](examples/docker_compose_base.yaml):
- Default (already enabled): [`example_1.front_robosense_helios_16p_config.yaml`](examples/example_1.front_robosense_helios_16p_config.yaml) (one LiDAR).
- Alternative: uncomment [`example_2.front_back_robosense_helios_16p_config.yaml`](examples/example_2.front_back_robosense_helios_16p_config.yaml) and comment the `example_1` line.

Example 1 (if you built with `./build.py jazzy`, the default `img_id` is `robosense:jazzy`):

```bash
cd sensors/lidars/robosense/examples
./run_docker_container.sh robosense:jazzy automatic
```

Example 2 in manual mode:

```bash
cd sensors/lidars/robosense/examples
# In docker_compose_base.yaml:
# - comment the example_1 volume line
# - uncomment the example_2 volume line
./run_docker_container.sh robosense:jazzy manual
docker compose exec -it robosense_srvc bash
ros2 launch rslidar_sdk sensor.launch.py
```

The GUI flow is automatic:
- If `DISPLAY` is set on the host, [`run_docker_container.sh`](examples/run_docker_container.sh) adds [`docker_compose_gui.yaml`](examples/docker_compose_gui.yaml) and runs `xhost +local:`.
- If `DISPLAY` is not set, the container is started in headless mode (no X11 mount).

Runtime variables are defined in [`examples/docker_compose_base.yaml`](examples/docker_compose_base.yaml) under `environment`.
In particular, [`sensor.launch.py`](sensor.launch.py) uses:

- `ROBOT_NAME` (required by launch)
- `CONFIG_FILE` (required by launch; set to `/tmp/config.yaml` in compose)
- `NAMESPACE` (optional)
- `NODE_OPTIONS` (optional `kvs`: `key=value,key=value,...`)
- `LOGGING_OPTIONS` (optional `kvs`: `key=value,key=value,...`)

Additional variables used in this example include:
- `ROS_DOMAIN_ID`
- `RMW_IMPLEMENTATION` (fixed as `rmw_cyclonedds_cpp`)
- `CYCLONEDDS_URI` (fixed to [`examples/cyclonedds_config.xml`](examples/cyclonedds_config.xml))

CycloneDDS configuration used in this example is defined in [`examples/cyclonedds_config.xml`](examples/cyclonedds_config.xml).

The launch flow supports config templating:
- Config files can contain `{{robot_prefix}}`.
- [`sensor.launch.py`](sensor.launch.py) renders the config with Jinja2 using `robot_prefix` derived from `ROBOT_NAME`.
- Undefined template variables fail fast (`StrictUndefined`).
- If rendering changes the content, an effective file `/tmp/robosense_config_YYYYMMDD.yaml` is generated and used.

To see all available options:

```bash
./run_docker_container.sh -h
```

For more information on sensor configuration and the driver project:
- [https://github.com/RoboSense-LiDAR/rslidar_sdk](https://github.com/RoboSense-LiDAR/rslidar_sdk)
