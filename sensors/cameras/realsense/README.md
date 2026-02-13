# RealSense ROS2 in Docker

The `realsense` folder contains the files required to install the ROS2 packages for RealSense cameras in multiple ROS2 distributions, together with their dependencies, in a Docker image.
Both the ROS2 packages and the `librealsense2` library are installed from source code by cloning their official repositories.

Official repositories:
- RealSense ROS2 packages: `https://github.com/realsenseai/realsense-ros`
- librealsense2 library: `https://github.com/realsenseai/librealsense`

The `setup.sh`, `install_librealsense2_from_source.sh`, and `compile.sh` scripts are designed to be used from a `Dockerfile` and automate image building.

The guide [how_to_patch_the_kernel_and_install_librealsense2_in_host_operating_system.md](how_to_patch_the_kernel_and_install_librealsense2_in_host_operating_system.md) summarizes the installation options for `librealsense2` and provides practical criteria to choose the most suitable one depending on the environment and use case.

In addition, the file [examples.md](examples.md) gathers practical examples to make environment setup and validation easier.

## Usage example

To illustrate how to use the files mentioned above, an example has been created in the `examples/` folder, where a `Dockerfile` is provided to build an image that allows running the ROS2 packages for RealSense cameras inside a Docker container.

The process is designed to be convenient for the user: just run `examples/build.py` and indicate the ROS2 distro you want to use (`humble` or `jazzy`).

Example:
```bash
cd sensors/cameras/realsense/examples
./build.py humble
```

The script includes optional flags that may be useful (for example, cache control, base image pull, metadata, or image name). To see them:
```bash
./build.py -h
```

In `examples/` there are two files that control which versions are cloned and how `librealsense2` is compiled:

- `refs.txt`: defines the remote references (tags/branches) cloned for:
  - `librealsense2`
  - `realsense-ros`
  - `ros2_launch_helpers`
- `librealsense2_compile_flags.txt`: defines CMake options to compile `librealsense2`.

Modify `refs.txt` if you want to:
- pin a specific version for stability or reproducibility,
- test a newer version (feature/bugfix),
- align compatible versions between `realsense-ros` and `librealsense2`.

Expected format:
```txt
librealsense2 v2.56.5
realsense-ros 4.56.4
ros2_launch_helpers main
```

