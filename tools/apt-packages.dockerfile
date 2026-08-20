RUN command -v unzip >/dev/null 2>&1 && command -v fish >/dev/null 2>&1 && \
    command -v vim >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1 || \
    (sudo apt-get update && sudo apt-get install -y --no-install-recommends unzip fish vim gnupg && \
     sudo rm -rf /var/lib/apt/lists/*)
