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
