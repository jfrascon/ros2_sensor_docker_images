#!/usr/bin/env python3

import argparse
import getpass
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Union  # noqa: UP035

# Supported ROS distros.
ros_distros: Dict[str, Dict[str, Union[str, int]]] = {
    'humble': {'ros_version': 2, 'ubuntu_version': '22.04'},
    'jazzy': {'ros_version': 2, 'ubuntu_version': '24.04'},
}

# ----------------------------------------------------------------------
# Helper functions
# ----------------------------------------------------------------------


def is_valid_docker_img_name(name: str) -> bool:
    """
    Validate a Docker image name according to Docker's official naming rules.

    Format:
        [HOST[:PORT_NUMBER]/]PATH[:TAG]

    See: https://docs.docker.com/get-started/docker-concepts/building-images/build-tag-and-publish-an-image/#tagging-images
    """
    # Optional registry prefix: host (lower-case letters, digits, dots, dashes)
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


# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

if __name__ == '__main__':
    this_file = Path(__file__).resolve()
    example_dir = this_file.parent
    parser = argparse.ArgumentParser(
        description=(
            'Script to build a ROS2 multi-sensor Docker image (IMU UMX + Livox Gen2 LiDAR + Robosense LiDAR).\n\n'
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

    parser.add_argument('ros_distro', type=str, help=(f'Supported ROS distros: {", ".join(ros_distros.keys())}'))

    default_img_id = 'um_livox_gen2_lidar_robosense_lidar:<ros_distro>'
    parser.add_argument('--img-id', type=str, default='', help=f'Built Docker image ID. Default: {default_img_id}')

    parser.add_argument(
        '--meta-title', type=str, default='Docker image to run sensors with ROS', help='Image title for OCI metadata'
    )

    parser.add_argument(
        '--meta-desc',
        type=str,
        default='A Docker image to run multiple sensors with ROS',
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

    # Validate image name.
    img_id_to_build = args.img_id.strip()

    # If no value is provided for the flag --img-id, use the default one.
    if not img_id_to_build:
        img_id_to_build = default_img_id.replace('<ros_distro>', ros_distro)

    if not is_valid_docker_img_name(img_id_to_build):
        print(f"Error: Invalid Docker image name: '{img_id_to_build}'", file=sys.stderr)
        sys.exit(1)

    # Dockerfile must exist.
    dockerfile = example_dir.joinpath('Dockerfile')

    if not dockerfile.is_file():
        print(f"Error: Dockerfile '{dockerfile}' does not exist or is not a file", file=sys.stderr)
        sys.exit(1)

    # ------------------------------------------------------------------
    # Build command
    # ------------------------------------------------------------------
    os.environ['DOCKER_BUILDKIT'] = '1'

    cmd = [
        'docker',
        'build',
        '--file',
        str(dockerfile),  # original Dockerfile path
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
    cmd.append(str(example_dir))  # use example folder as build context

    # Run Docker build.
    print(f"Building image '{img_id_to_build}' with Ubuntu '{ubuntu_version}' and 'ROS{ros_version}-{ros_distro}'")

    print('Executing command:\n', shlex.join(cmd), '\n')

    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as exc:
        print(f'Error: Docker build failed with exit code {exc.returncode}', file=sys.stderr)
        sys.exit(exc.returncode)
