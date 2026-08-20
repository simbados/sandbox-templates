# The base image ships Debian's own nodejs/npm (apt packages, pinned to whatever
# Ubuntu/Debian currently carries) alongside a long tail of node-* library
# packages that exist only to satisfy it. Left in place, /usr/bin/node sits on
# PATH ahead of nothing in particular and quietly wins over fnm's managed
# install in any shell that hasn't run `fnm env` (e.g. non-interactive
# invocations that never source ~/.bashrc). Purge it so fnm's install below is
# unambiguously the only `node`/`npm` on the system.
RUN sudo apt-get purge -y --autoremove nodejs npm libnode-dev libnode127 handlebars && \
    sudo rm -rf /var/lib/apt/lists/*

RUN set -eu; \
    FNM_VERSION=v1.39.0; \
    case "$(uname -m)" in \
        x86_64) FNM_ASSET=fnm-linux.zip; FNM_SHA256=7807664f39d39fc518da1c35ba0181e4b3267603c4b1dedeb4b5fc6ae440a224 ;; \
        aarch64) FNM_ASSET=fnm-arm64.zip; FNM_SHA256=4eaff58b2c5bf30d0934027572dd0b5bbb60d2a1af309230b53662d4b1d45599 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/fnm.zip "https://github.com/Schniz/fnm/releases/download/${FNM_VERSION}/${FNM_ASSET}"; \
    echo "${FNM_SHA256}  /tmp/fnm.zip" | sha256sum -c -; \
    mkdir -p ~/.local/share/fnm; \
    unzip -q /tmp/fnm.zip -d ~/.local/share/fnm; \
    rm /tmp/fnm.zip

ENV PATH="/home/agent/.local/share/fnm:$PATH"

RUN echo 'eval "$(fnm env --use-on-cd --shell bash)"' >> ~/.bashrc

RUN mkdir -p ~/.config/fish/conf.d && cat <<'EOF' > ~/.config/fish/conf.d/fnm.fish
status is-interactive; and fnm env --use-on-cd --shell fish | source
EOF

# /etc/sandbox-persistent.sh is sourced before every non-interactive shell the
# Bash tool spawns (via BASH_ENV/CLAUDE_ENV_FILE) — those never source
# ~/.bashrc or fish's conf.d, so without this `node`/`npm` would be missing
# there even though fnm is fully installed. No --use-on-cd here deliberately:
# this line reruns before every single command, and --use-on-cd would make
# fnm try to auto-switch to whatever version a directory's package.json/
# .nvmrc pins, hard-failing every command in a directory whose pin isn't
# installed. Just resolve the configured default (the LTS installed below).
RUN echo 'eval "$(fnm env --shell bash)"' >> /etc/sandbox-persistent.sh

RUN eval "$(fnm env --shell bash)" && \
    fnm install --lts && \
    fnm default lts-latest
