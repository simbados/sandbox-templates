# apt over HTTPS and without retries. The base image (sbx/shell, Debian 13) lists Debian's archive
# and Docker's hardened package repo (dhi.io) as http:// sources in /etc/apt/sources.list.d/*.sources.
# apt checks package signatures either way; HTTPS keeps a man-in-the-middle from serving anything
# at all, and no retries closes the hole where apt trusted a tampered package on a retried
# download. Changing APT_BUMP_DATE re-runs this step and the ones after it.
ARG APT_BUMP_DATE=2026-11-22
RUN echo 'Acquire::Retries "0";' | sudo tee /etc/apt/apt.conf.d/99-no-retries && \
    dpkg -s ca-certificates >/dev/null && \
    sudo sed -i 's|http://|https://|g' /etc/apt/sources.list.d/*.sources && \
    grep -h '^URIs' /etc/apt/sources.list.d/*.sources && \
    apt-config dump | grep Acquire::Retries

# libatomic1 is a runtime library mise's node binaries need ("libatomic.so.1: cannot open shared
# object file") that the minimal base image leaves out. The base image ships vim only as
# /usr/bin/vim.basic: its packages are installed without running their setup scripts, so the usual
# vim/vi links are missing.
RUN sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends libatomic1 && \
    sudo rm -rf /var/lib/apt/lists/* && \
    sudo ln -sf /usr/bin/vim.basic /usr/local/bin/vim && \
    sudo ln -sf /usr/bin/vim.basic /usr/local/bin/vi

# Upgrades the base image's packages to the current Debian and DHI updates (security fixes
# published since the image was built). Like every layer it is cached: it only re-runs when an
# earlier layer changes, e.g. a base image bump. Noninteractive and keeping existing config
# files, so a changed conffile can't stall the build. Change APT_UPGRADE_DATE to force a fresh
# upgrade: a changed ARG invalidates the cache from this step on (a comment doesn't, Docker
# ignores comments when matching layers).
ARG APT_UPGRADE_DATE=2026-11-22
RUN sudo apt-get update && \
    sudo env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
      -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold && \
    sudo rm -rf /var/lib/apt/lists/*
