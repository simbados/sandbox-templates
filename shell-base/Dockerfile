# GENERATED FILE - do not edit directly.
#
# Edit the fragments in tools/ (and this template's template.yaml / prelude
# fragment), then regenerate with:
#   python3 scripts/generate_dockerfile.py base-ubuntu

FROM docker/sandbox-templates:shell@sha256:c183a8ba03cdb30011c73f555c773c5712b84c6ea066f18409253dcab2cfe799

# Idempotent if the current template already switched to agent earlier in
# its tools list (e.g. via generic-tools): re-selecting the same user is a
# no-op. Kept here because templates whose base image ships agent already
# (no generic-tools needed) still need this before ~ is touched below.
USER agent

RUN mkdir -p ~/.config/pnpm ~/.config/uv && \
    cat <<'EOF' >> ~/.npmrc
# --- managed by config/setup.sh ---
min-release-age=7
ignore-scripts=true
update-notifier=false
allow-directory=root
allow-file=root
allow-remote=root
# --- end config/setup.sh ---
EOF

RUN cat <<'EOF' > ~/.config/pnpm/config.yaml
minimumReleaseAge: 10080

minimumReleaseAgeStrict: true

trustPolicy: no-downgrade

blockExoticSubdeps: true
EOF

RUN cat <<'EOF' > ~/.config/uv/uv.toml
exclude-newer = "7 days"
EOF

