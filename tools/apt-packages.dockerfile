RUN command -v unzip >/dev/null 2>&1 && command -v fish >/dev/null 2>&1 && \
    command -v vim >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1 || \
    (sudo apt-get update && sudo apt-get install -y --no-install-recommends unzip fish vim gnupg && \
     sudo rm -rf /var/lib/apt/lists/*)

# Removes the base image's Debian node/npm (npm 9) and the Debian JavaScript packages that need
# it. node and npm come from mise; the Debian npm was what ran whenever the mise shim could not
# find mise's node (another HOME, e.g. root), and npm 9 silently ignores min-release-age.
# --auto-remove also drops what only node needed (libicu, libssl-dev, ...). Claude Code is a
# native binary and does not use it. Skipped when the base image has no Debian nodejs.
RUN ! dpkg -s nodejs >/dev/null 2>&1 || \
    (sudo apt-get purge -y --auto-remove nodejs npm && sudo rm -rf /var/lib/apt/lists/*)

# Removes the base image's uv (/usr/local/bin/uv, 0.9.x when this was written) so the only uv is
# mise's, pinned in shell-base/mise.toml and locked in mise.lock. Otherwise whichever comes first
# on PATH wins, and the old one runs wherever mise's shims aren't active. Skipped when absent.
RUN for f in /usr/local/bin/uv /usr/local/bin/uvx; do \
      [ ! -e "$f" ] || sudo rm -f "$f"; \
    done

# Upgrades the base image's packages to the current Ubuntu updates (security fixes the image
# doesn't have yet). Last, so it doesn't upgrade node/npm only to purge them above. Like every
# layer it is cached: it only re-runs when an earlier layer changes, e.g. a base image bump.
# Noninteractive and keeping existing config files, so a changed conffile can't stall the build.
RUN sudo apt-get update && \
    sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
      -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold && \
    sudo rm -rf /var/lib/apt/lists/*
