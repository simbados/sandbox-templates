# GENERATED FILE - do not edit directly.
#
# Edit the fragments in tools/ (and this template's template.yaml / prelude
# fragment), then regenerate with:
#   python3 scripts/generate_dockerfile.py shell-base

FROM docker/sandbox-templates:shell-docker@sha256:1560168ac5fb9ce23d413c878349334c5845c07e264cd675d7867f0c78ad1761

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

# Ships the global agent guidance (package-manager and network-access rules) so it applies
# regardless of which project directory a session starts in. The rules live in AGENTS.md so
# other agents can read them too; CLAUDE.md only imports it (`@AGENTS.md`, resolved relative to
# CLAUDE.md), which is why both files must land in the same directory.
RUN mkdir -p ~/.claude
COPY --chown=agent:agent shared/CLAUDE.md shared/AGENTS.md /home/agent/.claude/

RUN command -v unzip >/dev/null 2>&1 && command -v fish >/dev/null 2>&1 && \
    command -v vim >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1 || \
    (sudo apt-get update && sudo apt-get install -y --no-install-recommends unzip fish vim gnupg && \
     sudo rm -rf /var/lib/apt/lists/*)

# mise (https://mise.jdx.dev) replaces fnm/fzf/zoxide/temurin/uv/pnpm's separate hand-rolled
# curl+sha256 installs (see archive/tools/) with one tool version manager, configured per image
# via <template>/mise.toml (see tools/shell-base-mise-tools.dockerfile). Installed here from
# GitHub Releases and GPG-verified against mise's release-signing key - deliberately not `curl | sh` - matching this repo's
# existing curl-then-verify-then-extract convention (closest precedent: temurin.dockerfile).
#
# keys/mise-release.asc fingerprint 24853EC9F655CE80B48E6C3A8B81C9D17413A06D - confirmed against
# two independent sources: https://mise.jdx.dev/installing-mise.html quotes this exact fingerprint
# for verifying the mise.run install script, and it matches the key ID computed locally from the
# "Release gpg key" block published in https://github.com/jdx/mise/blob/main/SECURITY.md ("used to
# sign deb releases and the SHASUMS files contained within releases").
#
# Each release's SHASUMS256.asc is a GPG clearsigned checksum manifest (not a detached signature
# over a separate file), so `gpg --verify` on it alone is both correct and sufficient - the
# checksum lines can then be read straight back out of that same now-verified file. See
# https://mise.jdx.dev/installing-mise.html#github-releases. A hardcoded MISE_SHA256 pin below is
# checked in addition to the live GPG verification (same belt-and-suspenders as temurin.dockerfile),
# so a build always gets the exact same reviewed bytes rather than "whatever is currently signed".
#
# Requires gnupg (from apt-packages.dockerfile).
COPY --chown=agent:agent shared/mise-release.asc /tmp/mise-release.asc

RUN set -eu; \
    MISE_VERSION=2026.9.12; \
    case "$(uname -m)" in \
        x86_64) MISE_PLATFORM=linux-x64; MISE_SHA256=e79ae57945034903aee8aa2ea66b4c7ca9cd4f4edd5a8a78a589cbae6d0f428a ;; \
        aarch64) MISE_PLATFORM=linux-arm64; MISE_SHA256=f344c6961190ed2f68e595ed7cb4f03c36c17812bd608886bec799a3082180ff ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    MISE_ASSET="mise-v${MISE_VERSION}-${MISE_PLATFORM}"; \
    curl -fsSL -o /tmp/mise "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/${MISE_ASSET}"; \
    curl -fsSL -o /tmp/SHASUMS256.asc "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/SHASUMS256.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --import /tmp/mise-release.asc; \
    gpg --batch --verify /tmp/SHASUMS256.asc; \
    rm -rf "$GNUPGHOME" /tmp/mise-release.asc; \
    LIVE_SHA256="$(grep " \./${MISE_ASSET}\$" /tmp/SHASUMS256.asc | awk '{print $1}')"; \
    rm /tmp/SHASUMS256.asc; \
    if [ "$LIVE_SHA256" != "$MISE_SHA256" ]; then \
        echo "mise ${MISE_VERSION} ${MISE_PLATFORM}: GPG-verified checksum ${LIVE_SHA256} does not match pinned ${MISE_SHA256}" >&2; \
        exit 1; \
    fi; \
    echo "${MISE_SHA256}  /tmp/mise" | sha256sum -c -; \
    mkdir -p ~/.local/bin; \
    install -m 755 /tmp/mise ~/.local/bin/mise; \
    rm /tmp/mise

# mise's shim directory just needs to be on PATH for every shell - interactive bash, interactive
# fish, and non-interactive invocations alike. Unlike fnm (which needs a per-shell
# `eval "$(fnm env ...)"` hook in ~/.bashrc, fish's conf.d, AND /etc/sandbox-persistent.sh - see
# archive/tools/fnm.dockerfile), mise's shims are static files that just need to be found on
# PATH, so this one ENV line replaces all three of those integration points. See
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
# base image's own node/npm (and pnpm had nothing to fall back to at all). The global config
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

# Kit templates only (their descriptor declares com.docker.sandbox/sbx@1). sbx then launches
# the workload itself, under its own PID 1, so the base image's `tini --` entrypoint ends up as
# a child process and warns on every start that it can't reap zombies ("Tini is not running as
# PID 1 and isn't registered as a child subreaper"). Reaping is sbx's job here, so drop tini and
# use the same launch command as Docker's example shell kit (sandbox-kit-spec examples/shell):
# a login shell. Setting ENTRYPOINT clears the inherited CMD, hence both lines.
ENTRYPOINT ["bash"]
CMD ["-l"]
