# Multi-sensor Docker example (UMX + Livox Gen2 + RoboSense)

This folder provides a practical example of how to build your own Docker image with ROS2 sensor handlers and run a multi-sensor deployment.

The main goal is to show one possible structure that you can reuse in your own project. It is only an example, not a mandatory template.

## What this example shows

- How to build a single Docker image that contains low-level sensor installations plus ROS2 handlers.
- How to run each sensor in its own container.
- How to combine multiple `docker compose` files in one final launch command.
- How to centralize deployment variables in an environment file.

## Key files and responsibilities

- `build.py`: simple helper to run `docker build` with the required build arguments and metadata.
- `Dockerfile`: the core of the installation logic. This is where the real setup happens.
- `run_docker_container.sh`: utility helper to start the deployment in `automatic` or `manual` mode.
- `deployment.env`: user-editable runtime values (namespaces, IDs, sensor config paths, etc.).

## Why the Dockerfile is important

`build.py` is intentionally simple. The important part is the `Dockerfile`.

During image build, the `Dockerfile` clones the sensor repository.
Then it reuses each sensor's setup/compile files.
This mirrors how many users integrate sensor folders in real projects.

If you want to adapt this example, inspect the `Dockerfile` first.

## Compose structure (chained files)

In this example, the final deployment is launched by chaining compose files:

- Base compose: `docker_compose_base.yaml`
- Mode compose: `docker_compose_mode_automatic.yaml` or `docker_compose_mode_manual.yaml`
- Optional GUI compose: `docker_compose_gui.yaml` (only when host display is available)

In this example, three compose YAML files are used to let users test different launch combinations (`base` + `mode` + optional `gui`).

For a real production deployment, this is usually simpler:

- `docker_compose_base.yaml`
- optionally `docker_compose_gui.yaml` only if the host has GUI capabilities

In many production setups, `run_docker_container.sh` is not needed.
The final `docker compose` command is run directly in a terminal.

Example of a command you will probably use in production (direct terminal execution, no wrapper script):

```bash
IMG_ID=multi_sensor:jazzy docker compose --env-file ./deployment.env \
  -f docker_compose_base.yaml \
  up -d
```

### `docker_compose_base.yaml`

This is the main compose file in this example. It defines all services and the base runtime settings.

About environment variables, there are two valid approaches:

- Simple and explicit approach: define all needed environment variables directly in each service, even if that means repeating the same values several times.
- Reusable approach: define common variables once and reuse them across services.

In this example, the reusable approach is implemented with `x-common-environment`.
That block is a YAML anchor defined at the top of the file.

A YAML anchor is a reusable YAML block:

- it is declared once (for example `&common-environment`),
- then referenced by its name in each service where it is needed (for example `<<: *common-environment`).

Reference: https://docs.docker.com/reference/compose-file/fragments/

### `docker_compose_gui.yaml`

This is an optional GUI support file (X11/XWayland).
In this example, `run_docker_container.sh` adds it only when `DISPLAY` is available on the host.

Why this matters:

- If the host has no display, GUI-related mappings are not useful, so this file is skipped.
- If the host has a display and you want GUI tools (for example RViz2 in manual debugging), this file is included.

For your own project, you do not need to keep this split.
You can do several things, for example:

- merge the GUI lines directly into your final compose file:
  keep a single compose file and copy the X11-related mounts and environment variables (from `docker_compose_gui.yaml`) into each service definition.
  With this approach, you do not need a separate GUI compose file.
- enable GUI only for selected sensor services:
  for example, enable GUI only in the service where you run RViz2, and keep other sensor services headless.
- enable GUI for all services:
  useful when you want any container to be able to open graphical tools during development/debug.
- remove GUI support completely if your host is headless:
  if the deployment host has no display, drop GUI-specific lines and keep a pure headless compose setup.

Important: if you want GUI, you must grant X11 permissions on the host before `docker compose up`, for example:

```bash
xhost +local:
```

In this example, `run_docker_container.sh` already runs this step automatically.
It does that when a host display is detected (`DISPLAY`) and `docker_compose_gui.yaml` is included.
The command is shown here for users who run `docker compose` directly without the wrapper script.

### `docker_compose_mode_automatic.yaml` and `docker_compose_mode_manual.yaml`

These mode files are specific to this example.
They let the user choose between two ways of running the same deployment:

- Automatic mode: when running `docker compose ... up`, sensor launch wrappers are executed automatically.
- Manual mode: containers start without launching sensors; then you connect with `docker exec` and launch each sensor manually for testing/debugging.

## About `run_docker_container.sh`

`run_docker_container.sh` is a convenience utility provided by this example.
It helps switch between automatic/manual mode.
It can also add the GUI compose file when a display is available.

