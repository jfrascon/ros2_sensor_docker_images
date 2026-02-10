#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $(basename "${BASH_SOURCE[0]}") [--remote-ref <ref>] <clone_dir> [--help | -h]

Description:
  Clone librealsense2 and run the Ubuntu LTS HWE kernel patch script.

Options:
  --remote-ref <ref>  Branch or tag to clone (example: master or v2.56.5).
  -h, --help          Show this help message.

Arguments:
  clone_dir           Destination directory for the cloned repository.

Notes:
  - If --remote-ref is not provided, the latest published tag is used (GitHub releases/latest).
EOF
}

log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%d_%H-%M-%S')" "$*"; }

require_cmd() {
    local cmd="$1"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        log "ERROR: Missing required command: ${cmd}"
        exit 1
    fi
}

# Minimal prerequisites required before argument parsing
require_cmd getopt
require_cmd git
require_cmd curl

SHORT_OPTS="h"
LONG_OPTS="help,remote-ref:"
PARSED_ARGS="$(getopt --options "${SHORT_OPTS}" --longoptions "${LONG_OPTS}" --name "$0" -- "$@")" || {
    usage
    exit 2
}

eval set -- "${PARSED_ARGS}"

REMOTE_REF=""
while true; do
    case "$1" in
    --remote-ref)
        REMOTE_REF="$2"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *)
        log "ERROR: Unexpected option: $1"
        usage
        exit 2
        ;;
    esac
done

if [ "$#" -ne 1 ]; then
    log "ERROR: Expected 1 positional argument: <clone_dir>. Got: $*"
    usage
    exit 2
fi

CLONE_DIR="${1}"

if [ -d "${CLONE_DIR}" ]; then
    log "ERROR: Destination directory already exists: ${CLONE_DIR}. Please remove it or choose a new destination."
    exit 1
fi

parent_dir="$(dirname "${CLONE_DIR}")"
mkdir --parent --verbose "${parent_dir}"
cd "${parent_dir}" # Set current directory

remote_repo="https://github.com/realsenseai/librealsense.git"
local_repo="${CLONE_DIR}"

# Determine which git ref to clone: use --remote-ref when provided, otherwise use the latest release tag.
if [ -n "${REMOTE_REF}" ]; then
    EFFECTIVE_REF="${REMOTE_REF}"
    REF_KIND="remote ref"
else
    if ! latest_release_json="$(curl -fsSL https://api.github.com/repos/realsenseai/librealsense/releases/latest)"; then
        log "ERROR: Failed to query GitHub API for the latest librealsense release."
        exit 1
    fi
    EFFECTIVE_REF="$(printf '%s\n' "${latest_release_json}" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)"

    if [ -z "${EFFECTIVE_REF}" ]; then
        log "ERROR: Could not resolve latest release tag from GitHub API."
        exit 1
    fi

    REF_KIND="tag (latest release)"
fi

log "Cloning librealsense using ${REF_KIND}: ${EFFECTIVE_REF}"
# --depth 1: Clone only the latest commit to save time and bandwidth, as we don't need the full history for this use
# case.
git clone --branch "${EFFECTIVE_REF}" --depth 1 "${remote_repo}" "${local_repo}"

# Free space for Docker image builds; VCS history is not required.
rm -rf "${local_repo}/.git"

# Patch the kernel modules for Ubuntu LTS using the librealsense scripts directory.
log "Patching kernel modules for Ubuntu LTS."
bash "${local_repo}/scripts/patch-realsense-ubuntu-lts-hwe.sh"
