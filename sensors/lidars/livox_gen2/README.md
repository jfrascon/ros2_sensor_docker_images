# Livox Gen2 ROS2 in Docker

The `livox_gen2` folder contains the files required to install the ROS2 packages for Livox second-generation LiDARs (HAP and Mid-360), together with their dependencies, in a Docker image.
Both the ROS2 packages and the Livox SDK dependency are installed from source code by cloning their repositories.

Official repositories:
- Livox ROS2 packages: `https://github.com/Livox-SDK/livox_ros_driver2`
- Livox SDK2: `https://github.com/Livox-SDK/Livox-SDK2`

This project currently uses maintained forks for `livox_ros_driver2` and `livox_sdk2`, selected in `examples/refs.txt`.

The `setup.sh`, `compile.sh`, and `eut_sensor.launch.py` scripts are designed to be used from a `Dockerfile` and automate image building.

## Usage example

To illustrate how to use the files mentioned above, an example is provided in the `examples/` folder, where a `Dockerfile` is included to build an image that allows running the ROS2 packages for Livox Gen2 LiDARs inside a Docker container.

The process is designed to be convenient for the user: run `examples/build.py` and indicate the ROS2 distro you want to use (`humble` or `jazzy`).

Example:
```bash
cd sensors/lidars/livox_gen2/examples
./build.py jazzy
```

The script includes optional flags that may be useful (for example, cache control, base image pull, metadata, or image name). To see them:
```bash
./build.py -h
```

In `examples/`, the file `refs.txt` defines the remote references (tags/branches) cloned for:
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
- `example 1`: one front LiDAR (`example_1.front_livox_mid360.json` + `example_1.front_livox_mid360.yaml`)
- `example 2`: front and rear LiDARs (`example_2.front_back_livox_mid360.json` + `example_2.front_back_livox_mid360.yaml`)

Once the image is built with `examples/build.py`, you can start the container in two modes using `examples/run_docker_container.sh`:

- `automatic` mode: the container starts and automatically runs the ROS2 driver launch.
- `manual` mode: the container starts without launching the driver, so you can enter a shell and run it manually.

Example (if you built with `./build.py jazzy`, the default `img_id` is `livox_gen2:jazzy`):

```bash
cd sensors/lidars/livox_gen2/examples
./run_docker_container.sh livox_gen2:jazzy automatic --example 1
```

If you prefer manual mode:

```bash
cd sensors/lidars/livox_gen2/examples
./run_docker_container.sh livox_gen2:jazzy manual --example 2
docker compose exec -it livox_gen2_srvc bash
bash /tmp/run_launch_in_terminal.sh
```

This example is also prepared to run graphical applications from the container and display them on the host through X11/XWayland.

The `run_docker_container.sh` script allows configuring variables through `--env KEY=VALUE`.

Variables with default values in this example:

- `NAMESPACE` (default: empty)
- `ROBOT_NAME` (default: `robot`)
- `ROS_DOMAIN_ID` (default: `11`)
- `NODE_OPTIONS` (default: `name=livox,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0`)
- `LOGGING_OPTIONS` (default: `log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true`)

`NODE_OPTIONS` and `LOGGING_OPTIONS` are `kvs` (key-value-string) variables, i.e., a string composed of `key=value` pairs separated by commas.

Additional variables supported by the script:

- `TOPIC_REMAPPINGS`: remapping string in `OLD:=NEW` format, with comma-separated pairs.
- `ROS_LOCALHOST_ONLY=1|0` (ROS2 Humble and earlier, no default value)
- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT` (ROS2 Jazzy and later, no default value)
- `ROS_STATIC_PEERS='192.168.0.1;remote.com'` (ROS2 Jazzy and later, no default value)

There are variables that cannot be configured with `--env` in this flow:

- `RMW_IMPLEMENTATION`: fixed in `examples/docker_compose_base.yaml` as `rmw_cyclonedds_cpp`.
- `CYCLONEDDS_URI`: fixed in `examples/docker_compose_base.yaml`.
- `PARAMS_FILE`: fixed in `examples/docker_compose_base.yaml`. It points to the selected YAML file mounted as `/tmp/params.yaml`.
- `USER_CONFIG_FILE_HOST`: selected internally by `run_docker_container.sh` from `--example`.
- `PARAMS_FILE_HOST`: selected internally by `run_docker_container.sh` from `--example`.
- `IMG_ID`: taken from the script positional argument `<img_id>`.
- `ENV_FILE`: managed internally by the script. It is the temporary `.env` file that `docker compose` loads through `env_file` (in `examples/docker_compose_base.yaml`) to pass environment variables to the container of service `livox_gen2_srvc`.

CycloneDDS configuration used in this example is defined in `examples/cyclonedds_config.xml`.

The launch flow keeps the current JSON/YAML placeholder replacement behavior:
- JSON files can contain `{{robot_prefix}}`.
- in this flow, `run_docker_container.sh` mounts the selected JSON as `/tmp/user_config.json` according to `--example`.
- `user_config_path` in `PARAMS_FILE` must point to `/tmp/user_config.json`.
- `run_launch.sh` resolves `{{robot_prefix}}` in the JSON pointed by `user_config_path` and updates `user_config_path` in a temporary YAML when needed.

Example execution with overrides:

```bash
./run_docker_container.sh livox_gen2:jazzy automatic --example 2 \
  --env ROBOT_NAME=robot1 \
  --env ROS_DOMAIN_ID=21 \
  --env ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST
```

To see all available options:

```bash
./run_docker_container.sh -h
```

For more information on sensor configuration and the driver project:
- https://github.com/Livox-SDK/livox_ros_driver2
