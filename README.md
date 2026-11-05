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

<table>
  <tr>
    <th>Path</th>
    <th>Description</th>
  </tr>
  <tr>
    <td><code>Dockerfile</code></td>
    <td>
      Arch Linux image with the development packages, a user matching
      the host one, and Claude Code.
    </td>
  </tr>
  <tr>
    <td><code>prisonmike.zsh</code></td>
    <td>
      Launcher to run Claude Code in a new container with the right bind
      mounts and then remove it.
    </td>
  </tr>
  <tr>
    <td><code>clip/xclip</code></td>
    <td>
      Copied to <code>/usr/local/bin/xclip</code> in the container.
      <br><br>
      This is an <code>xclip</code> replacement within the container
      which sends what it copies to the host.
      <br><br>
      Pair this with a "copy to clipboard" skill which indicates to
      always use <code>xclip</code> (through standard input) without
      looking at it.
    </td>
  </tr>
  <tr>
    <td><code>clip/clip-client.py</code></td>
    <td>
      Copied to <code>/usr/local/bin/clip-client.py</code> in the
      container.
      <br><br>
      Sends its standard input to the clipboard server through a
      Unix socket.
    </td>
  </tr>
  <tr>
    <td><code>clip/clip-server.py</code></td>
    <td>
      Runs on the host (<code>prisonmike.zsh</code> spawns it) to
      receive messages from the socket and put them in the X clipboard
      with the host's real <code>xclip</code>.
    </td>
  </tr>
  <tr>
    <td><code>ssh/config</code></td>
    <td>
      Copied to <code>~/.ssh/config</code> in the container.
      <br><br>
      SSH configuration of the image: only
      <code>review.lttng.org</code>, only with the Gerrit key.
    </td>
  </tr>
  <tr>
    <td><code>ssh/known_hosts</code></td>
    <td>
      Copied to <code>~/.ssh/known_hosts</code> in the container.
      <br><br>
      Public host key of <code>review.lttng.org</code>.
    </td>
  </tr>
</table>

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

### Useful Zsh stuff

I keep:

```sh
alias pm='zsh /path/to/prisonmike.zsh'
alias pm-tmp='cd "$(mktemp -d)" && pm'
```

My goal is to avoid at all cost starting Claude Code anywhere outside
the whitelisted directories, therefore I also have:

```sh
claude() {
  echo 'Use `pm` instead!' >&2
  return 1
}
```

If really needed, at your own risk:

```sh
alias the-real-claude='~/.local/bin/claude'
```

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
