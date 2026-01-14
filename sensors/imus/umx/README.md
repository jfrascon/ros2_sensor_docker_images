# umx_driver: um6 / um7

ROS driver for the CH Robotics UM6 and UM7 inertial measurement units (IMU).
Supports standard data and mag topics as well as providing temperature and rpy outputs.

See the ROS wiki for details on hardware installation and ROS 1 software implementation:  http://wiki.ros.org/um7

This driver is built on an updated version of the [original serial library](https://github.com/wjwwood/serial) that has been [updated for ROS 2](https://github.com/RoverRobotics-forks/serial-ros2).

This driver is the one used by **Clearpath Robotics** in their platforms. See [here](https://docs.clearpathrobotics.com/docs_robots/accessories/sensors/imu/redshift_labs_um7/).

>**Note**: The "port" assignment actually defaults to "/dev/ttyUSB0", so if your sensor is on that port, the parameter setting shown above is unnecessary. Replace "ttyUSB0" with the port number of your UM7 device.

## Nodes and topics

>**Note**: The same topic and service names are used for both the um6_driver and um7_driver and thus only one can be run at a time without additional namespacing.

- imu/data (sensor_msgs/msg/Imu)
- imu/mag (sensor_msgs/msg/magnetic_field)
- imu/rpy (geometry_msgs/msg/Vector3Stamped)
- imu/temperature (std_msgs/msg/Float32)

## Parameters and commands
The parameters are the same as the ROS 1 driver.

## Reset service
- imu/reset

Reference:[https://github.com/ros-drivers/um7/tree/ros2](https://github.com/ros-drivers/um7/tree/ros2)
