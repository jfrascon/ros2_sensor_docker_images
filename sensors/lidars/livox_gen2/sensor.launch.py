#!/usr/bin/env python3

"""
This launch file is meant to be baked into a Docker image to simplify running the Livox Gen2 driver.
"""

import json
import os
import re
from datetime import datetime, timezone
from typing import List

import ros2_launch_helpers as rlh
import yaml
from jinja2 import Environment, StrictUndefined, TemplateError
from launch import LaunchContext, LaunchDescription, LaunchDescriptionEntity
from launch.actions import LogInfo, OpaqueFunction
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
        node_options['name'] = 'livox_gen2_lidar_ros2_handler'

    logging_options = rlh.process_logging_options(
        get_optional_env_var('LOGGING_OPTIONS', rlh.default_logging_options_str())
    )

    # ros_arguments is the list of arguments to pass to the node, it is initialized with the logging options, since they
    # are also passed as ROS arguments.
    ros_arguments = logging_options

    topic_remappings = rlh.process_topic_remappings(get_optional_env_var('TOPIC_REMAPPINGS', ''))

    params_file = get_required_env_var('PARAMS_FILE')
    effective_params_file = process_params_file(params_file, robot_prefix)

    parameters = [
        ParameterFile(effective_params_file, allow_substs=True),
        # This launch file is always used with real hardware, never in simulation.
        {'use_sim_time': False},
    ]

    # ldes is the list of LaunchDescriptionEntity to return in this OpaqueFunction.
    # LogInfo actions are added first to the list, so that the log messages are printed before the node is launched.
    ldes: list[LaunchDescriptionEntity] = [LogInfo(msg=[f'robot_ns: {robot_ns}'])]

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


def get_required_env_var(env_name: str) -> str:
    value = os.getenv(env_name, '').strip()

    if not value:
        raise RuntimeError(f"Environment variable '{env_name}' is required and cannot be empty")

    return value


def get_optional_env_var(env_name: str, default: str) -> str:
    value = os.getenv(env_name)

    return value.strip() if value is not None else default


def process_params_file(params_file: str, robot_prefix: str) -> str:
    if not os.path.isfile(params_file):
        raise RuntimeError(f"The specified PARAMS_FILE '{params_file}' does not exist or is not a file")

    try:
        with open(params_file, encoding='utf-8') as f:
            params_content = f.read()
    except OSError as exc:
        raise RuntimeError(f"Failed to read PARAMS_FILE '{params_file}': {exc}") from exc

    # Match a full line defining 'user_config_path:' at any indentation level and split it into:
    # prefix (indent + key + ':'), value (path before inline comments), and suffix (spaces + optional '#...').
    # This lets us replace only the value while preserving formatting/comments in the original params file.
    user_config_path_pattern = re.compile(
        r'^(?P<prefix>[ \t]*user_config_path[ \t]*:[ \t]*)(?P<value>[^\n#]*?)(?P<suffix>[ \t]*(?:#.*)?)$', re.MULTILINE
    )

    matches = list(user_config_path_pattern.finditer(params_content))

    if not matches:
        raise RuntimeError(f"PARAMS_FILE '{params_file}' must declare exactly one 'user_config_path'")

    if len(matches) > 1:
        raise RuntimeError(f"PARAMS_FILE '{params_file}' has multiple 'user_config_path' entries")

    user_config_path_raw = matches[0].group('value').strip()

    if not user_config_path_raw:
        raise RuntimeError(f"'user_config_path' in PARAMS_FILE '{params_file}' must be a non-empty string")

    # Parse the user_config_path as a YAML scalar to allow for quoted strings and escape sequences, but ensure it is a
    # string.
    try:
        user_config_path = yaml.safe_load(user_config_path_raw)
    except yaml.YAMLError as exc:
        raise RuntimeError(f"Invalid YAML scalar for 'user_config_path' in PARAMS_FILE '{params_file}': {exc}") from exc

    if not isinstance(user_config_path, str) or not user_config_path.strip():
        raise RuntimeError(f"'user_config_path' in PARAMS_FILE '{params_file}' must be a non-empty string")

    user_config_path = user_config_path.strip()

    if not os.path.isfile(user_config_path):
        raise RuntimeError(f"user_config_path '{user_config_path}' does not exist or is not a file")

    # Read the original user config file content, render it as a Jinja2 template with the robot_prefix variable,
    # and check if the rendered content is different from the original. If it is different, validate that the rendered
    # content is valid JSON, write it to a new file in /tmp, and create a modified params file that points to the new
    # user config file.
    try:
        with open(user_config_path, encoding='utf-8') as f:
            original_user_config = f.read()
    except OSError as exc:
        raise RuntimeError(f"Failed to read user config file '{user_config_path}': {exc}") from exc

    try:
        template = Environment(autoescape=False, undefined=StrictUndefined).from_string(original_user_config)
        rendered_user_config = template.render(robot_prefix=robot_prefix)
    except TemplateError as exc:
        raise RuntimeError(f"Failed to render Jinja2 template in user config file '{user_config_path}': {exc}") from exc

    if rendered_user_config == original_user_config:
        return params_file

    try:
        json.loads(rendered_user_config)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"Rendered user config file '{user_config_path}' is not valid JSON: {exc}") from exc

    date_str = datetime.now(timezone.utc).strftime('%Y%m%d')
    effective_user_config = f'/tmp/livox_config_{date_str}.json'
    effective_params_file = f'/tmp/livox_params_{date_str}.yaml'

    try:
        with open(effective_user_config, mode='w', encoding='utf-8') as f:
            f.write(rendered_user_config)
    except OSError as exc:
        raise RuntimeError(f"Failed to write rendered user config file '{effective_user_config}': {exc}") from exc

    # Create the effective params file content by replacing the original user_config_path line with a new one that
    # points to the effective user config file, while preserving the original formatting and comments.
    effective_params_content = user_config_path_pattern.sub(
        lambda m: f'{m.group("prefix")}"{effective_user_config}"{m.group("suffix")}', params_content, count=1
    )

    # Write the effective params content to the effective params file.
    try:
        with open(effective_params_file, mode='w', encoding='utf-8') as f:
            f.write(effective_params_content)
    except OSError as exc:
        raise RuntimeError(f"Failed to write effective PARAMS_FILE '{effective_params_file}': {exc}") from exc

    return effective_params_file
