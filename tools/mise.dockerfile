# mise (https://mise.jdx.dev) replaces fnm/fzf/zoxide/temurin/uv/pnpm's separate hand-rolled
# curl+sha256 installs (see archive/tools/) with one tool version manager, configured per image
# via <template>/mise.toml (see tools/claude-mise-tools.dockerfile and
# tools/shell-base-mise-tools.dockerfile). Installed here from GitHub Releases and GPG-verified
# against mise's release-signing key - deliberately not `curl | sh` - matching this repo's
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
COPY --chown=agent:agent keys/mise-release.asc /tmp/mise-release.asc

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

# Global mise config (~/.config/mise/config.toml), shared by both images, lower precedence than
# each image's own <template>/mise.toml but applied everywhere mise runs - not just inside a
# trusted project config. Without this, minimum_release_age only protects the curated tool list
# in claude/mise.toml / shell-base/mise.toml; this makes it a floor for any ad-hoc `mise use`/
# `mise install` run anywhere in a live sandbox too. See
# https://mise.jdx.dev/configuration.html#configuration-hierarchy and
# https://mise.jdx.dev/security.html#minimum-release-age.
RUN mkdir -p ~/.config/mise && cat <<'EOF' > ~/.config/mise/config.toml
[settings]
minimum_release_age = "7d"
EOF

# mise's shim directory just needs to be on PATH for every shell - interactive bash, interactive
# fish, and non-interactive invocations alike. Unlike fnm (which needs a per-shell
# `eval "$(fnm env ...)"` hook in ~/.bashrc, fish's conf.d, AND /etc/sandbox-persistent.sh - see
# archive/tools/fnm.dockerfile), mise's shims are static files that just need to be found on
# PATH, so this one ENV line replaces all three of those integration points. See
# https://mise.jdx.dev/dev-tools/shims.html.
ENV PATH="/home/agent/.local/share/mise/shims:/home/agent/.local/bin:$PATH"
