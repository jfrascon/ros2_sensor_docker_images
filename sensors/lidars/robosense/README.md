# **RoboSense LiDAR: Drivers and SDKs**

RoboSense provides two main repositories for integrating their LiDAR sensors into custom or ROS-based systems.

## rs_driver

A standalone C++ driver that handles raw packet decoding and point cloud generation.
It is the **core component** used internally by the full SDK.

* Can be used directly in non-ROS applications.
* Supports all major RoboSense LiDAR models.

## rslidar_sdk

A complete SDK for ROS1 and ROS2 that **builds on top of `rs_driver`**.

* Bundles `rs_driver` as a submodule and uses it for decoding.
* Adds ROS/ROS2 nodes, message interfaces, launch files, and parameter handling.
* Replaces the older `ros_rslidar` driver (now deprecated).
* Supports ROS1 (Kinetic, Melodic, Noetic) and ROS2 (Galactic, Humble).

## Supported sensors

Both `rs_driver` and `rslidar_sdk` support the full RoboSense product line:

* **RS‑LiDAR‑16**, **RS‑LiDAR‑32**
* **RS‑Bpearl**
* **RS‑Helios**, **Helios‑16P**
* **RS‑Ruby‑48/80/128**, **Ruby‑Plus‑48/80/128**
* **RS‑M1**, **M2**, **M3**
* **RS‑E1**, **MX**, **AIRY**

## Docker Integration

The main objective of this folder is to provide a robust and reproducible mechanism to install the RoboSense ROS2 driver inside a Docker image. This approach encapsulates the execution environment, eliminating dependency conflicts and facilitating deployment on any host system.

### Build Components

To orchestrate the image creation, three essential files are provided to modularize the process:

*   **`install.sh`**: Manages the installation of system dependencies and libraries required for the proper functioning of the SDK.
*   **`compile.sh`**: Executes the compilation of the ROS2 workspace (*colcon build*), generating the driver binaries inside the container.
*   **`eut_sensor.launch.py`**: A *launch file* designed to be embedded in the image, which standardizes node execution and dynamic parameter configuration.

To fully understand the build process, we primarily recommend reading the **Dockerfile** from the multi-sensor example located at the project root. This example illustrates how to create a Docker image for multiple sensors by reusing the `install`, `compile`, and `eut_sensor.launch.py` files associated with each sensor in this project.

The **Dockerfile** in the `examples/` folder is also recommended reading. It serves as a standalone reference for building an image dedicated solely to this sensor, suitable for testing or specific single-sensor deployments.

#### Note on Repository Forks

The official repositories for `rslidar_sdk` and `rs_driver` tend to be slow in merging community Pull Requests that address bugs or introduce enhancements. Consequently, this project utilizes forked repositories that incorporate these community fixes and improvements (e.g., better ROS2 support, cleaner build processes).

For specific details on which forks are used and the rationale (including referenced PRs), please consult the comments within the `install.sh` script.

### Deployment Examples

In the `examples/` folder, you will find the necessary resources to build an example image and deploy the driver. Configurations are included for two frequent use cases:
1.  Running a single LiDAR sensor.
2.  Simultaneous execution of two sensors using a single driver node instance.

For detailed instructions on building and running, please refer to the `README.md` located inside the `examples` folder.

## Reference

For more information on sensor configuration and the driver project, please refer to the official GitHub repository:
https://github.com/RoboSense-LiDAR/rslidar_sdk
