# GENERATED FILE - do not edit directly.
#
# Edit the fragments in tools/ (and this kit's template.yaml), then regenerate with:
#   python3 scripts/generate_dockerfile.py shell-base

FROM sbx/shell:1.1.0@sha256:036c56158d78d741238079a4db9e36f072e6d047eb89debffab700b8cb0c3a96

# The base image ships the agent user; switch to it before ~ is touched below.
# Idempotent if an earlier fragment already switched to agent.
USER agent

# npm presets as environment variables, so they apply to every user and every HOME. npm finds the
# ~/.npmrc below only through $HOME, and its global npmrc location depends on which npm runs (the
# mise shim picks mise's npm only with the agent's HOME).
# Environment variables beat every .npmrc, so a project's .npmrc cannot loosen them; pass a flag
# such as --ignore-scripts=false on the command line for a one-off exception.
# Only npm 11+ knows min-release-age; older npm versions ignore it silently.
ENV NPM_CONFIG_MIN_RELEASE_AGE=7 \
    NPM_CONFIG_IGNORE_SCRIPTS=true \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_ALLOW_DIRECTORY=root \
    NPM_CONFIG_ALLOW_FILE=root \
    NPM_CONFIG_ALLOW_REMOTE=root

# The same presets as a file, for tools that read ~/.npmrc instead of npm's environment.
RUN mkdir -p ~/.config/pnpm ~/.config/uv && \
    cat <<'EOF' >> ~/.npmrc
min-release-age=7
ignore-scripts=true
update-notifier=false
allow-directory=root
allow-file=root
allow-remote=root
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

# mise (https://mise.jdx.dev) installs the image's tools, configured via shell-base/mise.toml (see
# tools/shell-base-mise-tools.dockerfile). mise itself comes from GitHub Releases, GPG-verified
# against mise's release-signing key - deliberately not `curl | sh`.
#
# keys/mise-release.asc fingerprint 24853EC9F655CE80B48E6C3A8B81C9D17413A06D - confirmed against
# two independent sources: https://mise.jdx.dev/installing-mise.html quotes this exact fingerprint
# for verifying the mise.run install script, and it matches the key ID computed locally from the
# "Release gpg key" block published in https://github.com/jdx/mise/blob/main/SECURITY.md ("used to
# sign deb releases and the SHASUMS files contained within releases").
#
# Each release's SHASUMS256.asc is a GPG clearsigned checksum manifest (not a detached signature
# over a separate file), so `gpg --verify` on it alone is both correct and sufficient - the
# checksum lines are read from `gpg --decrypt`'s output, which holds only the signed body, so text
# outside the clearsigned block can't inject a hash (same as .github/workflows/update-hashes.yml). See
# https://mise.jdx.dev/installing-mise.html#github-releases. A hardcoded MISE_SHA256 pin below is
# checked in addition to the live GPG verification,
# so a build always gets the exact same reviewed bytes rather than "whatever is currently signed".
#
# Requires curl and gnupg, which the base image ships.
COPY --chown=agent:agent shared/mise-release.asc /tmp/mise-release.asc

RUN set -eu; \
    MISE_VERSION=2026.11.10; \
    case "$(uname -m)" in \
        x86_64) MISE_PLATFORM=linux-x64; MISE_SHA256=b603a4f48563fc379a794d9ea2cf9f709ed276c9141068604cb0c59fa3e674a9 ;; \
        aarch64) MISE_PLATFORM=linux-arm64; MISE_SHA256=86ef275d541c5243cd20b1c0fcd16810e5f3601113d8db09278d0608617a3833 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    MISE_ASSET="mise-v${MISE_VERSION}-${MISE_PLATFORM}"; \
    curl -fsSL -o /tmp/mise "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/${MISE_ASSET}"; \
    curl -fsSL -o /tmp/SHASUMS256.asc "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/SHASUMS256.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --import /tmp/mise-release.asc; \
    gpg --batch --yes --output /tmp/SHASUMS256.txt --decrypt /tmp/SHASUMS256.asc; \
    rm -rf "$GNUPGHOME" /tmp/mise-release.asc /tmp/SHASUMS256.asc; \
    LIVE_SHA256="$(awk -v f="./${MISE_ASSET}" '$2 == f {print $1}' /tmp/SHASUMS256.txt)"; \
    rm /tmp/SHASUMS256.txt; \
    if [ "$LIVE_SHA256" != "$MISE_SHA256" ]; then \
        echo "mise ${MISE_VERSION} ${MISE_PLATFORM}: GPG-verified checksum ${LIVE_SHA256} does not match pinned ${MISE_SHA256}" >&2; \
        exit 1; \
    fi; \
    echo "${MISE_SHA256}  /tmp/mise" | sha256sum -c -; \
    mkdir -p ~/.local/bin; \
    install -m 755 /tmp/mise ~/.local/bin/mise; \
    rm /tmp/mise

# mise's shim directory just needs to be on PATH for every shell - interactive and
# non-interactive bash alike. The shims are static files, so this one ENV line
# needs no per-shell activation hook. See
# https://mise.jdx.dev/dev-tools/shims.html.
ENV PATH="/home/agent/.local/share/mise/shims:/home/agent/.local/bin:$PATH"

