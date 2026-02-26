# Livox Gen2 ROS2 in Docker

The `livox_gen2` folder contains the files required to install the ROS2 packages for Livox second-generation LiDARs (HAP and Mid-360), together with their dependencies, in a Docker image.
Both the ROS2 packages and the Livox SDK dependency are installed from source code by cloning their repositories.

Official repositories:
- Livox ROS2 packages: [https://github.com/Livox-SDK/livox_ros_driver2](https://github.com/Livox-SDK/livox_ros_driver2)
- Livox SDK2: [https://github.com/Livox-SDK/Livox-SDK2](https://github.com/Livox-SDK/Livox-SDK2)

This project currently uses maintained forks for `livox_ros_driver2`, `livox_sdk2`, and `ros2_launch_helpers`, selected in [`examples/refs.txt`](examples/refs.txt).

The [`setup.sh`](setup.sh), [`compile.sh`](compile.sh), and [`sensor.launch.py`](sensor.launch.py) scripts are designed to be used from a `Dockerfile` and automate image building.

## Usage example

To illustrate how to use the files mentioned above, an example is provided in the `examples/` folder, where a `Dockerfile` is included to build an image that allows running the ROS2 packages for Livox Gen2 LiDARs inside a Docker container.

The process is designed to be convenient for the user: run [`examples/build.py`](examples/build.py) and indicate the ROS2 distro you want to use (`humble` or `jazzy`).

Example:
```bash
cd sensors/lidars/livox_gen2/examples
./build.py jazzy
```

The script includes optional flags that may be useful (for example, cache control, base image pull, metadata, or image name). To see them:
```bash
./build.py -h
```

In `examples/`, the file [`refs.txt`](examples/refs.txt) defines the remote references (tags/branches) cloned for:
- `livox_sdk2`
- `livox_ros_driver2`
- `ros2_launch_helpers`

Expected format:
```txt
livox_sdk2 main
livox_ros_driver2 main
ros2_launch_helpers main
```

The Livox example supports two configurations:
- `example 1`: one front LiDAR ([`example_1.front_livox_mid360.json`](examples/example_1.front_livox_mid360.json) + [`example_1.front_livox_mid360.yaml`](examples/example_1.front_livox_mid360.yaml))
- `example 2`: front and rear LiDARs ([`example_2.front_back_livox_mid360.json`](examples/example_2.front_back_livox_mid360.json) + [`example_2.front_back_livox_mid360.yaml`](examples/example_2.front_back_livox_mid360.yaml))

Important JSON note:
- Files used by the driver (`example_*.json`, or any file pointed by `user_config_path`) must be strict JSON.
- Do not include `//` comments in those files. The parser from the `livox_ros_driver2` source code (manufacturer driver) will fail and can report `parse lidar type failed.`
- This repository provides commented templates to explain the purpose of each field:
  - [`examples/template_user_config_1_lidar.json`](examples/template_user_config_1_lidar.json) (one LiDAR)
  - [`examples/template_user_config_2_lidars.json`](examples/template_user_config_2_lidars.json) (two LiDARs)
- Use those templates as guidance to create your project-specific JSON configs, but pass comment-free JSON files to the driver at runtime.

Once the image is built with [`examples/build.py`](examples/build.py), you can start the container in two modes using [`examples/run_docker_container.sh`](examples/run_docker_container.sh):

- `automatic` mode: the container starts and automatically runs the ROS2 driver launch.
- `manual` mode: the container starts without launching the driver, so you can enter a shell and run it manually.

Note on the scope of these example files:
- [`run_docker_container.sh`](examples/run_docker_container.sh) and the compose fragments ([`docker_compose_mode_automatic.yaml`](examples/docker_compose_mode_automatic.yaml), [`docker_compose_mode_manual.yaml`](examples/docker_compose_mode_manual.yaml), [`docker_compose_gui.yaml`](examples/docker_compose_gui.yaml)) are intended for testing and experimentation.
- In production, the typical approach is to define your own single `docker compose` file with your sensor configuration, startup command, and GUI setup (if needed).
- In that case you do not need [`run_docker_container.sh`](examples/run_docker_container.sh) or split compose files by `automatic/manual/gui` mode.

The script only receives positional arguments:
- `<img_id>`
- `<mode>` (`automatic` or `manual`)

Configuration files are selected in [`examples/docker_compose_base.yaml`](examples/docker_compose_base.yaml):
- Default (already active): [`example_1.front_livox_mid360.json`](examples/example_1.front_livox_mid360.json) + [`example_1.front_livox_mid360.yaml`](examples/example_1.front_livox_mid360.yaml).
- Alternative: uncomment [`example_2.front_back_livox_mid360.json`](examples/example_2.front_back_livox_mid360.json) + [`example_2.front_back_livox_mid360.yaml`](examples/example_2.front_back_livox_mid360.yaml) and comment out the `example_1` lines.

Example 1 (if you built with `./build.py jazzy`, the default `img_id` is `livox_gen2:jazzy`):

```bash
cd sensors/lidars/livox_gen2/examples
./run_docker_container.sh livox_gen2:jazzy automatic
```

Example 2 in manual mode:

```bash
cd sensors/lidars/livox_gen2/examples
# In docker_compose_base.yaml:
# - comment out example_1 volume lines
# - uncomment example_2 volume lines
./run_docker_container.sh livox_gen2:jazzy manual
docker compose exec -it livox_gen2_srvc bash
ros2 launch livox_ros_driver2 sensor.launch.py
```

GUI flow is automatic:
- If `DISPLAY` is defined on the host, [`run_docker_container.sh`](examples/run_docker_container.sh) adds [`docker_compose_gui.yaml`](examples/docker_compose_gui.yaml) and runs `xhost +local:`.
- If `DISPLAY` is not defined, the container starts headless (without X11 mount).

Runtime environment variables are defined in [`examples/docker_compose_base.yaml`](examples/docker_compose_base.yaml), under `environment`.
In particular, [`sensor.launch.py`](sensor.launch.py) uses:

- `ROBOT_NAME` (required by launch)
- `PARAMS_FILE` (required by launch; fixed to `/tmp/params.yaml` in compose)
- `NAMESPACE` (optional)
- `TOPIC_REMAPPINGS` (optional, remapping string `OLD:=NEW,OLD:=NEW,...`)
- `NODE_OPTIONS` (optional, `kvs` format: `key=value,key=value,...`)
- `LOGGING_OPTIONS` (optional, `kvs` format: `key=value,key=value,...`)

Other variables used in this example:
- `ROS_DOMAIN_ID`
- `RMW_IMPLEMENTATION` (fixed to `rmw_cyclonedds_cpp`)
- `CYCLONEDDS_URI` (fixed to [`examples/cyclonedds_config.xml`](examples/cyclonedds_config.xml))

CycloneDDS configuration used in this example is defined in [`examples/cyclonedds_config.xml`](examples/cyclonedds_config.xml).

The launch flow supports templates in the user JSON:
- [`sensor.launch.py`](sensor.launch.py) reads `PARAMS_FILE`, extracts `user_config_path`, and renders that JSON with Jinja2 using `robot_prefix` (derived from `ROBOT_NAME`).
- Undefined Jinja2 variables fail fast (`StrictUndefined`).
- If rendering does not change content, the original `PARAMS_FILE` is used.
- If rendering changes content, launch generates and uses:
  - `/tmp/livox_config_YYYYMMDD.json`
  - `/tmp/livox_params_YYYYMMDD.yaml`

To see all available options:

```bash
./run_docker_container.sh -h
```

For more information on sensor configuration and the driver project:
- [https://github.com/Livox-SDK/livox_ros_driver2](https://github.com/Livox-SDK/livox_ros_driver2)