RUN command -v unzip >/dev/null 2>&1 && command -v fish >/dev/null 2>&1 && \
    command -v vim >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1 || \
    (sudo apt-get update && sudo apt-get install -y --no-install-recommends unzip fish vim gnupg && \
     sudo rm -rf /var/lib/apt/lists/*)

# Some base images (e.g. docker/sandbox-templates:claude-code-docker) ship
# nodejs/npm pre-installed via apt (pinned to whatever Ubuntu currently
# carries) alongside a long tail of node-* library packages that exist only
# to satisfy it. Left in place, /usr/bin/node sits on PATH ahead of nothing
# in particular and quietly wins over fnm's managed install in any shell
# that hasn't run `fnm env` (e.g. non-interactive invocations that never
# source ~/.bashrc). Purge it so fnm's install below is unambiguously the
# only `node`/`npm` on the system. Other bases (e.g. plain ubuntu) never had
# these packages installed, so `apt-get purge` on them would error "Unable
# to locate package" - only purge what dpkg actually shows as installed.
RUN installed="$(dpkg-query -W -f='${Package}\n' nodejs npm libnode-dev libnode127 handlebars 2>/dev/null)" && \
    if [ -n "$installed" ]; then sudo apt-get purge -y --autoremove $installed; fi; \
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
# Only some base images (e.g. docker/sandbox-templates:claude-code-docker)
# bake this file in at a path agent can write; others don't ship it at all,
# so skip rather than fail the build when it's absent.
RUN if [ -f /etc/sandbox-persistent.sh ]; then \
        echo 'eval "$(fnm env --shell bash)"' >> /etc/sandbox-persistent.sh; \
    fi

RUN eval "$(fnm env --shell bash)" && \
    fnm install --lts && \
    fnm default lts-latest

RUN set -eu; \
    FZF_VERSION=v0.74.3; \
    ZOXIDE_VERSION=v0.10.0; \
    case "$(uname -m)" in \
        x86_64) \
            FZF_ASSET=fzf-0.74.3-linux_amd64.tar.gz; \
            FZF_SHA256=3501a595e4b5c40a6b047340a0e8f805c46fd4e61ef95ef8a136ba8c61cf6f22; \
            ZOXIDE_ASSET=zoxide-0.10.0-x86_64-unknown-linux-musl.tar.gz; \
            ZOXIDE_SHA256=2d93385b99f3e82cf2701609a1bffcad863fbeb75aa3fe7eb6be4d29be68b1ae ;; \
        aarch64) \
            FZF_ASSET=fzf-0.74.3-linux_arm64.tar.gz; \
            FZF_SHA256=4a17a17b46bd0c4873e995533de508995c11572c0be0664a5dbcf13f60463046; \
            ZOXIDE_ASSET=zoxide-0.10.0-aarch64-unknown-linux-musl.tar.gz; \
            ZOXIDE_SHA256=f1f16c5d6298d63dee467eedea1cdcd8490e43e493bea43acd416dc9033ef641 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    mkdir -p ~/.local/bin; \
    curl -fsSL -o /tmp/fzf.tar.gz "https://github.com/junegunn/fzf/releases/download/${FZF_VERSION}/${FZF_ASSET}"; \
    echo "${FZF_SHA256}  /tmp/fzf.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/fzf.tar.gz -C ~/.local/bin fzf; \
    rm /tmp/fzf.tar.gz; \
    curl -fsSL -o /tmp/zoxide.tar.gz "https://github.com/ajeetdsouza/zoxide/releases/download/${ZOXIDE_VERSION}/${ZOXIDE_ASSET}"; \
    echo "${ZOXIDE_SHA256}  /tmp/zoxide.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/zoxide.tar.gz -C ~/.local/bin zoxide; \
    rm /tmp/zoxide.tar.gz; \
    chmod +x ~/.local/bin/fzf ~/.local/bin/zoxide

# ~/.local/bin only reaches PATH by default through bash's stock ~/.profile
# (login shells) - fish has no equivalent, and this is a Docker ENV (not a
# shell dotfile) specifically so it applies to every shell uniformly,
# including fish and uv.dockerfile's later install into the same directory.
ENV PATH="/home/agent/.local/bin:$PATH"

RUN printf '%s\n%s\n' 'eval "$(fzf --bash)"' 'eval "$(zoxide init bash)"' >> ~/.bashrc

RUN mkdir -p ~/.config/fish/conf.d && cat <<'EOF' > ~/.config/fish/conf.d/fzf-zoxide.fish
status is-interactive; and fzf --fish | source
status is-interactive; and zoxide init fish | source
EOF

# Eclipse Temurin 25 (latest LTS), pulled directly from Adoptium's own GitHub releases,
# sha256-verified, and GPG-verified against Adoptium's vendored signing key (keys/adoptium-temurin.asc,
# fingerprint 3B04D753C9050D9A5D343F39843C48A565F8F04B - confirmed against the .sig packet metadata,
# Adoptium's own official container build, and a live keyserver fetch). This is the same source
# SDKMAN's own broker redirects to for this candidate, just fetched with real integrity verification
# and without SDKMAN's per-candidate "post-installation hook" mechanism (a remote script fetched and
# sourced on every install; see prior investigation). Installed ahead of the base image's existing
# OpenJDK on PATH so `java` resolves to this build. Requires gnupg (from apt-packages.dockerfile).
COPY --chown=agent:agent keys/adoptium-temurin.asc /tmp/adoptium-temurin.asc

RUN set -eu; \
    TEMURIN_VERSION=jdk-25.0.4+7; \
    case "$(uname -m)" in \
        x86_64) TEMURIN_ASSET=OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz; TEMURIN_SHA256=e58fcdcd637b25c03ca84cbbcefc70d11efb8f4b4cbd05decc9f661769d77f94 ;; \
        aarch64) TEMURIN_ASSET=OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.4_7.tar.gz; TEMURIN_SHA256=621f7196f0b682fb557da58bec89bd7dfe5419811fe1c0ba75c9cc8432f084c7 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/temurin.tar.gz "https://github.com/adoptium/temurin25-binaries/releases/download/${TEMURIN_VERSION}/${TEMURIN_ASSET}"; \
    curl -fsSL -o /tmp/temurin.tar.gz.sig "https://github.com/adoptium/temurin25-binaries/releases/download/${TEMURIN_VERSION}/${TEMURIN_ASSET}.sig"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --import /tmp/adoptium-temurin.asc; \
    gpg --batch --verify /tmp/temurin.tar.gz.sig /tmp/temurin.tar.gz; \
    rm -rf "$GNUPGHOME" /tmp/temurin.tar.gz.sig /tmp/adoptium-temurin.asc; \
    echo "${TEMURIN_SHA256}  /tmp/temurin.tar.gz" | sha256sum -c -; \
    mkdir -p ~/.local/share/temurin; \
    tar -xzf /tmp/temurin.tar.gz --strip-components=1 -C ~/.local/share/temurin; \
    rm /tmp/temurin.tar.gz

ENV JAVA_HOME="/home/agent/.local/share/temurin"
ENV PATH="/home/agent/.local/share/temurin/bin:$PATH"

RUN eval "$(fnm env --shell bash)" && \
    npm install -g pnpm

RUN set -eu; \
    UV_VERSION=0.12.5; \
    case "$(uname -m)" in \
        x86_64) UV_ASSET=uv-x86_64-unknown-linux-gnu.tar.gz; UV_SHA256=68a509da24b06b4223a1c0175fb5eb5bc79342b76cbeff0cfe51ac3f5b17b6b2 ;; \
        aarch64) UV_ASSET=uv-aarch64-unknown-linux-gnu.tar.gz; UV_SHA256=9bf43b4d1a07665bf64d4c4e710930b382321a785e0eb10aac07f46471f86a31 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/uv.tar.gz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_ASSET}"; \
    echo "${UV_SHA256}  /tmp/uv.tar.gz" | sha256sum -c -; \
    mkdir -p ~/.local/bin; \
    tar -xzf /tmp/uv.tar.gz --strip-components=1 -C ~/.local/bin "${UV_ASSET%.tar.gz}/uv" "${UV_ASSET%.tar.gz}/uvx"; \
    rm /tmp/uv.tar.gz
