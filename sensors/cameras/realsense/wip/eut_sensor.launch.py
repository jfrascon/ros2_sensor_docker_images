#!/usr/bin/env python3

"""
This launch file is meant to be baked into a Docker image to simplify running the driver.

- NAMESPACE (optional): base namespace. If unset or '/', the base is '/'. Otherwise:
      * The provided value is validated first (rejects invalid tokens, control chars, '//' etc.),
      * Then normalized, ensuring leading '/' and strip trailing '/'.
- ROBOT_NAME (required, non-empty): used to build the robot-scoped namespace/prefix.
- PARAMS_FILE (required, non-empty): path to a YAML parameters file ('*.yaml').
- TOPIC_REMAPPINGS (optional): key-value string for topic remappings.
  For example:
  TOPIC_REMAPPINGS="from_topic1:=to_topic1,from_topic2:=to_topic2"
- NODE_OPTIONS (optional): key-value string for node options.
  For example:
  NODE_OPTIONS="name=any_name,output=both,emulate_tty=True,respawn=True,respawn_delay=3.0"
- LOGGING_OPTIONS (optional): key-value string for ROS logging options.
  For example:
  LOGGING_OPTIONS="log-level=info,disable-stdout-logs=false,disable-rosout-logs=false,disable-external-lib-logs=true,
                   logger1_name=<level>,logger2_name=<level>"

The effective robot namespace is:
    robot_namespace = '/' + ROBOT_NAME                , if NAMESPACE == '/'
                      NAMESPACE + '/' + ROBOT_NAME    , otherwise

A 'robot_prefix' is also derived for frame ids:
    robot_prefix = robot_name + '_'
"""

import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, Union

import yaml
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription, LaunchDescriptionEntity
from launch.actions import LogInfo
from launch_ros.actions import LifecycleNode, Node

# Add to the system path the path to the 'realsense2_camera/launch' folder.
# This way we can import the 'rs_launch' module directly and we can access the 'configurable_parameters' list.
sys.path.append(os.path.join(get_package_share_directory('realsense2_camera'), 'launch'))
import rs_launch

# After the import of the 'rs_launch' module, we have access to 'rs_launch.configurable_parameters'.
# Check 'https://github.com/IntelRealSense/realsense-ros/blob/ros2-master/realsense2_camera/launch/rs_launch.py#L23'
# for a list of the default parameters.

DEFAULT_LOGGING_OPTIONS = {
    'log-level': 'info',  # One of: 'debug', 'info', 'warn', 'error'
    'disable-stdout-logs': False,  # Whether to disable writing log messages to the console
    'disable-rosout-logs': False,  # Whether to disable writing log messages out to /rosout
    'disable-external-lib-logs': False,  # Whether to completely disable the use of an external logger
}

DEFAULT_NODE_OPTIONS = {
    'name': '',  # Node name (if empty, use default from the node executable)
    'output': 'screen',  # One of: 'screen', 'log', 'both'
    'emulate_tty': True,  # Whether to emulate a TTY for the node's stdout/stderr (usually True for 'screen' or 'both')
    'respawn': False,  # Whether to respawn the node if it dies
    'respawn_delay': 0.0,  # Delay in seconds before respawning a node
}


