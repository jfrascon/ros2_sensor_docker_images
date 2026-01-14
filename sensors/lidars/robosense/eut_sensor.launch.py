#!/usr/bin/env python3

"""
This launch file is meant to be baked into a Docker image to simplify running the RoboSense driver.
"""

from typing import Any, Dict, List

import ros2_launch_helpers as rlh
from launch import LaunchContext, LaunchDescription, LaunchDescriptionEntity
from launch.actions import DeclareLaunchArgument, LogInfo, OpaqueFunction, SetLaunchConfiguration  # noqa: F401
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterFile  # noqa: F401


def generate_launch_description() -> LaunchDescription:
    return LaunchDescription(
        [
            DeclareLaunchArgument('namespace', default_value='', description='namespace (Optional)'),
            DeclareLaunchArgument(
                'robot_name', default_value='', description='The unique name for the robot (Required)'
            ),
            DeclareLaunchArgument('config_file', default_value='', description='Path to configuration file (Optional)'),
            DeclareLaunchArgument(
                'node_options', default_value=rlh.default_node_options_str(), description=rlh.NODE_OPTIONS_DESC
            ),
            DeclareLaunchArgument(
                'logging_options', default_value=rlh.default_logging_options_str(), description=rlh.LOGGING_OPTIONS_DESC
            ),
            OpaqueFunction(function=launch_node),
        ]
    )


def launch_node(ctx: LaunchContext) -> List[LaunchDescriptionEntity]:
    robot_name = LaunchConfiguration('robot_name').perform(ctx)
    robot_ns = rlh.create_robot_namespace(LaunchConfiguration('namespace').perform(ctx), robot_name)

    node_options = rlh.process_node_options(LaunchConfiguration('node_options').perform(ctx))

    # If the node's name is not set, set a default one.
    if not str(node_options['name']).strip():
        node_options['name'] = 'robosense_lidar_ros2_driver'

    logging_options = rlh.process_logging_options(LaunchConfiguration('logging_options').perform(ctx))

    ros_arguments = logging_options

    # Robosense drivers gets the topics from the config file, so remappings are not needed.

    # Each executable 'rslidar_sdk_node' will spawn a node called 'param_handle' and 'N' nodes, one for each
    # LiDAR described in the config file under the 'lidar' key.
    # Each of those 'N' nodes is in charge of publishing the pointcloud and imu (if present) of one LiDAR.

    # We have to re-name those nodes properly, prepending the robot name and a unique index.

    # Renaming of one param_handle.
    ros_arguments.extend(['-r', f'param_handle:__node:={node_options["name"]}_param_handler'])

    config_file = LaunchConfiguration('config_file').perform(ctx).strip()

    if config_file:
        config = process_config_file(config_file)

        # Renaming of N nodes, one per lidar in the config file.
        for index, _ in enumerate(config['lidar']):
            ros_arguments.extend(
                [
                    # remappings of names of those nodes for each binary executed
                    '-r',
                    f'rslidar_points_destination_{index}:__node:={node_options["name"]}_handler_{index}',
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
                parameters=[{'use_sim_time': False, 'config_path': config_file}],
                # No remappings needed, topics are defined in the config_file.
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


def process_config_file(config_file: str) -> Dict[str, Any]:
    """
    Process the configuration file, substituting the 'robot_prefix' in the configuration file.
    :param params_file: Configuration file.
    :param robot_prefix: Robot prefix to substitute in the configuration file.
    :return: Path to the new configuration file with the substituted 'robot_prefix'.
    """

    _, config = rlh.read_yaml_mapping(config_file)

    # Validate expected structure of the configuration file.
    # 'common' and 'lidar' top-level keys are required.
    # For each entry in the 'lidar' list, 'driver' and 'ros' keys are required.
    # Under the 'ros' key, 'ros_frame_id' key is required.
    # 'ros_frame_id' value must be a string.
    # Prepend 'robot_prefix' to 'ros_frame_id' if not already present.
    if 'common' not in config:
        raise RuntimeError(f"Configuration file '{config_file}' is missing the top-level 'common' key")

    if 'lidar' not in config:
        raise RuntimeError(f"Configuration file '{config_file}' is missing the top-level 'lidar' key")

    lidar_cfg = config['lidar']

    if not isinstance(lidar_cfg, list) or len(lidar_cfg) == 0:
        raise RuntimeError(
            f"Configuration file '{config_file}' must have a non-empty list under the top-level 'lidar' key"
        )

    for index, lidar_config in enumerate(lidar_cfg):
        if 'driver' not in lidar_config:
            raise RuntimeError(
                f"LiDAR entry at index {index} in configuration file '{config_file}' is missing the 'driver' key"
            )

        if 'ros' not in lidar_config:
            raise RuntimeError(
                f"LiDAR entry at index {index} in configuration file '{config_file}' is missing the 'ros' key"
            )

        ros_cfg = lidar_config['ros']

        if 'ros_frame_id' not in ros_cfg:
            raise RuntimeError(
                f"LiDAR entry at index {index} in configuration file '{config_file}' is missing the"
                " 'ros_frame_id' key under the 'ros' key"
            )

        if not isinstance(ros_cfg['ros_frame_id'], str):
            raise RuntimeError(
                f"'ros_frame_id' in LiDAR entry at index {index} in configuration file '{config_file}' must be a string"
            )

    return config