In production, you do not need this script if your deployment flow is already fixed.
You can run Docker Compose directly with the files you need, for example:

```bash
IMG_ID=multi_sensor:jazzy docker compose --env-file ./deployment.env \
  -f docker_compose_base.yaml \
  -f docker_compose_mode_automatic.yaml \
  up -d
```

Depending on your project, you may use one compose file, two files, or a different structure.

## Deployment variables (`deployment.env`)

`deployment.env` contains runtime values such as:

- common scope values (`NAMESPACE`, `ROBOT_NAME`, `ROS_DOMAIN_ID`),
- common logging values,
- paths to sensor configuration files mounted by compose.

`run_docker_container.sh` passes this file to Docker Compose with `--env-file`.
You can provide a different environment file if you want different deployment profiles.

In this example, using `deployment.env` is a convenience choice. It helps centralize shared values and switch deployment profiles quickly.

In your own project, it is also valid not to use an env file.
You can define values directly in each compose service, even if they are repeated.
For example, you can repeat namespace/robot/domain values per service.
That approach is equally correct and may simplify deployment, depending on your workflow.

## Sensor configuration files

Each sensor has its own configuration files:

- UMX: params YAML selected with `UM_PARAMS_FILE` and model selected with `UM_MODEL`.
- Livox Gen2: JSON + params YAML (`LIVOX_USER_CONFIG_FILE`, `LIVOX_PARAMS_FILE`).
- RoboSense: YAML config (`ROBOSENSE_CONFIG_FILE`).

These files are mounted by `docker_compose_base.yaml` and then consumed inside each sensor container.

In this example, host paths for these files are provided through variables in `deployment.env`.
Those variables are then used in Compose mounts.

In your own project, you can skip that indirection.
You can write host paths directly in each service mount in your compose file.
That is also a valid approach and can simplify the workflow, depending on how much flexibility you need.

This example intentionally shows a more complete pattern.
You can see what is possible and keep only what fits your deployment.

## Launch wrapper scripts (`run_launch_*`)

The scripts:

- `run_launch_umx.sh`
- `run_launch_livox_gen2.sh`
- `run_launch_robosense.sh`

are used to map runtime environment values to launch-file arguments.
They also run sensor-specific pre-processing before `ros2 launch`.

Why this matters:

- Some sensor configs include names related to URDF links or frame IDs.
- In many systems those names must be prefixed with `<robot_name>_`.
- `ROBOT_NAME` is runtime-configurable (environment variable), so the same configuration templates can be reused across different robots and projects.

For that reason, wrappers compute `robot_prefix` dynamically from `ROBOT_NAME` and replace placeholders such as `{{robot_prefix}}` when present in sensor config files.

This avoids hardcoding robot-specific names in sensor configuration files and keeps the same configuration templates reusable across multiple robot identities.

If you prefer, you can still hardcode full names in your config files and maintain them manually.
That is also valid, but then you must keep those names consistent with the robot name used at runtime.
With that manual style, you might simplify or even remove parts of these wrapper scripts.

This example provides the more general and programmatic approach on purpose. In many projects you can reuse these scripts almost as-is.

In manual mode, `run_docker_container.sh` starts all sensor containers but leaves them running in `bash`.
It does not launch sensors automatically.
Then you connect to each container with `docker exec -it <container_name> bash` and run `/tmp/run_launch_in_terminal.sh`.
This starts the corresponding sensor in that container.
It also lets you inspect live console output per sensor, which is useful for debugging or for investigating failures seen in automatic mode.

## Build and run

Build image:

```bash
python example_multi_sensor/build.py ubuntu:24.04 jazzy multi_sensor:jazzy
```

Run automatic mode:

```bash
cd example_multi_sensor
./run_docker_container.sh multi_sensor:jazzy automatic
```

Run manual mode:

```bash
./run_docker_container.sh multi_sensor:jazzy manual
# Shows running services/containers and their names (useful before docker exec).
IMG_ID=multi_sensor:jazzy docker compose --env-file ./deployment.env -f docker_compose_base.yaml -f docker_compose_mode_manual.yaml ps
```

Then enter a container and launch manually:

```bash
docker exec -it <container_name> bash
/tmp/run_launch_in_terminal.sh
```

## Important: this is an example, not a constraint

This layout is one valid way to structure a multi-sensor deployment.

You can change it freely, for example:

- avoid shared variable blocks and define everything per service,
- use only one compose file,
- use different environment files for different deployments,
- reorganize services and scripts as needed.

The purpose of this folder is to provide a clear, working reference that you can adapt.
It is not a fixed rule set.
In many real deployments, you will keep only a reduced subset of these files.

## References

- `sensors/imus/umx/README.md`
- `sensors/lidars/livox_gen2/README.md`
- `sensors/lidars/robosense/README.md`
