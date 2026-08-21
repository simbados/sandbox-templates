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