# Installs this image's tools as declared in shell-base/mise.toml (see that file for the list and
# tools/mise.dockerfile for how the mise binary itself gets here). shell-base/mise.lock pins exact
# reviewed checksums/provenance so `mise install` doesn't re-resolve against live upstream
# metadata on every build; .github/workflows/update-hashes.yml keeps it refreshed going forward.
#
# Installed as mise's *global* config (~/.config/mise/config.toml), not as ~/mise.toml: a
# ~/mise.toml is a project config that only applies when the cwd is under /home/agent, so in a
# workspace elsewhere (e.g. /Users/...) no version was active and the shims fell through to the
# base image's own node/npm. The global config
# applies from every directory, is implicitly trusted (no `mise trust`), and its settings
# (minimum_release_age) also become the floor for ad-hoc `mise use`/`mise install` runs in a live
# sandbox. The lockfile must sit next to it as mise.lock (mise ignores config.lock there);
# `--locked` fails the build if mise isn't actually installing from it. See
# https://mise.jdx.dev/configuration.html#configuration-hierarchy and
# https://mise.jdx.dev/dev-tools/mise-lock.html.
# mkdir first so ~/.config/mise is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/mise
COPY --chown=agent:agent mise.toml /home/agent/.config/mise/config.toml
COPY --chown=agent:agent mise.lock /home/agent/.config/mise/mise.lock

RUN mise install --locked

# Ships the global agent guidance (package-manager and network-access rules) so it applies
# regardless of which project directory a session starts in. The rules live in AGENTS.md so
# other agents can read them too; CLAUDE.md only imports it (`@AGENTS.md`, resolved relative to
# CLAUDE.md), which is why both files must land in the same directory.
RUN mkdir -p ~/.claude
COPY --chown=agent:agent shared/CLAUDE.md shared/AGENTS.md /home/agent/.claude/

# Claude Code's classic renderer instead of its fullscreen one, which became the default when the
# `tui` setting is unset. Fullscreen captures the mouse, so drags no longer reach tmux copy mode
# on the host, and its own copy (OSC 52) does not arrive through sbx and tmux: copy-paste breaks.
# Same as `"tui": "default"` in settings.json, which claude-mixin seeds; the variable beats the
# setting, so `/tui fullscreen` only lasts with CLAUDE_CODE_NO_FLICKER=1 set for that session.
ENV CLAUDE_CODE_NO_FLICKER=0

# Ships a default helix config (theme) as the user-level config in ~/.config/helix/, so it applies
# in every project; a project's own .helix/ still overrides it. Kit mode flattens COPY sources into
# shared/ by file name, so this name must stay unique there.
# mkdir first so ~/.config/helix is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/helix
COPY --chown=agent:agent shared/config.toml /home/agent/.config/helix/config.toml

# Make helix (installed via mise, see shell-base/mise.toml) the default editor for git, sudoedit
# etc. A Docker ENV rather than an `export` in ~/.bashrc, so it reaches every
# shell - interactive and non-interactive bash alike - like mise's PATH does.
ENV EDITOR=hx VISUAL=hx

# Ships a default git config (identity, unsigned commits, aliases) as the user-level config. It goes
# to git's XDG path ~/.config/git/config rather than ~/.gitconfig, so anything that writes
# ~/.gitconfig at runtime cannot replace it (values set there still win). Kit mode flattens COPY sources into
# shared/ by file name, so this name must stay unique there.
# mkdir first so ~/.config/git is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/git
COPY --chown=agent:agent shared/gitconfig /home/agent/.config/git/config

# Ships a default hunk config (theme, view settings) as the user-level config in ~/.config/hunk/,
# so it applies in every project; a repo's own .hunk/config.toml still overrides it. Kit mode
# flattens COPY sources into shared/ by file name, so the source is hunk.toml, not config.toml
# (helix already uses that name).
# mkdir first so ~/.config/hunk is agent-owned rather than created root-owned by COPY.
RUN mkdir -p ~/.config/hunk
COPY --chown=agent:agent shared/hunk.toml /home/agent/.config/hunk/config.toml

# Extension that shows a toast and rings the terminal bell when the agent comments or replies in a
# live review (see the file's header).
RUN mkdir -p ~/.config/hunk/extensions
COPY --chown=agent:agent shared/agent-notify.ts /home/agent/.config/hunk/extensions/agent-notify.ts

# Kit templates only (their descriptor declares com.docker.sandbox/sbx@1). sbx launches the
# workload with the image's ENTRYPOINT plus any arguments after `--`. sbx/shell's own entrypoint
# is `bash -c 'exec "$@"' bash`, which expects a whole command, but sbx-up passes bash options
# (`-l`, `-lc 'claude ...'`). So use a plain bash entrypoint, like Docker's
# example shell kit (sandbox-kit-spec examples/shell): no arguments give a login shell, and
# sbx-up's arguments run inside one. Setting ENTRYPOINT clears the inherited CMD, hence both lines.
ENTRYPOINT ["bash"]
CMD ["-l"]
