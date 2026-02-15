#!/usr/bin/env python3

import argparse
import getpass
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Union  # noqa: UP035

# Supported ROS distros.
ros_distros: Dict[str, Dict[str, Union[str, int]]] = {
    'humble': {'ros_version': 2, 'ubuntu_version': '22.04'},
    'jazzy': {'ros_version': 2, 'ubuntu_version': '24.04'},
}


def is_valid_docker_img_name(name: str) -> bool:
    """
    Validate a Docker image name according to Docker's official naming rules.

    Format:
        [HOST[:PORT_NUMBER]/]PATH[:TAG]

    See: https://docs.docker.com/get-started/docker-concepts/building-images/build-tag-and-publish-an-image/#tagging-images
    """
    host_and_port_prefix = r'([a-z0-9.-]+(:[0-9]+)?/)?'
    path_separator = r'(?:\.|_{1,2}|-+)'
    path_component = rf'[a-z0-9]+(?:{path_separator}[a-z0-9]+)*'
    path_re = rf'{path_component}(/{path_component})*'
    tag_re = r'(:[a-zA-Z0-9_.-]+)?'
    full_re = re.compile(rf'^{host_and_port_prefix}{path_re}{tag_re}$')
    return bool(full_re.match(name))


if __name__ == '__main__':
    this_file = Path(__file__).resolve()
    examples_dir = this_file.parent
    livox_gen2_dir = examples_dir.parent
    lidars_dir = livox_gen2_dir.parent
    sensors_dir = lidars_dir.parent
    project_dir = sensors_dir.parent
    base_docker_files_dir = project_dir.joinpath('base_docker_files')

    parser = argparse.ArgumentParser(
        description=('Script to build a Docker image to run the ROS2 driver for Livox Gen2 LiDARs.\n\n'),
        allow_abbrev=False,
        add_help=False,
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

    parser.add_argument('ros_distro', type=str, help=(f'Supported ROS distros: {", ".join(ros_distros.keys())}'))

    default_img_id = 'livox_gen2:<ros_distro>'
    parser.add_argument('--img-id', type=str, default='', help=f'Built Docker image ID. Default: {default_img_id}')

    parser.add_argument(
        '--meta-title', type=str, default='Docker image to run a sensor with ROS', help='Image title for OCI metadata'
    )

    parser.add_argument(
        '--meta-desc',
        type=str,
        default='A Docker image to run a sensor with ROS',
        help='Image description for OCI metadata',
    )
    parser.add_argument('--meta-authors', default=getpass.getuser(), help='Image authors')

    args = parser.parse_args()
    ros_distro = args.ros_distro.strip()

    if ros_distro not in ros_distros:
        print(f"Error: Invalid ROS distro '{ros_distro}'", file=sys.stderr)
        print(f'Supported distros are: {", ".join(ros_distros.keys())}', file=sys.stderr)
        sys.exit(1)

    ros_version = ros_distros[ros_distro]['ros_version']
    ubuntu_version = ros_distros[ros_distro]['ubuntu_version']

    img_id_to_build = args.img_id.strip()
    if not img_id_to_build:
        img_id_to_build = default_img_id.replace('<ros_distro>', ros_distro)

    if not is_valid_docker_img_name(img_id_to_build):
        print(f"Error: Invalid Docker image name: '{img_id_to_build}'", file=sys.stderr)
        sys.exit(1)

    dockerfile = examples_dir.joinpath('Dockerfile')
    if not dockerfile.is_file():
        print(f"Error: Dockerfile '{dockerfile}' does not exist or is not a file", file=sys.stderr)
        sys.exit(1)

    tmp_context_dir = Path(tempfile.mkdtemp(dir='/tmp', prefix='docker_context_'))
    tmp_context_dir.mkdir(parents=True, exist_ok=True)

    exit_code = 0

    for file in base_docker_files_dir.iterdir():
        if file.is_file():
            try:
                shutil.copy2(file, tmp_context_dir.joinpath(file.name))
            except Exception as e:
                print(f'Error copying {file} to {tmp_context_dir}: {e}')

    shutil.copy2(livox_gen2_dir.joinpath('setup.sh'), tmp_context_dir.joinpath('setup.sh'))
    shutil.copy2(examples_dir.joinpath('refs.txt'), tmp_context_dir.joinpath('refs.txt'))
    shutil.copy2(livox_gen2_dir.joinpath('compile.sh'), tmp_context_dir.joinpath('compile.sh'))
    shutil.copy2(livox_gen2_dir.joinpath('eut_sensor.launch.py'), tmp_context_dir.joinpath('eut_sensor.launch.py'))

    os.environ['DOCKER_BUILDKIT'] = '1'

    cmd = [
        'docker',
        'build',
        '--file',
        str(dockerfile),
        '--progress=plain',
        '--network=host',
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
    cmd.append(str(tmp_context_dir))

    print(
        f"Building image '{img_id_to_build}' with Ubuntu '{ubuntu_version}' and 'ROS{ros_version}-{ros_distro}' using "
        f"temporary context at '{tmp_context_dir}'"
    )

    complete_log_file = Path('/tmp').joinpath(
        f'{img_id_to_build.replace(":", "_").replace("/", "_")}_'
        f'{datetime.now(timezone.utc).strftime("%Y-%m-%d_%H-%M-%S")}.log'
    )

    print('Executing command:\n', shlex.join(cmd), '\n')

    try:
        with (
            subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                bufsize=1,
            ) as process,
            open(complete_log_file, 'w') as full_log,
        ):
            for line in process.stdout:  # type: ignore
                print(line, end='', flush=True)
                full_log.write(line)

            full_log.flush()
            process.wait()

            exit_code = process.returncode
            status = 'SUCCESS' if exit_code == 0 else f'FAILURE (code {exit_code})'
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
        shutil.rmtree(tmp_context_dir, ignore_errors=True)
        sys.exit(exit_code)
