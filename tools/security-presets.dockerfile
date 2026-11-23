# The base image ships the agent user; switch to it before ~ is touched below.
# Idempotent if an earlier fragment already switched to agent.
USER agent

# npm presets as environment variables, so they apply to every user and every HOME. npm finds the
# ~/.npmrc below only through $HOME, and its global npmrc location depends on which npm runs (the
# mise shim picks mise's npm only with the agent's HOME).
# Environment variables beat every .npmrc, so a project's .npmrc cannot loosen them; pass a flag
# such as --ignore-scripts=false on the command line for a one-off exception.
# Only npm 11+ knows min-release-age; older npm versions ignore it silently. allow-git=root: only
# the project's own package.json may use git dependencies (npm 11 defaults to all, npm 12 to none).
ENV NPM_CONFIG_MIN_RELEASE_AGE=7 \
    NPM_CONFIG_IGNORE_SCRIPTS=true \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    NPM_CONFIG_ALLOW_GIT=root \
    NPM_CONFIG_ALLOW_DIRECTORY=root \
    NPM_CONFIG_ALLOW_FILE=root \
    NPM_CONFIG_ALLOW_REMOTE=root

# The same presets as a file, for tools that read ~/.npmrc instead of npm's environment.
RUN mkdir -p ~/.config/pnpm ~/.config/uv && \
    cat <<'EOF' >> ~/.npmrc
min-release-age=7
ignore-scripts=true
update-notifier=false
allow-git=root
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

# The same 7-day minimum release age for the other package managers a project may bring in through
# its mixin. Environment variables where the tool reads one, since they beat a project's own config:
# - cargo (Rust 1.100+): versions published less than 7 days ago are ignored unless already in
#   Cargo.lock. One-off exception: CARGO_RESOLVER_INCOMPATIBLE_PUBLISH_AGE=allow cargo update ...
# - pip (26.1+; the base image ships 26.3): only files uploaded at least 7 days ago. pip 26.0 knows
#   the option but not the P<n>D form and fails, so recreate venvs that pin it.
# - yarn (4.12+, Berry; Classic 1.x has no age gate): YARN_ENABLE_SCRIPTS=false is the default,
#   set anyway so a project's .yarnrc.yml can't turn install scripts on.
ENV CARGO_REGISTRY_GLOBAL_MIN_PUBLISH_AGE="7 days" \
    PIP_UPLOADED_PRIOR_TO=P7D \
    YARN_NPM_MINIMAL_AGE_GATE=7d \
    YARN_ENABLE_SCRIPTS=false

# bun (1.3+) has no environment variable for this; it reads a global ~/.bunfig.toml, which a
# project's bunfig.toml can override. 604800 seconds = 7 days.
RUN cat <<'EOF' > ~/.bunfig.toml
[install]
minimumReleaseAge = 604800
EOF
