# Mapping Livox LiDAR models to their corresponding SDKs and ROS drivers

Livox LiDAR sensors are divided into two technological generations, each based on a distinct communication protocol and software stack. Correct integration depends on the specific model of the sensor.

## First-generation sensors

The **Mid-40**, **Mid-70**, **Horizon**, **Tele-15**, and **Avia** models use the original Livox protocol (v1). They must be integrated using the following components:

* **SDK:** `Livox-SDK`
* **ROS1 driver:** `livox_ros_driver`
* **ROS2 driver:** `livox_ros2_driver`

The `livox_ros2_driver` is a partial port of the ROS1 driver and provides basic ROS2 compatibility. While functional, it is less mature and feature-complete than the drivers developed for newer sensor models.

## Second-generation sensors

The **HAP** and **Mid-360** models rely on a newer communication protocol (v2), introduced with the updated software stack. These sensors require:

* **SDK:** `Livox-SDK2`
* **Unified ROS1/ROS2 driver:** `livox_ros_driver2`

This driver supports both ROS1 and ROS2 natively, offers improved maintainability, and includes dedicated configuration scripts for each sensor type. It also enables concurrent connection of multiple devices with minimal overhead.

## Docker Integration

The main objective of this folder is to provide a robust and reproducible mechanism to install the Livox ROS2 driver (specifically for second-generation sensors like HAP and Mid-360) inside a Docker image. This approach encapsulates the execution environment, eliminating dependency conflicts and facilitating deployment on any host system.

### Build Components

To orchestrate the image creation, three essential files are provided to modularize the process:

*   **`install.sh`**: Manages the installation of the **Livox-SDK2**, the **livox_ros_driver2**, and other system dependencies required for the proper functioning of the driver.
*   **`compile.sh`**: Executes the compilation of the ROS2 workspace (*colcon build*), generating the driver binaries inside the container.
*   **`eut_sensor.launch.py`**: A *launch file* designed to be embedded in the image, which standardizes node execution and dynamic parameter configuration.

To fully understand the build process, we primarily recommend reading the **Dockerfile** from the multi-sensor example located at the project root. This example illustrates how to create a Docker image for multiple sensors by reusing the `install`, `compile`, and `eut_sensor.launch.py` files associated with each sensor in this project.

The **Dockerfile** in the `examples/` folder is also recommended reading. It serves as a standalone reference for building an image dedicated solely to this sensor, suitable for testing or specific single-sensor deployments.

#### Note on Repository Forks

The official repositories for `Livox-SDK2` and `livox_ros_driver2` tend to be slow in merging community Pull Requests that address bugs or introduce enhancements. Consequently, this project utilizes forked repositories that incorporate these community fixes and improvements (e.g., better ROS2 support, cleaner build processes).

For specific details on which forks are used and the rationale (including referenced PRs), please consult the comments within the `install.sh` script.

### Deployment Examples

In the `examples/` folder, you will find the necessary resources to build an example image and deploy the driver. Configurations are included for two frequent use cases:
1.  Running a single LiDAR sensor (e.g., Mid-360).
2.  Simultaneous execution of two sensors using a single driver node instance.

For detailed instructions on building and running, please refer to the `README.md` located inside the `examples` folder.

## Reference

For more information on sensor configuration and the driver project, please refer to the official GitHub repository:
https://github.com/Livox-SDK/livox_ros_driver2
