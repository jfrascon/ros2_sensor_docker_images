#!/usr/bin/env python3

"""
This launch file is meant to be baked into a Docker image to simplify running the UM IMU driver.
"""

import os
from typing import List

import ros2_launch_helpers as rlh
from launch import LaunchContext, LaunchDescription, LaunchDescriptionEntity
from launch.actions import LogInfo, OpaqueFunction, SetLaunchConfiguration
from launch_ros.actions import Node
from launch_ros.parameter_descriptions import ParameterFile


def generate_launch_description() -> LaunchDescription:
    return LaunchDescription([OpaqueFunction(function=launch_node)])


def launch_node(_ctx: LaunchContext) -> List[LaunchDescriptionEntity]:
    robot_name = get_required_env_var('ROBOT_NAME')
    namespace = get_optional_env_var('NAMESPACE', '')
    robot_ns = rlh.create_robot_namespace(namespace, robot_name)
    robot_prefix = rlh.create_robot_prefix(robot_name)

    node_options = rlh.process_node_options(get_optional_env_var('NODE_OPTIONS', rlh.default_node_options_str()))

    # If the node's name is not set, set a default one.
    if not str(node_options['name']).strip():
        node_options['name'] = 'umx'

    logging_options = rlh.process_logging_options(
        get_optional_env_var('LOGGING_OPTIONS', rlh.default_logging_options_str())
    )

    ros_arguments = logging_options
    topic_remappings = rlh.process_topic_remappings(get_optional_env_var('TOPIC_REMAPPINGS', ''))

    um_model = get_optional_env_var('UM_MODEL', '7')

    if um_model not in ('6', '7'):
        raise RuntimeError(f"UM_MODEL must be 6 or 7 (got '{um_model}')")

    params_file = get_required_env_var('PARAMS_FILE')

    if not os.path.isfile(params_file):
        raise RuntimeError(f"The specified PARAMS_FILE '{params_file}' does not exist or is not a file")

    parameters = [
        # Allow substitutions because the params file may use '$(var robot_prefix)' in fields like frame_id.
        ParameterFile(params_file, allow_substs=True),
        # This launch file is always used with real hardware, never in simulation.
        {'use_sim_time': False},
    ]

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
            # In case the parameter file uses the placeholder 'robot_prefix',
            # it must be set in the launch context before adding the Node.
            SetLaunchConfiguration('robot_prefix', robot_prefix),
            Node(
                package='umx_driver',
                executable=f'um{um_model}_driver',
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
