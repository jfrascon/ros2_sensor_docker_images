# How to update the firmware of an RealSense camera (D400 series, D500 series, etc.)

## Option A: Update the firmware using the `realsense-viewer` tool

The `realsense-viewer` tool provides a graphical user interface to manage your RealSense camera, including firmware updates.
If there is a firmware update available for your camera, you will see a notification in the `realsense-viewer` interface when you connect your camera. You can follow the prompts to download and install the latest firmware directly from the viewer.

## Option B: Update the firmware using the `rs-fw-update` command-line tool

The following instructions are a summary of the information found on the official RealSense documentation:
https://dev.realsenseai.com/docs/firmware-update-tool

Please, be sure the `librealsense` version you are using has been compiled with tools support (`-DBUILD_TOOLS=ON`), otherwise you won't be able to use the `rs-fw-update` tool.

To ensure your RealSense camera is running the recommended firmware, follow these steps:

1. **Check the current and recommended firmware version**

   ```bash
   rs-enumerate-devices
   ```

   Look for lines similar to:

   ```bash
   Firmware Version              :     5.16.0
   Recommended Firmware Version  :     5.17.0.10
   ```

   This indicates whether your device can be updated and which version is recommended.

2. **Download the recommended firmware**

   Visit [https://dev.realsenseai.com/docs/firmware-releases-d400](https://dev.realsenseai.com/docs/firmware-releases-d400) and download the indicated firmware version.
   There are similar pages for other series: https://dev.realsenseai.com/docs/firmware-updates

3. **Extract the firmware file**

   Unzip the downloaded folder. Locate the `.bin` file inside.

4. **Update the firmware**

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
