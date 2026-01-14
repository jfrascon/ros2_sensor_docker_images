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

## Which should you use?

* Use **`rslidar_sdk`** for integration into **ROS1 or ROS2** systems.
* Use **`rs_driver`** for **custom C++ pipelines** or embedded deployments **without ROS**.
