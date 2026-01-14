# Example: ROS2 multi-sensor Docker image (IMU UMX + Livox Gen2 LiDAR + Robosense LiDAR)

This folder is a user-facing example that shows how to build a ROS 2 Docker image that
installs multiple sensor drivers by reusing the scripts already present in `sensors/`.

Key idea: the Dockerfile clones this repository into `/tmp/sensor_images` and then calls
`sensors/imus/umx`, `sensors/lidars/livox_gen2`, and `sensors/lidars/robosense` install/compile scripts.

## Build

The build script is intentionally simple; it builds using this folder as the Docker build context.

```
usage: build.py [-h] [-c] [-p] [--img-id IMG_ID] [--meta-title META_TITLE] [--meta-desc META_DESC] [--meta-authors META_AUTHORS] ros_distro

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
  --img-id IMG_ID              Built Docker image ID. Default: um_livox_gen2_lidar_robosense_lidar:<ros_distro>
  --meta-title META_TITLE      Image title for OCI metadata
  --meta-desc META_DESC        Image description for OCI metadata
  --meta-authors META_AUTHORS  Image authors
```

```
python3 build.py jazzy
```

## Notes

- The Dockerfile clones the repo into `/tmp/sensor_images`.
- The example uses the existing install/compile scripts from each sensor.
- This example is meant to be copied to other projects and edited as needed.
