#!/usr/bin/env python3

"""
This launch file is meant to be baked into a Docker image to simplify running the Realsense driver.
"""

import os
from typing import List

import ros2_launch_helpers as rlh
from ament_index_python.packages import get_package_share_directory
from launch import LaunchContext, LaunchDescription, LaunchDescriptionEntity
from launch.actions import LogInfo, OpaqueFunction, SetLaunchConfiguration
from launch_ros.actions import LifecycleNode, Node
from launch_ros.parameter_descriptions import ParameterFile


def generate_launch_description() -> LaunchDescription:
    return LaunchDescription([OpaqueFunction(function=launch_node)])


def launch_node(_ctx: LaunchContext) -> List[LaunchDescriptionEntity]:
    robot_name = get_required_env_var('ROBOT_NAME')
    namespace = get_optional_env_var('NAMESPACE', '')
    robot_ns = rlh.create_robot_namespace(namespace, robot_name)

    # Create the robot_prefix by adding an underscore at the end of the robot name, if it does not already end with an
    # underscore.
    robot_prefix = rlh.create_robot_prefix(robot_name)

    # Process node options, including 'name', 'output', 'emulate_tty', 'respawn', 'respawn_delay'.
    node_options = rlh.process_node_options(get_optional_env_var('NODE_OPTIONS', rlh.default_node_options_str()))

    # If the node's name is not set, set a default one.
    if not str(node_options['name']).strip():
        node_options['name'] = 'realsense_camera'

    # Process logging options, including 'log-level', 'disable-stdout-logs', 'disable-rosout-logs',
    # 'disable-external-lib-logs', and custom logger levels.
    logging_options = rlh.process_logging_options(
        get_optional_env_var('LOGGING_OPTIONS', rlh.default_logging_options_str())
    )

    # ros_arguments is the list of arguments to pass to the node, it is initialized with the logging options, since they
    # are also passed as ROS arguments.
    ros_arguments = logging_options

    # The key 'TOPIC_REMAPPINGS' is associated by default to an empty string.
    # If a value is passed for this key, it should be a string with key-value pairs, like:
    # "/from_topic1:=/to_topic1,/from_topic2:=/to_topic2"
    topic_remappings = rlh.process_topic_remappings(get_optional_env_var('TOPIC_REMAPPINGS', ''))

    params_file = get_required_env_var('PARAMS_FILE')

    if not os.path.isfile(params_file):
        raise RuntimeError(f"The specified PARAMS_FILE '{params_file}' does not exist or is not a file")

    parameters = [
        # Allow substitutions because the params file may use '$(var robot_prefix)' in fields like frame_id.
        ParameterFile(params_file, allow_substs=True),
        # This launch file is always used with real hardware, never in simulation.
        # The parameter 'use_sim_time' is stored after any parameter file, so it overrides any value in the file.
        {'use_sim_time': False},
    ]

    # The realsense2_camera ROS2 driver can be launched in two modes, with a lifecycle node or with a regular node.
    # The 'use_lifecycle_node' parameter in the 'global_settings.yaml' file is used to select the mode.
    # If 'use_lifecycle_node' is set to True, a LifecycleNode is used, otherwise a regular Node is used.
    # The 'global_settings.yaml' file is generated dynamically during the compilation process of the ROS2 package,
    # based on the value of the flag '-DUSE_LIFECYCLE_NODE=ON|OFF' passed to colcon with --cmake-args.
    lifecycle_param_file = os.path.join(
        get_package_share_directory('realsense2_camera'), 'config', 'global_settings.yaml'
    )

    # read_yaml_mapping(...) returns a tuple:
    # (resolved_yaml_path, yaml_mapping_dict), where the path can come from resolvable patterns (e.g., package://,
    # file://).
    _, lifecycle_params = rlh.read_yaml_mapping(lifecycle_param_file)
    node_action = LifecycleNode if lifecycle_params.get('use_lifecycle_node', False) else Node

    # ldes is the list of LaunchDescriptionEntity to return in this OpaqueFunction.
    # LogInfo actions are added first to the list, so that the log messages are printed before the node is launched.
    ldes: list[LaunchDescriptionEntity] = [
        LogInfo(msg=[f'robot_ns: {robot_ns}']),
        LogInfo(msg=[f'robot_prefix: {robot_prefix}']),
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
            # In case the parameter file uses the placeholder 'robot_prefix' (for the 'frame_id') the key 'robot_prefix'
            # must be set in the context before adding the node that uses the parameter file.
            SetLaunchConfiguration('robot_prefix', robot_prefix),
            node_action(
                package='realsense2_camera',
                executable='realsense2_camera_node',
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
