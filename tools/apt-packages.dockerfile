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
