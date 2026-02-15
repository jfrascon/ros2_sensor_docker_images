#!/usr/bin/env python3

"""
This launch file is meant to be baked into a Docker image to simplify running the Livox Gen2 driver.
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
    # Get robot name from key 'robot_name' in the launch context.
    robot_name = LaunchConfiguration('robot_name').perform(ctx)

    # Create the robot namespace (robot_ns) by combining the values of the keys 'namespace' and 'robot_name' in the
    # launch context.
    # robot_ns has the form '/<namespace>/<robot_name>' or '/<robot_name>' if '<namespace>' is empty or '/'.
    robot_ns = rlh.create_robot_namespace(LaunchConfiguration('namespace').perform(ctx), robot_name)

    # Process node options, including 'name', 'output', 'emulate_tty', 'respawn', 'respawn_delay'.
    node_options = rlh.process_node_options(LaunchConfiguration('node_options').perform(ctx))

    # If the node's name is not set, set a default one.
    if not str(node_options['name']).strip():
        node_options['name'] = 'livox_gen2_lidar_ros2_handler'

    # Process logging options, including 'log-level', 'disable-stdout-logs', 'disable-rosout-logs',
    # 'disable-external-lib-logs', and custom logger levels.
    logging_options = rlh.process_logging_options(LaunchConfiguration('logging_options').perform(ctx))

    # ros_arguments is the list of arguments to pass to the node, it is initialized with the logging options, since they
    # are also passed as ROS arguments.
    ros_arguments = logging_options

    # The key 'topic_remappings' is associated by default to an empty string.
    # If a value is passed for the key 'topic_remappings', it should be a string with the form of key-value pairs, like:
    # "/from_topic1:=/to_topic1,/from_topic2:=/to_topic2"
    # The function 'process_topic_remappings' processes the string and returns a list of tuples of the form:
    # [(from1, to1), (from2, to2), ...]
    topic_remappings = rlh.process_topic_remappings(LaunchConfiguration('topic_remappings').perform(ctx))

    # parameters is a list of parameters to pass Node. It can contain ParameterFile and/or dictionaries with parameters.
    parameters = []

    # Add parameter file to parameters list only if it's not empty.
    params_file = LaunchConfiguration('params_file').perform(ctx).strip()
    if params_file:
        parameters.append(ParameterFile(params_file, allow_substs=True))

    # This launch file is always used with real hardware, never in simulation.
    # The parameter 'use_sim_time' is store after any parameter file, so it overrides any value in the file.
    parameters.append({'use_sim_time': False})

    # ldes is the list of LaunchDescriptionEntity to return in this OpaqueFunction.
    # LogInfo actions are added first to the list, so that the log messages are printed before the node is launched.
    ldes: list[LaunchDescriptionEntity] = [
        LogInfo(msg=[f'robot_ns: {robot_ns}']),
    ]

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