Keep in mind that the `librealsense2` version and the release of ROS2 packages in the `realsense-ros` repository are linked: not every version combination is compatible. To know which `librealsense2` version corresponds to a specific `realsense-ros` release, the most reliable way is to review [realsense2_camera/CMakeLists.txt](https://github.com/realsenseai/realsense-ros/blob/ros2-master/realsense2_camera/CMakeLists.txt) (use the file from the specific `realsense-ros` release you need; this link points to `ros2-master`) and identify the version indicated in `find_package(realsense2 X.Y.Z)`.

Modify `librealsense2_compile_flags.txt` if you want to:
- enable/disable tools or examples (`BUILD_TOOLS`, `BUILD_GRAPHICAL_EXAMPLES`, `BUILD_EXAMPLES`),
- adjust backend (`FORCE_RSUSB_BACKEND`),
- enable or disable CUDA (`BUILD_WITH_CUDA`).

Expected format:
- one option per line with `NAME=VALUE`,
- without `-D` prefix,
- boolean values `ON|OFF|TRUE|FALSE`.

All `librealsense2` build flags are described at:
[https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake](https://github.com/realsenseai/librealsense/blob/master/CMake/lrs_options.cmake)

Additional tools are described at:
[https://github.com/realsenseai/librealsense/tree/master/tools](https://github.com/realsenseai/librealsense/blob/master/tools).

Examples are described at:
[https://github.com/realsenseai/librealsense/tree/master/examples](https://github.com/realsenseai/librealsense/tree/master/examples).

If `BUILD_EXAMPLES=ON`, the binaries `rs-callback`, `rs-color`, `rs-depth`, `rs-distance`, `rs-embedded-filter`, `rs-eth-config`, `rs-infrared`, `rs-hello-realsense`, `rs-on-chip-calib`, and `rs-save-to-disk` are built.<br/><br/>
If `BUILD_GRAPHICAL_EXAMPLES=ON` as well, `realsense-viewer`, `rs-align`, `rs-align-gl`, `rs-align-advanced`, `rs-benchmark`, `rs-capture`, `rs-data-collect`, `rs-depth-quality`, `rs-gl`, `rs-hdr`, `rs-labeled-pointcloud`, `rs-measure`, `rs-motion`, `rs-multicam`, `rs-pointcloud`, `rs-post-processing`, `rs-record-playback`, `rs-rosbag-inspector`, `rs-sensor-control`, and `rs-software-device` are also generated.<br/><br/>
If `BUILD_EXAMPLES=OFF`, none of the binaries above are built, neither graphical nor non-graphical, even if `BUILD_GRAPHICAL_EXAMPLES` is `ON`.<br/><br/>
If you only want non-graphical examples, use `BUILD_EXAMPLES=ON` and `BUILD_GRAPHICAL_EXAMPLES=OFF`.<br/><br/>
If you want graphical examples, use `BUILD_EXAMPLES=ON` and `BUILD_GRAPHICAL_EXAMPLES=ON`, which implies you will also get non-graphical examples.

If `BUILD_TOOLS=ON`, the binaries `rs-convert`, `rs-enumerate-devices`, `rs-fw-logger`, `rs-terminal`, `rs-record`, `rs-fw-update`, and `rs-embed` are built.<br/><br/>
If `BUILD_WITH_DDS=ON` as well, `rs-dds-adapter`, `rs-dds-config`, and `rs-dds-sniffer` are also generated.<br/><br/>
If `BUILD_TOOLS=OFF`, none of the binaries above are built, neither DDS nor non-DDS, even if `BUILD_WITH_DDS` is `ON`.<br/><br/>
If you only want base tools, use `BUILD_TOOLS=ON` and `BUILD_WITH_DDS=OFF`.<br/><br/>
If you want DDS tools, use `BUILD_TOOLS=ON` and `BUILD_WITH_DDS=ON`, which implies you will also get base tools.

Example file with build flags for `librealsense2`:
```txt
BUILD_WITH_CUDA=OFF
BUILD_EXAMPLES=ON
BUILD_GRAPHICAL_EXAMPLES=ON
BUILD_TOOLS=ON
FORCE_RSUSB_BACKEND=ON
```

Once the image is built with `examples/build.py`, you can start the container in two modes using `examples/run_docker_container.sh`:

- `automatic` mode: the container starts and automatically runs the ROS2 driver launch.
- `manual` mode: the container starts without launching the driver, so you can enter a shell and run it manually.

Example (if you built with `./build.py humble`, the default `img_id` is `realsense:humble`):

```bash
cd sensors/cameras/realsense/examples
./run_docker_container.sh realsense:humble automatic
```

If you prefer manual mode:

```bash
cd sensors/cameras/realsense/examples
./run_docker_container.sh realsense:humble manual
docker compose exec -it realsense_srvc bash
bash /tmp/run_realsense_launch_in_terminal.sh
```

This example is also prepared to run graphical applications from the container (for example `rviz2` and `realsense-viewer`) and display them on the host through X11/XWayland. Keep in mind that `realsense-viewer` will only be available if `librealsense2` was compiled with `BUILD_EXAMPLES=ON` and `BUILD_GRAPHICAL_EXAMPLES=ON`.

The `run_docker_container.sh` script allows configuring variables through `--env KEY=VALUE`.

Variables with default values in this example:

- `NAMESPACE` (default: empty)
- `ROBOT_NAME` (default: `robot`)
- `ROS_DOMAIN_ID` (default: `11`)
- `NODE_OPTIONS` (default: `name=realsense_ros2_driver,output=screen,emulate_tty=True,respawn=False,respawn_delay=0.0`)
- `LOGGING_OPTIONS` (default: `log-level=info,disable-stdout-logs=true,disable-rosout-logs=false,disable-external-lib-logs=true`)

`NODE_OPTIONS` and `LOGGING_OPTIONS` are `kvs` (key-value-string) variables, i.e., a string composed of `key=value` pairs separated by commas.

Additional variables supported by the script:

- `ROS_LOCALHOST_ONLY=1|0` (ROS2 Humble and earlier, no default value)
- `ROS_AUTOMATIC_DISCOVERY_RANGE=LOCALHOST|SUBNET|OFF|SYSTEM_DEFAULT` (ROS2 Jazzy and later, no default value)
- `ROS_STATIC_PEERS='192.168.0.1;remote.com'` (ROS2 Jazzy and later, no default value)
- `TODO`: add documentation for `TOPIC_REMAPPINGS` once validation tests are completed.

Additionally, you can pass other extra variables with `--env`; the script forwards them to the container.

There are variables that cannot be configured with `--env` in this flow:

- `RMW_IMPLEMENTATION`: fixed in `docker_compose_base.yaml` as `rmw_cyclonedds_cpp`. This example uses CycloneDDS as DDS middleware. If you want to change middleware, you must edit `docker_compose_base.yaml`.
- `CYCLONEDDS_URI`: fixed in `docker_compose_base.yaml`.
- `PARAMS_FILE`: fixed in `docker_compose_base.yaml`.
- `IMG_ID`: taken from the script positional argument `<img_id>`.
- `ENV_FILE`: managed internally by the script.

CycloneDDS configuration used in this example is defined in `examples/cyclonedds_config.xml`. The middleware loads it through the `CYCLONEDDS_URI` variable, defined in `docker_compose_base.yaml`.

Camera parameter configuration is defined in `examples/realsense_params.yaml`. If you want to change profiles, streams, `frame_id`, or any parameter of the `realsense2_camera` node, edit that file.

Example execution with overrides:

```bash
./run_docker_container.sh realsense:humble automatic \
  --env ROBOT_NAME=robot1 \
  --env ROS_DOMAIN_ID=21 \
  --env ROS_LOCALHOST_ONLY=1
```

To see all available options:

```bash
./run_docker_container.sh -h
```
