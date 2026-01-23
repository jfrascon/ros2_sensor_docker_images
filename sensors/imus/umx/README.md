# umx_driver: um6 / um7

ROS driver for the CH Robotics UM6 and UM7 inertial measurement units (IMU).
Supports standard data and mag topics as well as providing temperature and rpy outputs.

See the ROS wiki for details on hardware installation and ROS 1 software implementation:  http://wiki.ros.org/um7

This driver is built on an updated version of the [original serial library](https://github.com/wjwwood/serial) that has been [updated for ROS 2](https://github.com/RoverRobotics-forks/serial-ros2).

This driver is the one used by **Clearpath Robotics** in their platforms. See [here](https://docs.clearpathrobotics.com/docs_robots/accessories/sensors/imu/redshift_labs_um7/).

## Docker Integration

The main objective of this folder is to provide a robust and reproducible mechanism to install the UM7/UM6 ROS2 driver inside a Docker image. This approach encapsulates the execution environment, eliminating dependency conflicts and facilitating deployment on any host system.

### Build Components

To orchestrate the image creation, three essential files are provided to modularize the process:

*   **`install.sh`**: Manages the installation of the **serial-ros2** library, the **um7** driver, and other system dependencies required for the proper functioning of the driver.
*   **`compile.sh`**: Executes the compilation of the ROS2 workspace (*colcon build*), generating the driver binaries inside the container.
*   **`eut_sensor.launch.py`**: A *launch file* designed to be embedded in the image, which standardizes node execution and dynamic parameter configuration.

To fully understand the build process, we primarily recommend reading the **Dockerfile** from the multi-sensor example located at the project root. This example illustrates how to create a Docker image for multiple sensors by reusing the `install`, `compile`, and `eut_sensor.launch.py` files associated with each sensor in this project.

The **Dockerfile** in the `examples/` folder is also recommended reading. It serves as a standalone reference for building an image dedicated solely to this sensor, suitable for testing or specific single-sensor deployments.

#### Note on Repository Forks and Patches

This project utilizes a forked version of the serial library (`serial-ros2`) to ensure compatibility with ROS2. Additionally, the official `um7` driver repository is patched during installation to facilitate the inclusion of the custom launch file and ensure proper build configuration.

For specific details on the repositories used and the patching process, please consult the comments within the `install.sh` script.

### Deployment Examples

In the `examples/` folder, you will find the necessary resources to build an example image and deploy the driver. Configurations are included for:
1.  Running the UM7 or UM6 IMU sensor.

For detailed instructions on building and running, please refer to the `README.md` located inside the `examples` folder.

## Reference

For more information on sensor configuration and the driver project, please refer to the official GitHub repository:
https://github.com/ros-drivers/um7/tree/ros2
