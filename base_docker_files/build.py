#!/usr/bin/env python3

import argparse
import getpass
import os
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Union  # noqa: UP035

import yaml

# ----------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------


def check_ssh_agent_and_keys() -> None:
    """Abort if ssh-agent is not running or has no keys."""
    ssh_auth_sock = os.environ.get('SSH_AUTH_SOCK')

    if not ssh_auth_sock:
        print('Error: ssh-agent is not running or SSH_AUTH_SOCK is not defined.\nHint: run:  eval $(ssh-agent)')
        sys.exit(1)

    try:
        result = subprocess.run(['ssh-add', '-l'], capture_output=True, text=True, check=True)
        if 'The agent has no identities.' in result.stdout:
            print(
                'Error: ssh-agent is running but no key is loaded.\nHint: load a key with:  ssh-add ~/.ssh/<your_key>'
            )
            sys.exit(1)
    except subprocess.CalledProcessError as exc:
        print(f'Error: failed to communicate with ssh-agent.\nDetails: {exc.stderr.strip() or exc.stdout.strip()}')
        sys.exit(1)

    print('ssh-agent is running and a key is loaded.')


def get_ros_distros_str(ros_distros: Dict[str, Dict[str, Union[str, int]]]) -> str:  # noqa: UP006
    """
    Return a human-readable, column-aligned list of the available ROS variants.

    The function iterates through the mapping of variants loaded from the YAML file and
    constructs a multi-line string in which the colon after each distro name is vertically
    aligned.  The insertion order of the original mapping is preserved (Python ≥ 3.7
    guarantees that `dict` keeps insertion order).

    Parameters
    ----------
    ros_distros : dict[str, dict[str, str | int]]
        A dictionary whose keys are variant labels (e.g. noetic) and
        whose values contain at least the following keys:

        ros_distro : str
            Name of the ROS distribution (noetic, humble, …).
        ros_version : int
            ROS major version (1 or 2).
        ubuntu_version : str
            Ubuntu release the image is based on (e.g. 20.04).

    Returns
    -------
    str
        A multi-line string of the form::

            Available ROS distros:
                noetic : ros1, ubuntu_20.04
                humble : ros2, ubuntu_22.04
                jazzy  : ros2, ubuntu_24.04
    """
    header = 'Available ROS distros:'
    width = max(len(v['ros_distro']) for v in ros_distros.values())  # type: ignore
    lines = [
        f'{v["ros_distro"]:<{width}}: ros{v["ros_version"]}, ubuntu_{v["ubuntu_version"]}' for v in ros_distros.values()
    ]

    return '\n'.join([header, *lines])


def img_exists_locally(img: str) -> bool:
    """Return True if Docker image <img> exists locally."""
    # capture=True -> stdout y stderr redireted to PIPE (they are not shown in the terminal)
    # check=False  -> it does not throw exception if the image does not exist
    result = run_command(['docker', 'image', 'inspect', img], capture=True, check=False)
    return result.returncode == 0


def is_valid_docker_img_name(name: str) -> bool:
    """
    Validate a Docker image name according to Docker's official naming rules.

    Format:
        [HOST[:PORT_NUMBER]/]PATH[:TAG]

    See: https://docs.docker.com/get-started/docker-concepts/building-images/build-tag-and-publish-an-image/#tagging-images
    """
    # Optional registry prefix: host (lower‑case letters, digits, dots, dashes)
    # with optional :PORT, followed by a slash.
    host_and_port_prefix = r'([a-z0-9.-]+(:[0-9]+)?/)?'

    # A separator inside a path component can be:
    #  - a single dot.
    #  - one or two underscores.
    #  - one or more dashes.
    path_separator = r'(?:\.|_{1,2}|-+)'

    # A path component must start and end with an alphanumeric character,
    # separators are allowed only between alphanumerics.
    path_component = rf'[a-z0-9]+(?:{path_separator}[a-z0-9]+)*'

    # PATH = one or more components separated by '/'
    path_re = rf'{path_component}(/{path_component})*'

    # Optional TAG: colon + allowed characters (letters, digits, '_', '.', '-')
    tag_re = r'(:[a-zA-Z0-9_.-]+)?'

    # Full regex combining all parts
    full_re = re.compile(rf'^{host_and_port_prefix}{path_re}{tag_re}$')

    return bool(full_re.match(name))


def run_command(
    cmd: list[str], capture: bool = False, check: bool = True, cwd: Path | None = None
) -> subprocess.CompletedProcess:
    """Wrapper around subprocess.run with sane defaults."""
    return subprocess.run(cmd, check=check, text=True, capture_output=capture, cwd=cwd)


# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