def generate_launch_description() -> LaunchDescription:
    # Namespace env variable is optional, and by default is ''.
    raw_ns = os.getenv('NAMESPACE', '')

    # Empty or '/' means global namespace '/'.
    if raw_ns == '' or raw_ns == '/':
        namespace = '/'
    else:
        # Validate the provided namespace.
        validate_namespace(raw_ns)

        # Make the namespace global.
        # If the provided namespace does not start with '/', add it.
        namespace = raw_ns if raw_ns.startswith('/') else '/' + raw_ns

        # If the provided namespace ends with '/', remove it.
        if namespace.endswith('/'):
            namespace = namespace.rstrip('/')

    # From this point onwards, 'namespace' is either '/' or a string starting with '/' and not ending with '/'.

    # ROBOT_NAME env variable is required and must be non-empty.
    robot_name = os.getenv('ROBOT_NAME')

    if robot_name is None:
        raise RuntimeError('Environment variable ROBOT_NAME must be set to a non-empty string')

    if not is_valid_name(robot_name):
        raise RuntimeError("Robot's name must be ASCII [A-Za-z0-9_] only")

    robot_namespace = f'/{robot_name}' if namespace == '/' else (namespace + '/' + robot_name)  # type: ignore

    # Since the characters allowed for names include [A-Za-z0-9_], the '_' is a valid character and it could be the
    # case the last character is '_'.
    # Not very common to have a robot name ending with '_', but handle it anyway.
    if not robot_name.endswith('_'):
        robot_prefix = robot_name + '_'
    else:
        robot_prefix = robot_name

    # LOGGING_OPTIONS is option, it may not appear in the environment.
    # LOGGING_OPTIONS is a key-value string (kvs), like:
    # "log-level=info,disable-stdout-logs=True,disable-rosout-logs=True,disable-external-lib-logs=True,
    #  logger1_name=<level>,logger2_name=<level>"
    logging_options = process_logging_options(os.getenv('LOGGING_OPTIONS', ''))

    # NODE_OPTIONS is optional, it may not appear in the environment.
    # NODE_OPOPTIONS is a key-value string (kvs), like
    # "name=any_name,output=both,emulate_tty=True,respawn=True,respawn_delay=3.0"'
    node_options = process_node_options(os.getenv('NODE_OPTIONS', ''))
    # If node_options['name'] is empty, use the default name 'realsense2_camera_node'.
    node_name = node_options['name'] or 'realsense2_camera_node'

    if not is_valid_name(node_name):  # type: ignore
        raise RuntimeError("Node's name must be ASCII [A-Za-z0-9_] only")

    # TOPIC_REMAPPINGS is optional and if it appears, it is a key-value string (kvs), like
    # "/from_topic1:=/to_topic1,/from_topic2:=/to_topic2"
    # 'remapppings' is a list of (from, to) tuples.
    topic_remappings = process_topic_remappings(os.getenv('TOPIC_REMAPPINGS', ''))

    # process_params_file returns a tuple (params_dict, params_file_path)
    # The parameters file passed in the PARAMS_FILE environment variable can be edited by the function
    # 'process_params_file', so that is why the function returns both, the parameters dict and the actual parameters
    # file used. More details in the function 'process_params_file'.
    # params, params_file = process_params_file(os.getenv('PARAMS_FILE', ''), robot_prefix, node_options['name'])  # type: ignore

    # Load lifecycle nodes setting from YAML dynamically generated by CMAKE instead of environment variable
    lifecycle_param_file = os.path.join(
        get_package_share_directory('realsense2_camera'), 'config', 'global_settings.yaml'
    )

    lifecycle_params = read_yaml_mapping(lifecycle_param_file)
    use_lifecycle_node = lifecycle_params.get('use_lifecycle_node', False)

    # Dynamically choose Node or LifecycleNode
    node_action = LifecycleNode if use_lifecycle_node else Node

    ldes: list[LaunchDescriptionEntity] = [
        LogInfo(msg=[f'namespace: {namespace}']),
        LogInfo(msg=[f'robot_name: {robot_name}']),
        LogInfo(msg=[f'robot_namespace: {robot_namespace}']),
        LogInfo(msg=[f'robot_prefix: {robot_prefix}']),
        # LogInfo(msg=[f'Parameters file: {params_file}']),
        LogInfo(msg=[f'ROS arguments: {" ".join(logging_options)}']),
    ]

    for k, v in node_options.items():
        ldes.append(LogInfo(msg=[f'Node option: {k} = {v}']))

    if not topic_remappings:
        ldes.append(LogInfo(msg=['No topic remappings specified']))
    else:
        for original_topic, new_topic in topic_remappings:
            ldes.append(LogInfo(msg=[f'Topic remapping: {original_topic} -> {new_topic}']))

    ldes.append(
        node_action(
            package='realsense2_camera',
            executable='realsense2_camera_node',
            namespace=robot_namespace,
            name=node_options['name'],  # type: ignore
            # parameters=[params],
            remappings=topic_remappings,
            ros_arguments=logging_options,
            output=node_options['output'],
            emulate_tty=node_options['emulate_tty'],
            respawn=node_options['respawn'],
            respawn_delay=node_options['respawn_delay'],
        )
    )

    return LaunchDescription(ldes)


