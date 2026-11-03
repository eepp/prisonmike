# Prison Mike

<p align="center">
  <img src="prisonmike.jpg" alt="Prison Mike: the worst thing about prison was the bind mounts" width="500">
</p>

_**Prison Mike**_ is [Claude Code](https://claude.ai/code) in a
throwaway Docker container which only sees `~/dev`, `~/lttng-traces`,
`~/.herdr`, the state of Claude Code, and a few read-only config files
of the host home directory.

The goal is to keep what Claude Code can read and write away from the
rest of the home directory (other SSH keys, credentials, browser
cookies, and the rest) while still offering a complete
development environment.

Compatible with [Herdr](https://herdr.dev/)!

> [!NOTE]
> This is custom for my own needs! My user name, my Gerrit server, the
> packages I need to work on my projects, my host paths, and
> so on are hardcoded. Feel free to take ideas from it, but expect to
> adapt it.

## What's here

| Path                  | Description                                                                                                  |
|-----------------------|--------------------------------------------------------------------------------------------------------------|
| `Dockerfile`          | Arch Linux image with the development packages, a user matching the host one, and Claude Code.             |
| `prisonmike.zsh`      | Launcher to run Claude Code in a new container with the right bind mounts and then remove it.                  |
| `clip/xclip`          | `xclip` replacement within the container which sends what it copies to the host.                            |
| `clip/clip-client.py` | Sends its standard input to the clipboard server through a Unix socket.                                     |
| `clip/clip-server.py` | Runs on the host to receive messages from the socket and put them in the X clipboard with the real `xclip`. |
| `ssh/config`          | SSH configuration of the image: only `review.lttng.org`, only with the Gerrit key.                          |
| `ssh/known_hosts`     | Public host key of `review.lttng.org`.                                                                       |

## Build the image

```sh
docker build -t prisonmike:latest .
```

Build arguments:

* `USER_NAME`, `USER_UID`, `USER_GID`: user of the container (default:
  `eepp`, 1000, 1000), which must match the host user so that file
  ownership within `~/dev` stays correct.

* `CLAUDE_CODE_VERSION`: version of Claude Code to install
  (default: `latest`).

The image doesn't update Claude Code by itself: rebuild it (with
`--no-cache` to get a new `latest`) to update.

## Run

From any directory within `~/dev`, within `~/.herdr`, or within a
subdirectory of `/tmp`:

```sh
zsh /path/to/prisonmike.zsh [CLAUDE-ARGS...]
```

I keep

```sh
alias pm='zsh /path/to/prisonmike.zsh'
```

The launcher:

1. Checks that Docker is running and that the CWD is within `~/dev`,
   within `~/.herdr`, or within a subdirectory of `/tmp`.

2. Starts the clipboard server on the host.

3. Runs Claude Code in a new container with the CWD as
   its working directory.

4. Removes the container and stops the clipboard server when Claude Code
   exits.

### What the container sees

Read/write:

* `~/dev`
* `~/lttng-traces`
* `~/.herdr` (Herdr state, including its worktrees)
* `~/.claude` and `~/.claude.json` (Claude Code state)
* If the CWD is within a subdirectory of `/tmp`: that
  first-level subdirectory (for example, `/tmp/meow` when the CWD
  is `/tmp/meow/mix`), but not the rest of `/tmp`

Read-only:

* `~/.gitconfig` and `~/.config/git`
* `~/.config/clangd`
* `~/.ssh/id_ed25519.gerrit` (the only SSH key)
* `/opt/clang-format-static` (pinned `clang-format` versions)
* `/etc/localtime`

Host paths which don't exist are skipped.

The container doesn't see `~/.config/herdr`: it contains the control
socket of Herdr (which can run commands on the host), a link to the SSH
agent socket, and the session state.

## Host requirements

* Docker
* Zsh
* Python 3
* `xclip` and an X server (for the clipboard)

Prison Mike assumes that the host and the container run the same,
compatible distribution (Arch Linux, both up to date): the container
and the host share `~/dev` and `/opt/clang-format-static`, so what one
builds (executables, libraries, Python virtual environments) must work
on the other.
