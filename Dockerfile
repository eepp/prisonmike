FROM archlinux:latest

ARG USER_NAME=eepp
ARG USER_UID=1000
ARG USER_GID=1000
ARG CLAUDE_CODE_VERSION=latest

# Keep man pages, docs, and locales, which the base image strips, then
# upgrade the whole system.
#
# Reinstall `glibc` to get the locale definitions back.
RUN sed -i '/^NoExtract/d' /etc/pacman.conf && \
    pacman -Sy --noconfirm archlinux-keyring && \
    pacman -Su --noconfirm && \
    pacman -S --noconfirm glibc

# Install the development packages
RUN pacman -S --needed --noconfirm \
           # Build tooling
           base-devel autoconf-archive cmake meson ninja ccache bear clang lld \
           # Debugging
           gdb valgrind strace \
           # Babeltrace
           glib2 elfutils fmt swig python-setuptools catch2 \
           # LTTng-UST and LTTng-tools
           liburcu popt libxml2 kmod numactl jdk-openjdk \
           # Docs
           asciidoc asciidoctor xmlto doxygen python-sphinx \
           # Python
           python python-pip uv python-pytest python-pytest-xdist python-black \
           ruff pyright \
           # Shell scripts
           shellcheck zsh \
           # General tools
           git openssh the_silver_searcher ripgrep fd fzf bat tig jq curl wget \
           less man-db man-pages vim procps-ng psmisc lsof which diffutils \
           file tree kitty-terminfo && \
    rm -rf /var/cache/pacman/pkg/*

# Generate the locales
RUN printf '%s\n' 'en_CA.UTF-8 UTF-8' 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen

# Create the user
RUN groupadd --gid "$USER_GID" "$USER_NAME" && \
    useradd --create-home --uid "$USER_UID" --gid "$USER_GID" \
            --shell /bin/bash "$USER_NAME"

# Run the following as the user, from its home directory
USER $USER_NAME
WORKDIR /home/$USER_NAME

# Environment (update Claude Code by rebuilding the image; no
# background sessions/daemon, which would die with the container)
ENV PATH=/home/$USER_NAME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/opt/clang-format-static \
    LANG=en_CA.UTF-8 \
    SHELL=/bin/bash \
    DISABLE_AUTOUPDATER=1 \
    CLAUDE_CODE_DISABLE_AGENT_VIEW=1

# Install Claude Code into `~/.local`.
#
# Remove what the installer writes to `~/.claude*`: the launcher
# bind-mounts the host versions over them.
RUN curl -fsSL https://claude.ai/install.sh | bash -s "$CLAUDE_CODE_VERSION" && \
    rm -rf ~/.claude ~/.claude.json && \
    mkdir ~/.claude ~/dev

# SSH: Gerrit only with the key which `prisonmike` mounts
RUN mkdir -m 700 ~/.ssh
COPY --chown=$USER_UID:$USER_GID --chmod=600 ssh/config ssh/known_hosts .ssh/

# `xclip` wrapper and its client, which send what it copies to the host
# clipboard through the socket which `prisonmike` mounts
COPY --chmod=755 clip/xclip clip/clip-client.py /usr/local/bin/

# Default command just in case
CMD ["claude"]
