# How to update the firmware of an Intel RealSense camera (D400 series, D500 series, etc.)

The following instructions are a summary of the information found on the official Intel RealSense documentation:
https://dev.realsenseai.com/docs/firmware-update-tool

To ensure your Intel RealSense camera is running the recommended firmware, follow these steps:

1. **Check the current and recommended firmware version**
   In your Docker container (with the camera connected and no ROS nodes running), execute:
   ```bash
   rs-enumerate-devices
   ```
   Look for lines similar to:
   ```
   Firmware Version              :     5.16.0
   Recommended Firmware Version  :     5.17.0.10
   ```
   This indicates whether your device can be updated and which version is recommended.

2. **Download the recommended firmware**
   Visit [https://dev.realsenseai.com/docs/firmware-releases-d400](https://dev.realsenseai.com/docs/firmware-releases-d400) and download the indicated firmware version.
   There are similar pages for other series: https://dev.realsenseai.com/docs/firmware-updates

3. **Share the firmware file with your Docker container**
   Place the downloaded firmware in a directory that is mounted and accessible from your Docker container.

4. **Extract the firmware file**
   Unzip the downloaded folder. Locate the `.bin` file inside.

5. **Update the firmware**
   In a terminal inside the container, run:
   ```bash
   sudo rs-fw-update -r -f /path/to/bin_file.bin
   ```
   Replace `/path/to/bin_file.bin` with the actual path to your firmware file.

**Notes:**
- Make sure no other process is using the camera during the update.
- Do not disconnect the camera until the update process is complete.
- The `-r` option is required if the device is in recovery mode.
- [rs-enumerate-devices](https://github.com/realsenseai/librealsense/blob/master/tools/enumerate-devices/readme.md)
