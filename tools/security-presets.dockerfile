# Idempotent if the current template already switched to agent earlier in
# its tools list (e.g. via generic-tools): re-selecting the same user is a
# no-op. Kept here because templates whose base image ships agent already
# (no generic-tools needed) still need this before ~ is touched below.
USER agent

# npm presets as environment variables, so they apply to every user and every HOME. npm finds the
# ~/.npmrc below only through $HOME, and its global npmrc location depends on which npm runs (the
# mise shim picks mise's npm only with the agent's HOME, the base image's npm otherwise).
# Environment variables beat every .npmrc, so a project's .npmrc cannot loosen them; pass a flag
# such as --ignore-scripts=false on the command line for a one-off exception.
# Only npm 11+ knows min-release-age; the base image's /usr/bin/npm (9.x) ignores it silently.
ENV NPM_CONFIG_MIN_RELEASE_AGE=7 \
    NPM_CONFIG_IGNORE_SCRIPTS=true \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_ALLOW_DIRECTORY=root \
    NPM_CONFIG_ALLOW_FILE=root \
    NPM_CONFIG_ALLOW_REMOTE=root

# The same presets as a file, for tools that read ~/.npmrc instead of npm's environment.
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
