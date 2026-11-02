#!/usr/bin/env zsh
#
# Runs Claude Code in a throwaway Docker container which only sees
# `~/dev`, Claude Code's own state, and a few read-only configuration
# files of the host home directory.
#
# Usage:
#
#     zsh prisonmike.zsh [CLAUDE-ARGS...]
#
# Run it from a directory within `~/dev` or within a subdirectory of
# `/tmp`. In the latter case, the container also sees that first-level
# subdirectory of `/tmp` (for example, `/tmp/meow` when the current
# directory is `/tmp/meow/mix`), but not the rest of `/tmp`.
#
# The container stops and is removed as soon as Claude Code exits.
#
# What `xclip` copies within the container lands in the X clipboard of
# the host (see `clip/clip-server.py`).

setopt err_exit no_unset pipe_fail

readonly dev_dir=$HOME/dev
readonly script_dir=${0:A:h}

die() {
    print -Pru2 -- "%B%F{white}%K{red}ERROR: Prison Mike: ${*//\%/%%}%k%f%b"
    exit 1
}

# A few checks
if ! docker info &> /dev/null; then
    die 'No Docker daemon yo!'
fi

# Subdirectory of `/tmp` to bind, if the CWD is within one
tmp_subdir=

if [[ $PWD/ != $dev_dir/* ]]; then
    if [[ $PWD != /tmp/?* ]]; then
        die "CWD isn't within \`$dev_dir\` or within a subdirectory of \`/tmp\`"
    fi

    tmp_subdir=/tmp/${${PWD#/tmp/}%%/*}
fi

readonly tmp_subdir

# Claude Code must find its global configuration file on the host,
# otherwise it would create it within the container and lose it.
if [[ ! -e $HOME/.claude.json ]]; then
    print '{}' > $HOME/.claude.json
fi

readonly container_name=prisonmike-$$

# Clipboard server socket directory
readonly clip_dir=${XDG_RUNTIME_DIR:-/tmp}/$container_name

args=(
    --rm --interactive --tty --init
    --pull=never
    --name=$container_name
    --hostname=prisonmike
    --user=$UID:$GID
    --security-opt=no-new-privileges
    --workdir=$PWD
    --env=TERM --env=COLORTERM --env=LANG --env=LC_CTYPE
    --shm-size=2g
)

# Bind-mounts the host path `$1` at the same path within the container,
# with the option `$2` (for example `ro`) if it exists.
bind() {
    if [[ -e $1 ]]; then
        args+=(--volume="$1:$1${2:+:$2}")
    fi
}

# Read/write: the source trees and Claude Code's state
bind $dev_dir
bind $HOME/.claude
bind $HOME/.claude.json

# Read/write: the current subdirectory of `/tmp`, if any, but not the
# rest of `/tmp`.
if [[ -n $tmp_subdir ]]; then
    bind $tmp_subdir
fi

# Read-only: the clipboard scripts of Prison Mike, as the host
# runs `clip/clip-server.py`.
bind $script_dir/clip ro

# Clipboard: socket directory, at a fixed path for the `xclip` wrapper
# of the image.
args+=(--volume=$clip_dir:/run/prisonmike)

# Read-only: config
bind $HOME/.gitconfig ro
bind $HOME/.config/git ro
bind $HOME/.config/clangd ro
bind /etc/localtime ro

# Read-only: Gerrit SSH key (the only one; the image has the SSH config)
bind $HOME/.ssh/id_ed25519.gerrit ro

# Pinned clang-format versions
bind /opt/clang-format-static ro

# On exit, remove the container, in case the Docker client died without
# the container exiting (for example, when the terminal closes), then
# stop the clipboard server and remove its socket directory.
#
# Exit on SIGHUP/SIGTERM so that the `EXIT` trap runs.
clip_server_pid=

cleanup() {
    docker rm --force $container_name &> /dev/null || true

    if [[ -n $clip_server_pid ]]; then
        kill $clip_server_pid &> /dev/null || true
    fi

    rm -rf $clip_dir || true
}

trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 143' TERM

# Start the clipboard server.
#
# Create the socket directory now, otherwise Docker would create it
# as `root`.
#
# `setpriv --pdeathsig` makes the kernel terminate the server if this
# script dies without running its `EXIT` trap (for example,
# on `SIGKILL`).
mkdir -m 700 $clip_dir
setpriv --pdeathsig=TERM python3 $script_dir/clip/clip-server.py $clip_dir/clip.sock < /dev/null &> /dev/null &
clip_server_pid=$!

# And finally Claude Code.
#
# `HERDR_AGENT` makes Herdr treat the Docker client as Claude Code.
print -Pru2 -- "%S%BPrison Mike%b: entering container \`$container_name\`%s"
ret=0
HERDR_AGENT=claude docker run $args prisonmike:latest claude "$@" || ret=$?
print -Pru2 -- "%S%BPrison Mike%b: left container \`$container_name\` with exit status $ret%s"
exit $ret
