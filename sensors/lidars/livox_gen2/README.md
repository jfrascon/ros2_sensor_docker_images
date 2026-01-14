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
