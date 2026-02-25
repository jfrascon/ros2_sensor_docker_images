#!/usr/bin/env python3

"""
This launch file is meant to be baked into a Docker image to simplify running the RoboSense driver.
"""

import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Tuple

import ros2_launch_helpers as rlh
import yaml
from jinja2 import Environment, StrictUndefined, TemplateError
from launch import LaunchContext, LaunchDescription, LaunchDescriptionEntity
from launch.actions import LogInfo, OpaqueFunction
from launch_ros.actions import Node


def generate_launch_description() -> LaunchDescription:
    return LaunchDescription([OpaqueFunction(function=launch_node)])


def launch_node(_ctx: LaunchContext) -> List[LaunchDescriptionEntity]:
    robot_name = get_required_env_var('ROBOT_NAME')
    namespace = get_optional_env_var('NAMESPACE', '')
    robot_ns = rlh.create_robot_namespace(namespace, robot_name)
    node_options = rlh.process_node_options(get_optional_env_var('NODE_OPTIONS', rlh.default_node_options_str()))

    # If the node's name is not set, set a default one.
    if not str(node_options['name']).strip():
        node_options['name'] = 'robosense_lidar_ros2_handler'

    logging_options = rlh.process_logging_options(
        get_optional_env_var('LOGGING_OPTIONS', rlh.default_logging_options_str())
    )

    ros_arguments = logging_options

    # Each executable 'rslidar_sdk_node' will spawn a node called 'param_handle' and 'N' nodes, one for each
    # LiDAR described in the config file under the 'lidar' key.
    # Each of those 'N' nodes is in charge of publishing the pointcloud and imu (if present) of one LiDAR.

    # We have to re-name those nodes properly, prepending the robot name and a unique index.

    # Renaming of one param_handle.
    ros_arguments.extend(['-r', f'param_handle:__node:={node_options["name"]}_params'])

    config_file = get_required_env_var('CONFIG_FILE')
    effective_config_file, config = process_config_file(config_file)

    # Renaming of N nodes, one per lidar in the config file.
    for index, _ in enumerate(config['lidar']):
        ros_arguments.extend(
            [
                # remappings of names of those nodes for each binary executed
                '-r',
                f'rslidar_points_destination_{index}:__node:={node_options["name"]}_lidar_{index}',
            ]
        )

    ldes: list[LaunchDescriptionEntity] = [LogInfo(msg=[f'robot_ns: {robot_ns}'])]

    for k, v in node_options.items():
        ldes.append(LogInfo(msg=f'Node option: {k} = {v}'))

    ldes.extend(
        [
            LogInfo(msg=[f'ROS arguments: {" ".join(ros_arguments)}']),
            Node(
                package='rslidar_sdk',
                executable='rslidar_sdk_node',
                namespace=robot_ns,
                # name = node_name NOT ADDED ON PURPOSE, read above.
                # This launch file is always used with real hardware, never in simulation.
                parameters=[{'use_sim_time': False, 'config_path': effective_config_file}],
                ros_arguments=ros_arguments,
                output=node_options['output'],
                emulate_tty=node_options['emulate_tty'],
                respawn=node_options['respawn'],
                respawn_delay=node_options['respawn_delay'],
            ),
        ]
    )

    return ldes


################################################################################
# Non-opaque functions and helpers.
################################################################################


def get_required_env_var(env_name: str) -> str:
    value = os.getenv(env_name, '').strip()

    if not value:
        raise RuntimeError(f"Environment variable '{env_name}' is required and cannot be empty")

    return value


def get_optional_env_var(env_name: str, default: str) -> str:
    value = os.getenv(env_name)

    return value.strip() if value is not None else default


def process_config_file(config_file: str) -> Tuple[str, Dict[str, Any]]:
    """
    Render an optional Jinja2 robot-prefix placeholder and validate the resulting
    RoboSense configuration file structure.
    :param config_file: Configuration file.
    :return: Tuple of effective configuration file path and parsed configuration mapping.
    """

    robot_prefix = rlh.create_robot_prefix(get_required_env_var('ROBOT_NAME'))

    # Read the original configuration file content as UTF-8 text.
    with open(config_file, encoding='utf-8') as f:
        original_content = f.read()

    # Render the configuration file as a Jinja2 template, substituting the 'robot_prefix' variable, if present.
    try:
        template = Environment(autoescape=False, undefined=StrictUndefined).from_string(original_content)
        rendered_content = template.render(robot_prefix=robot_prefix)
    except TemplateError as exc:
        raise RuntimeError(f"Failed to render Jinja2 template in configuration file '{config_file}': {exc}") from exc

    effective_config_file = config_file

    # Keep the original file when Jinja2 does not change anything, otherwise write the rendered content to a
    # deterministic daily file in /tmp and use that as the effective configuration file.
    if rendered_content != original_content:
        date_str = datetime.now(timezone.utc).strftime('%Y%m%d')
        effective_config_file = f'/tmp/robosense_config_{date_str}.yaml'

        with open(effective_config_file, mode='w', encoding='utf-8') as f:
            f.write(rendered_content)

    try:
        config = yaml.safe_load(rendered_content)
    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML syntax in file '{effective_config_file}': {e}") from e

    if not isinstance(config, dict):  # Top-level YAML object must be a mapping
        raise ValueError(f"File '{effective_config_file}' must be a mapping. Got: '{type(config).__name__}'")

    # Validate expected structure of the configuration file.
    # 'common' and 'lidar' top-level keys are required.
    # For each entry in the 'lidar' list, 'driver' and 'ros' keys are required.
    # Under the 'ros' key, 'ros_frame_id' key is required.
    # 'ros_frame_id' value must be a string.
    # Prepend 'robot_prefix' to 'ros_frame_id' if not already present.
    if 'common' not in config:
        raise RuntimeError(f"Configuration file '{effective_config_file}' is missing the top-level 'common' key")

    if 'lidar' not in config:
        raise RuntimeError(f"Configuration file '{effective_config_file}' is missing the top-level 'lidar' key")

    lidar_cfg = config['lidar']

    if not isinstance(lidar_cfg, list) or len(lidar_cfg) == 0:
        raise RuntimeError(
            f"Configuration file '{effective_config_file}' must have a non-empty list under the top-level 'lidar' key"
        )

    for index, lidar_config in enumerate(lidar_cfg):
        if 'driver' not in lidar_config:
            raise RuntimeError(
                f'LiDAR entry at index {index} in configuration file '
                f"'{effective_config_file}' is missing the 'driver' key"
            )

        if 'ros' not in lidar_config:
            raise RuntimeError(
                f"LiDAR entry at index {index} in configuration file '{effective_config_file}' is missing the 'ros' key"
            )

        ros_cfg = lidar_config['ros']

        if 'ros_frame_id' not in ros_cfg:
            raise RuntimeError(
                f"LiDAR entry at index {index} in configuration file '{effective_config_file}' is missing the"
                " 'ros_frame_id' key under the 'ros' key"
            )

        if not isinstance(ros_cfg['ros_frame_id'], str):
            raise RuntimeError(
                f"'ros_frame_id' in LiDAR entry at index {index} in configuration file "
                f"'{effective_config_file}' must be a string"
            )

    return effective_config_file, config
