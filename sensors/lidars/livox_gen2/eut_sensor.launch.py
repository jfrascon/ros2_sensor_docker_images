#!/usr/bin/env python3

"""
This launch file is meant to be baked into a Docker image to simplify running the RoboSense driver.
"""

from typing import List

import ros2_launch_helpers as rlh
from launch import LaunchContext, LaunchDescription, LaunchDescriptionEntity
from launch.actions import DeclareLaunchArgument, LogInfo, OpaqueFunction
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterFile


def generate_launch_description() -> LaunchDescription:
    return LaunchDescription(
        [
            DeclareLaunchArgument('namespace', default_value='', description='namespace (Optional)'),
            DeclareLaunchArgument(
                'robot_name', default_value='', description='The unique name for the robot (Required)'
            ),
            DeclareLaunchArgument('params_file', default_value='', description='Path to parameter file (Optional)'),
            DeclareLaunchArgument('topic_remappings', default_value='', description='Topic remappings (Optional)'),
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
        node_options['name'] = 'livox_gen2_lidar_ros2_driver'

    logging_options = rlh.process_logging_options(LaunchConfiguration('logging_options').perform(ctx))

    ros_arguments = logging_options

    # topic_remappings is optional and if it appears, it is a key-value string (kvs), like
    # "/from_topic1:=/to_topic1,/from_topic2:=/to_topic2"
    # 'remapppings' is a list of (from, to) tuples.
    topic_remappings = rlh.process_topic_remappings(LaunchConfiguration('topic_remappings').perform(ctx))

    parameters = []
    params_file = LaunchConfiguration('params_file').perform(ctx).strip()

    # Add parameter file only if it's not empty.
    if params_file:
        # Allow substitutions in the parameter file.
        parameters.append(ParameterFile(params_file, allow_substs=True))

    # This launch file is always used with real hardware, never in simulation.
    # The parameter 'use_sim_time' is store after any parameter file, so it overrides any value in the file, so
    # if the user provides a parameter file with 'use_sim_time' set to True, it will be overridden to False here.
    parameters.append({'use_sim_time': False})

    print('----------------------------------------------------')
    print(parameters)

    ldes: list[LaunchDescriptionEntity] = [LogInfo(msg=[f'robot_ns: {robot_ns}'])]

    for k, v in node_options.items():
        ldes.append(LogInfo(msg=[f'Node option: {k} = {v}']))

    if not topic_remappings:
        ldes.append(LogInfo(msg='No topic remappings specified'))
    else:
        for original_topic, new_topic in topic_remappings:
            ldes.append(LogInfo(msg=f'Topic remapping: {original_topic} -> {new_topic}'))

    for k, v in node_options.items():
        ldes.append(LogInfo(msg=f'Node option: {k} = {v}'))

    ldes.extend(
        [
            LogInfo(msg=[f'ROS arguments: {" ".join(ros_arguments)}']),
            Node(
                package='livox_ros_driver2',
                executable='livox_ros_driver2_node',
                namespace=robot_ns,
                name=node_options['name'],  # type: ignore
                parameters=parameters,
                remappings=topic_remappings,
                ros_arguments=ros_arguments,
                output=node_options['output'],
                emulate_tty=node_options['emulate_tty'],
                respawn=node_options['respawn'],
                respawn_delay=node_options['respawn_delay'],
            ),
        ]
    )

    return ldes