################################################################################
# Non-opaque functions and helpers.
################################################################################


def read_yaml_mapping(yaml_file: str) -> dict[str, Any]:
    """
    Load a YAML file and enforce:
      - top-level must be a mapping (dict)
      - it must NOT be empty (emit a dedicated 'empty mapping' message)
    """
    if not isinstance(yaml_file, str):
        raise ValueError(f'YAML file must be a str (got: {type(yaml_file).__name__})')

    yaml_file = yaml_file.strip()

    yaml_path = Path(yaml_file)

    if not yaml_path.is_file():
        raise ValueError(f"File '{yaml_file}' does not exist")

    try:
        with yaml_path.open('r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML syntax in file '{yaml_file}': {e}") from e
    except (OSError, UnicodeDecodeError) as e:
        raise ValueError(f"Failed to read file '{yaml_file}': {e}") from e
    except Exception as e:
        raise ValueError(f"Unexpected error reading YAML file '{yaml_file}': {e}") from e

    # Handle empty/None content explicitly
    if data is None:
        raise ValueError(f"File '{yaml_file}' is empty; expected a mapping")

    if not isinstance(data, dict):
        raise ValueError(f"File '{yaml_file}' must be a mapping. Got: '{type(data).__name__}'")

    # Validate non-empty mapping.
    if not data:  # type: ignore
        raise RuntimeError(f"File '{yaml_file}' has no nodes: YAML mapping is empty")

    return data  # type: ignore


def process_logging_options(logging_options_kvs: str) -> List[str]:
    """
    Parse the logging options string into a ROS arguments string.
    :param logging_options_kvs: Key-value string for logging options.
    :return: ROS arguments string.

    Reference: https://docs.ros.org/en/rolling/Tutorials/Demos/Logging-and-logger-configuration.html

    Example
    logging_options_kvs="log-level=info,disable-stdout-logs=True,disable-rosout-logs=True,disable-external-lib-logs=True,
                  logger1_name=<level>,logger2_name=<level>"
    output: [--log-level, info, --disable-stdout-logs, --disable-rosout-logs, --disable-external-lib-logs, --log-level,
             logger1_name:=<level>, --log-level, logger2_name:=<level>]
    """

    def to_ros_args(logging_options: Dict[str, Any]) -> List[str]:
        args = []

        for k, v in logging_options.items():
            if k == 'log-level':
                v = v.strip()
                if v:
                    args.extend([f'--{k}', v])
            elif k == 'disable-stdout-logs' or k == 'disable-rosout-logs' or k == 'disable-external-lib-logs':
                if v:
                    args.append(f'--{k}')
            # If it is not one of the known keys, it must be a custom logger level.
            else:
                v = v.strip()
                if v:
                    args.extend(['--log-level', f'{k}:={v}'])

        return args

    # Passing default values to 'logging_opts', so:
    # - In case a key is missing, it gets the default value.
    # - In case 'logging_options' is empty, we use the default log options.
    logging_opts: Dict[str, Union[str, bool]] = DEFAULT_LOGGING_OPTIONS.copy()

    # If no logging options are provided, return the default logging options as ROS args.
    if not isinstance(logging_options_kvs, str):
        return to_ros_args(logging_opts)

    logging_options_kvs = logging_options_kvs.strip()

    # If the logging options string is empty, return the default logging options as ROS args.
    if not logging_options_kvs:
        return to_ros_args(logging_opts)

    # Iterate over each key-value pair in the logging options string.
    for logging_option in logging_options_kvs.split(','):
        logging_option = logging_option.strip()

        # If the element between commas is empty or does not contain '=', skip it.
        if not logging_option or '=' not in logging_option:
            continue

        # Split only on the first '='. It should be key=value, but value could contain '='.
        key, val = logging_option.split('=', 1)

        # Strip leading and trailing spaces.
        # Key must be passed as is (case-sensitive), but we allow values to be case-insensitive, so
        # we convert them to lower case for easier comparison.
        key = key.strip()
        val = val.strip().lower()

        # If no key or value is provided, skip it.
        if not key or not val:
            continue

        match key:
            case 'log-level':
                if val in ('debug', 'info', 'warn', 'error'):
                    logging_opts[key] = val
            case 'disable-stdout-logs':
                if val in ('true', 'false'):
                    logging_opts[key] = val == 'true'
            case 'disable-rosout-logs':
                if val in ('true', 'false'):
                    logging_opts[key] = val == 'true'
            case 'disable-external-lib-logs':
                if val in ('true', 'false'):
                    logging_opts[key] = val == 'true'
            # If it is not one of the known keys, it must be a custom logger level.
            # A custom logger has the form 'logger_name=<level>'.
            # Important, for a logger to apply correctly in the node, its name must be fully qualified with the node's
            # namespace
            case _:
                if val in ('debug', 'info', 'warn', 'error', 'fatal'):
                    # key is the logger name, val is the log level.
                    logging_opts[key] = val

    # print(f'Logging options dict: {logging_opts}')
    # print(f'ROS args: {to_ros_args(logging_opts)}')

    return to_ros_args(logging_opts)


def process_node_options(node_options_kvs: Optional[str]) -> Dict[str, Union[str, bool, float]]:
    """
    Parse the node options string into a dictionary.
    :return: Dictionary with node options.

    Example
    node_options="name=a_node_name,output=both,emulate_tty=True,respawn=True,respawn_delay=3.0"
    output: {'output': 'both', 'emulate_tty': True, 'respawn': True, 'respawn_delay': 3.0}
    """
    node_options: Dict[str, Union[str, bool, float]] = DEFAULT_NODE_OPTIONS.copy()

    # If no node options are provided or not a string, return the default node options.
    if not isinstance(node_options_kvs, str):
        return node_options

    # Strip leading and trailing spaces.
    node_options_kvs = node_options_kvs.strip()

    # If the node options string is empty, return the default node options.
    if not node_options_kvs:
        return node_options

    for node_option in node_options_kvs.split(','):
        node_option = node_option.strip()

        # If the element between commas is empty or does not contain '=', skip it.
        if not node_option or '=' not in node_option:
            continue

        # Split only on the first '='. It should be key=value, but value could contain '='.
        key, val = node_option.split('=', 1)

        key = key.strip().lower()
        val = val.strip().lower()

        # If no key is provided or the key is not in the default node options, skip it.
        if not key or key not in DEFAULT_NODE_OPTIONS:
            continue

        # Validate and set the node option based on the key.
        match key:
            case 'name':
                # The best option for the user to use the default name is not to provide the 'name' key at all.
                # But, we also allow the user to indicate TO USE THE DEFAULT NODE NAME by providing one of the words
                # 'none', 'null', 'undefined', 'unknown', 'default', case insensitive, or empty string. If one of these
                # words or empty string is provided, we skip setting the 'name' key, so the default name is used.
                if (
                    val
                    and val != 'none'
                    and val != 'null'
                    and val != 'undefined'
                    and val != 'unknown'
                    and val != 'default'
                ):
                    node_options[key] = val
            case 'output':
                if val in ('screen', 'log', 'both'):
                    node_options[key] = val
            case 'emulate_tty':
                if val in ('true', 'false'):
                    node_options[key] = val == 'true'
            case 'respawn':
                if val in ('true', 'false'):
                    node_options[key] = val == 'true'
            case 'respawn_delay':
                try:
                    node_options[key] = float(val)
                except Exception as e:
                    raise ValueError(f"Invalid value for 'respawn_delay': '{val}'") from e
            case _:  # Should never happen
                pass

    return node_options


def process_params_file(params_file: str, robot_prefix: str) -> Dict[str, Any]:
    """
    Process the parameters file, substituting the 'robot_prefix' in the configuration file.
    :param params_file: String path to the parameters file.
    :param robot_prefix: Robot prefix to substitute in the configuration file.
    :return: Path to the new configuration file with the substituted 'robot_prefix'.
    """

    if not isinstance(params_file, str):
        raise RuntimeError('Parameters file must be a non-empty string pointing to a .yaml file')

    params_file = params_file.strip()

    if not params_file:
        raise RuntimeError('Parameters file must be a non-empty string pointing to a .yaml file')

    # Substitute 'robot_prefix' in the parameters file provided by the user and load the rendered content as YAML.
    params = read_yaml_mapping(params_file)

    # Default parameters are defined in the rs_launch module.
    # In the 'rs.configurable_parmaters' list, every default value is a 'string'.
    # We will iterate over this list and if the user did not provide a value for a parameter,
    # we will use the default value, but converted to its real type.
    # But if the user provided a value for a parameter, we will use it as is.
    # configurable_parameters = [{'name': 'camera_name',      'default': 'camera', 'description': '...'},
    #                            {'name': 'camera_namespace', 'default': 'camera', 'description': '...'},
    #                            {'name': 'serial_no',        'default': "''",     'description': '...'},
    #                            {'name': 'usb_port_id',      'default': "''",     'description': '...'},
    # ...
    #                            {'name': 'initial_reset',    'default': 'false',  'description': '...'},
    # ...
    #                            {'name': 'wait_for_device_timeout', 'default': '-1.', 'description': '...'},
    # ...
    default_params_seq = rs_launch.configurable_parameters
    merged_params = {}

    for default_param in default_params_seq:
        try:
            name = default_param['name']
            # safe_load to convert the default value from string to its real type.
            merged_params[name] = params.get(name, yaml.safe_load(default_param['default']))
        except yaml.YAMLError as e:
            raise RuntimeError(
                f"Invalid YAML in default parameter '{default_param['name']}': {default_param['default']}. Error: {e}"
            ) from e

    # It is important to note that in the default parameters defined in the 'rs_launch.py' module, we can find the
    # parameter 'camera_namespace'.
    # The parameter 'camera_namespace' is used in the module 'rs_launch.py' to set the namespace of the node.
    # In our Docker images for sensors we use the environment variables 'NAMESPACE' and 'ROBOT_NAME' to set the
    # variable 'robot_namespace', which is then used as the namespace for the node, topics, etc., for homogeneity among
    # all the eut_sensor.launch.py files.
    # For this reason, key 'camera_namespace' in the 'merged_params' dictionary, coming either from the user-provided
    # parameters file or from the default parameters defined in the 'rs_launch.py' module, is popped out from the
    # 'merged_params' dictionary, because the node will use 'robot_namespace' as its namespace.

    # In the default parameters defined in the 'rs_launch.py' module, we can find the parameter 'config_file'.
    # This parameter is used in the 'rs_launch.py' to set the path to a configuration file for the RealSense camera.
    # There is no need to use that parameter in this launch file, since the configuration file used for the camera is
    # set via the environment variable 'PARAMS_FILE' pointing to a YAML file.

    # In the default parameters defined in the 'rs_launch.py' module, we can find the parameters 'output' and
    # 'log_level'.
    # These parameters are used in the 'rs_launch.py' to set the output and log level of the node.
    # In our Docker images for sensors we use the environment variables 'LOGGING_OPTIONS' and 'NODE_OPTIONS' to set the
    # output and logging level for the node, for homogeneity among all the eut_sensor.launch.py files.
    # For this reason, keys 'output' and 'log_level' in the 'merged_params' dictionary, coming either from the
    # user-provided parameters file or from the default parameters defined in the 'rs_launch.py' module, are popped out
    # from the 'merged_params' dictionary, because the node will use the values from 'node_options' and 'log_options'.

    merged_params.pop('camera_namespace', None)
    merged_params.pop('config_file', None)
    merged_params.pop('output', None)
    merged_params.pop('log_level', None)

    # 'camera_name' should not be prefixed with the 'robot_prefix' in the configuration file provided by the user, and
    # it is definitely not prefixed in the default parameters defined in the 'rs_launch' module.
    # Anyway, ensure the 'camera_name' is not prefixed with the 'robot_prefix', and if it is not, prefix it.
    if not merged_params['camera_name'].startswith(robot_prefix):
        merged_params['camera_name'] = robot_prefix + merged_params['camera_name']

    # Write the merged parameters to a new temporary YAML file, to let the user know the final parameters used.
    params_file = f'/tmp/{robot_prefix}{node_name}.yaml'

    with Path(params_file).open('w', encoding='utf-8') as f:
        # default_flow_style False for pretty-printed YAML.
        yaml.dump(merged_params, f, default_flow_style=False)

    return merged_params, params_file


def process_topic_remappings(remappings_kvs: Optional[str]) -> Optional[List[Tuple[str, str]]]:
    """
    Parse the remappings string into a list of (from, to) tuples.
    :param remappings_kvs: Key-value string for topic remappings.
    :return: List of (from, to) tuples.

    Example
    remappings_kvs="/a:=/b,/c:=d,e:=/f,g:=h"
    ouput: [('/a', '/b'), ('/c', 'd'), ('e', '/f'), ('g', 'h')]
    """

    # If no remappings are provided or not a string, return None.
    if not isinstance(remappings_kvs, str):
        return None

    remappings_kvs = remappings_kvs.strip()

    # If the remappings string is empty, return None.
    if not remappings_kvs:
        return None

    remappings: List[Tuple[str, str]] = []

    for from_to in remappings_kvs.split(','):
        from_to = from_to.strip()

        # If the element between commas is empty, skip it.
        if not from_to:
            continue

        # If the element does not contain ':=', skip it.
        if ':=' not in from_to:
            continue  # Ignore invalid remapping

        # Split only on the first ':='. It must be from:=to.
        from_expr, to_expr = from_to.split(':=', 1)

        from_expr = from_expr.strip()
        to_expr = to_expr.strip()

        # If no 'from' or 'to' expression is provided, skip it.
        if not from_expr or not to_expr:
            continue  # Ignore invalid remapping

        remappings.append((from_expr, to_expr))

    return remappings


def is_valid_name(name: str) -> bool:
    """
    Validate characters of a string segment.

    Returns:
        - True  -> all characters are valid (ASCII alnum or underscore).
        - False -> at least one invalid character found.
        - None  -> input is empty; considered 'not evaluable' at this level.

    Notes:
        - This function does not raise; it only reports.
        - Policy decisions (e.g., whether empty is allowed) belong to the caller.
    """
    if not isinstance(name, str):
        return False

    name = name.strip()

    if not name:
        return False

    # Check all characters.
    # Valid characters are ASCII alphanumeric or underscore, [A-Za-z0-9_].
    # If any other character is found, return False.
    return all((c == '_') or (c.isascii() and c.isalnum()) for c in name)


def validate_namespace(ns: str) -> None:
    """
    Validate a namespace string.

    Rules:
    - '' and '/' are permitted as special cases (root/empty).
    - Reject empty segments (no '//' allowed at any position).
    - Each non-empty segment must be valid, i.e., ASCII alnum or underscore only, [A-Za-z0-9_].
    """

    if ns in ('', '/'):
        return

    # When two or more slashes are contiguos, when you split the string by '/', you get empty segments.
    # For example:
    # 'ns1//ns2'   -> ['ns1', '', 'ns2'] --> two or more '/' in a row
    # '/ns1//ns2/' -> ['', 'ns1', '', 'ns2', ''] -> the first and last are false positives.

    # In order to check if there are two or more '/' in a row, we need to first remove the leading and trailing slashes
    # if present.

    # Remove EXACTLY ONE leading slash.
    if ns.startswith('/'):
        ns = ns[1:]

    # Remove exactly one trailing slash
    if ns.endswith('/'):
        ns = ns[:-1]

    # If ns is '//', after removing leading and trailing slashes, it becomes '', which is an invalid namespace.
    if not ns:
        raise RuntimeError("Namespace cannot be empty after removing leading and trailing '/'")

    # Examples at this point:
    # '/ns1//ns2/' -> 'ns1//ns2' -> ['ns1', '', 'ns2'] -> two or more '/' in a row, this is an error.
    # But
    # '/ns1/ns2/'  -> 'ns1/ns2'  -> ['ns1', 'ns2']  -> OK. The leadind and trailing slashes are OK, although the
    #                                                      trailing slash is not necessary.

    items = ns.split('/')

    for item in items:
        # Empty items means two or more '/' in a row, so this is an error.
        # Technically, we could have removed this 'if not item' check, since 'is_valid_name' would return False for
        # empty strings, but this way we can provide a more specific error message.
        if not item:
            raise RuntimeError("Consecutive '/' are not allowed in a namespace")

        # Check the item is in valid, which means ASCII alnum or underscore only, [A-Za-z0-9_].
        if not is_valid_name(item):
            raise RuntimeError('Namespace segments must be ASCII [A-Za-z0-9_] only')