if __name__ == '__main__':
    this_file = Path(__file__).resolve()
    root_dir = this_file.parent
    ros_distros_yaml_file = root_dir.joinpath('ros_distros.yaml')

    if not ros_distros_yaml_file.is_file():
        print(f"Error: File '{ros_distros_yaml_file.resolve()}' is required")
        sys.exit(1)

    try:
        with open(ros_distros_yaml_file) as f:
            ros_distros = yaml.safe_load(f)
    except (FileNotFoundError, yaml.YAMLError):
        print(f"Error: Could not read or parse the file '{ros_distros_yaml_file.resolve()}'", file=sys.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser(
        description=(
            'Builds a Docker image with ROS(1|2) to execute the driver of a sensor and publish the captured data.'
        ),
        allow_abbrev=False,  # Disable prefix matching
        add_help=False,  # Add custom help message
        formatter_class=lambda prog: argparse.RawTextHelpFormatter(prog, max_help_position=38),
    )

    parser.add_argument('-h', '--help', action='help', default=argparse.SUPPRESS, help='Show help')

    parser.add_argument(
        '-c',
        '--cache',
        action='store_true',
        help='Reuse cached layers to optimize the time and resources needed to build the image.',
    )

    parser.add_argument(
        '-p',
        '--pull',
        action='store_true',
        help=(
            'If no local copy of the base image exists, Docker will download it automatically from\n'
            'the proper registry. If there is a local copy of the base image, Docker will get the\n'
            'version available in the proper registry, and if the version from the registry is newer\n'
            'than the local copy, it will be downloaded and used. If the local copy is the latest\n'
            'version, it will not be downloaded again.\n'
            'Without --pull Docker uses the local copy of the base image if it is available on the\n'
            'system. If no local copy exists, Docker will download it automatically.\n'
            'Usage of --pull is recommended to ensure an updated base image is used.'
        ),
    )

    parser.add_argument(
        'sensors', type=str, help="Comma-separated list of sensors to include (e.g. 'robosense,livox_hap_mid360')"
    )

    parser.add_argument('ros_distro', type=str, help=(f'{get_ros_distros_str(ros_distros)}'))

    parser.add_argument('img_id', type=str, help='Resulting Docker image ID')

    parser.add_argument(
        '-f', '--file', type=str, default=None, help=('JSON file with compile and installation options for sensors')
    )

    parser.add_argument(
        '--meta-title', type=str, default='Docker image to run a sensor', help='Image title for OCI metadata'
    )

    parser.add_argument(
        '--meta-desc',
        type=str,
        default='A Docker image to launch a sensor and publish the captured data',
        help='Image description for OCI metadata',
    )
    parser.add_argument('--meta-authors', default=getpass.getuser(), help='Image authors')

    args = parser.parse_args()

    sensors_str = args.sensors.strip()
    sensors: list[str] = []

    if not sensors_str:
        print("Warning: 'sensors' is empty", file=sys.stderr)
    else:
        for sensor in sensors_str.split(','):
            sensor_clean = sensor.strip()

            if sensor_clean:
                sensors.append(sensor_clean)

        if not sensors:
            print("Error: No valid sensor names parsed from 'sensors'", file=sys.stderr)
            sys.exit(1)

    sensors_set = set(sensors)  # Remove duplicates
    ros_distro = args.ros_distro.strip()
    dockerfile = Path(__file__).parent.joinpath('Dockerfile')
    img_id_to_build = args.img_id.strip()

    # Checks on arguments

    # Validate ROS distro
    if ros_distro not in ros_distros:
        print(f"Error: Invalid ROS distro '{ros_distro}'.\n{get_ros_distros_str(ros_distros)}", file=sys.stderr)
        sys.exit(1)

    ros_version = ros_distros[ros_distro]['ros_version']
    ubuntu_version = ros_distros[ros_distro]['ubuntu_version']

    # Dockerfile must exist.
    if not dockerfile.is_file():
        print(f"Error: Dockerfile '{dockerfile}' does not exist or is not a file", file=sys.stderr)
        sys.exit(1)

    # Validate image name.
    if not is_valid_docker_img_name(img_id_to_build):
        print(f"Error: Invalid Docker image name: '{img_id_to_build}'", file=sys.stderr)
        sys.exit(1)

    check_ssh_agent_and_keys()  # Ensure ssh-agent is running and has a key loaded.

    # Create a temporary build context.
    tmp_context_dir = Path(tempfile.mkdtemp(prefix='docker_context_'))

    exit_code = 0  # Return code for the script.

    try:
        try:
            shutil.copy2(
                root_dir.joinpath('install_base_system.sh'), tmp_context_dir.joinpath('install_base_system.sh')
            )
            shutil.copy2(root_dir.joinpath('install_ros.sh'), tmp_context_dir.joinpath('install_ros.sh'))
            shutil.copy2(
                root_dir.joinpath('rosdep_init_update_install.sh'),
                tmp_context_dir.joinpath('rosdep_init_update_install.sh'),
            )
            shutil.copy2(
                root_dir.joinpath('colcon_mixin_metadata.sh'), tmp_context_dir.joinpath('colcon_mixin_metadata.sh')
            )
            shutil.copy2(root_dir.joinpath('entrypoint.sh'), tmp_context_dir.joinpath('entrypoint.sh'))
        except Exception as e:
            raise RuntimeError(f'{e}') from e

        if args.file is not None:
            options_file = Path(args.file).expanduser().resolve()

            if not options_file.is_file():
                raise RuntimeError(f"Error: Options file '{options_file}' does not exist or is not a file")

            if options_file.stat().st_size == 0:
                raise RuntimeError(f"Error: Options file '{options_file}' is empty")

            try:
                shutil.copy2(options_file, tmp_context_dir.joinpath('options.json'))
            except Exception as e:
                raise RuntimeError(
                    f"Error: Could not copy options file '{options_file}' to temporary context: {e}"
                ) from e

        sensors_dir = Path(__file__).parent.joinpath('sensors')

        if not sensors_dir.is_dir():
            raise RuntimeError(f"Error: sensors root not found: '{sensors_dir}'")

        for sensor in sensors_set:
            # Look for the sensor directory under sensors_dir.
            matches = [item for item in sensors_dir.rglob('*') if item.is_dir() and item.name == sensor]

            if not matches:
                raise RuntimeError(f"Error: sensor '{sensor}' not found under '{sensors_dir}'")

            if len(matches) > 1:
                raise RuntimeError(f"Error: multiple matches for sensor '{sensor}': {[str(m) for m in matches]}")

            src_sensor_dir = matches[0]

            dst_sensor_dir = tmp_context_dir.joinpath(sensor)

            # If the destination directory already exists, remove it first. IT SHOULD NOT HAPPEN.
            if dst_sensor_dir.exists():
                shutil.rmtree(dst_sensor_dir, ignore_errors=True)

            shutil.copytree(src_sensor_dir, dst_sensor_dir, dirs_exist_ok=False)

            print(f"Copied sensor '{sensor}': {src_sensor_dir} -> {dst_sensor_dir}")

        # ------------------------------------------------------------------
        # Build command
        # ------------------------------------------------------------------
        # With DOCKER_BUILDKIT enabled, we can use advanced build features like volume mounts, like:
        # RUN --mount=type=bind,source=...,target=... && <command>
        # Ref: https://docs.docker.com/build/buildkit/
        # docker-py doesn't support BuildKit, and has an issue open for almost 6 years
        # (https://github.com/docker/docker-py/issues/2230) so it doesn't seem like it is being added.
        # Therefore, we use the subprocess module to call docker build... so that we can enable
        # BuildKit, and thus mount volume during buil

        os.environ['DOCKER_BUILDKIT'] = '1'

        cmd = [
            'docker',
            'build',
            '--file',
            str(dockerfile),  # original Dockerfile path
            '--progress=plain',
            '--network=host',
            '--add-host=gitlab.local.eurecat.org:172.20.49.120',
            '--ssh=default',
        ]

        if args.pull:
            print(f"--pull specified: Docker will pull/update 'ubuntu:{ubuntu_version}' if needed")
            cmd.append('--pull')

        if not args.cache:
            cmd.append('--no-cache')

        build_args = {'UBUNTU_VERSION': ubuntu_version, 'ROS_DISTRO': ros_distro, 'ROS_VERSION': ros_version}

        for k, v in build_args.items():
            cmd += ['--build-arg', f'{k}={v}']

        labels = {
            'org.opencontainers.image.created': datetime.now(timezone.utc).isoformat(),
            'org.opencontainers.image.title': args.meta_title.strip(),
            'org.opencontainers.image.description': args.meta_desc.strip(),
            'org.opencontainers.image.authors': args.meta_authors.strip(),
        }

        for k, v in labels.items():
            cmd += ['--label', f'{k}={v}']

        cmd += ['--tag', img_id_to_build]
        cmd.append(str(tmp_context_dir))  # use temporary context

        # Run Docker build.
        print(f"Building image '{img_id_to_build}' with Ubuntu '{ubuntu_version}' and 'ROS{ros_version}-{ros_distro}'")

        complete_log_file = Path('/tmp').joinpath(
            f'{img_id_to_build.replace(":", "_").replace("/", "_")}_'
            f'{datetime.now(timezone.utc).strftime("%Y-%m-%d_%H-%M-%S")}.log'
        )

        print('Executing command:\n', ' '.join(cmd), '\n')

        with (
            subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,  # Combine stdout and stderr
                text=True,  # Decode directly to strings
                bufsize=1,  # Enable line buffering for real-time output
            ) as process,
            open(complete_log_file, 'w') as full_log,
        ):
            # Read each line of the subprocess's output as it is produced, i.e., in real-time.
            for line in process.stdout:  # type: ignore
                print(line, end='', flush=True)
                full_log.write(line)  # Full log

            # Ensure the log file is flushed to disk.
            full_log.flush()
            # Wait for the process to finish and check the exit code
            process.wait()

            exit_code = process.returncode

            status = 'SUCCESS' if exit_code == 0 else f'FAILURE (code {exit_code}): {process.stderr.strip()}'  # type: ignore
            print(f'\nDocker build finished: {status}')

            if complete_log_file.stat().st_size:
                print(f"Full log saved to '{complete_log_file}'")
    except KeyboardInterrupt:
        print('Aborted by user (Ctrl+C)')
        exit_code = 1
    except Exception as exc:
        print(f'Error: {exc}', file=sys.stderr)
        exit_code = 1
    finally:
        # Always remove temporary context
        shutil.rmtree(tmp_context_dir, ignore_errors=True)
        sys.exit(exit_code)
