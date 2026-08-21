# Bare base images (e.g. plain ubuntu) have no non-root user. Every other
# tools/*.dockerfile fragment assumes USER agent with home /home/agent and
# passwordless sudo (see the hardcoded /home/agent paths in temurin.dockerfile
# and fnm.dockerfile, and apt-packages.dockerfile's `sudo apt-get`), so this
# fragment must run first, as root, to create that before anything else does.
RUN apt-get update && \
    apt-get install -y --no-install-recommends sudo ca-certificates curl git && \
    rm -rf /var/lib/apt/lists/* && \
    useradd --create-home --shell /bin/bash agent && \
    echo 'agent ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/agent && \
    chmod 0440 /etc/sudoers.d/agent

USER agent
