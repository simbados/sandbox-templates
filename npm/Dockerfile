FROM docker/sandbox-templates:claude-code-docker
USER agent

RUN mkdir -p ~/Library/Preferences/pnpm ~/.config/uv && \
    BEFORE_DATE=$(date -d "-3 days" +%Y-%m-%d) && \
    cat <<EOF >> ~/.npmrc
# --- managed by config/setup.sh ---
before=$BEFORE_DATE
ignore-scripts=true
update-notifier=false
allow-directory=root
allow-file=root
allow-remote=root
# --- end config/setup.sh ---
EOF

RUN cat <<'EOF' > ~/Library/Preferences/pnpm/config.yaml
minimumReleaseAge: 10080

minimumReleaseAgeStrict: true

trustPolicy: no-downgrade

blockExoticSubdeps: true
EOF

RUN cat <<'EOF' > ~/.config/uv/uv.toml
exclude-newer = "7 days"
EOF

RUN command -v unzip >/dev/null 2>&1 || \
    (sudo apt-get update && sudo apt-get install -y --no-install-recommends unzip && sudo rm -rf /var/lib/apt/lists/*)

RUN set -eu; \
    FNM_VERSION=v1.38.0; \
    case "$(uname -m)" in \
        x86_64) FNM_ASSET=fnm-linux.zip; FNM_SHA256=0000000000000000000000000000000000000000000000000000000000000000 ;; \
        aarch64) FNM_ASSET=fnm-arm64.zip; FNM_SHA256=0000000000000000000000000000000000000000000000000000000000000000 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/fnm.zip "https://github.com/Schniz/fnm/releases/download/${FNM_VERSION}/${FNM_ASSET}"; \
    echo "${FNM_SHA256}  /tmp/fnm.zip" | sha256sum -c -; \
    mkdir -p ~/.local/share/fnm; \
    unzip -q /tmp/fnm.zip -d ~/.local/share/fnm; \
    rm /tmp/fnm.zip

ENV PATH="/home/agent/.local/share/fnm:$PATH"

RUN echo 'eval "$(fnm env --use-on-cd --shell bash)"' >> ~/.bashrc

RUN eval "$(fnm env --shell bash)" && \
    fnm install --lts && \
    fnm default lts-latest

RUN set -eu; \
    FZF_VERSION=v0.74.2; \
    ZOXIDE_VERSION=v0.10.0; \
    case "$(uname -m)" in \
        x86_64) \
            FZF_ASSET=fzf-0.74.2-linux_amd64.tar.gz; \
            FZF_SHA256=b3648f48675612b69ee35371cf6dc99ca96d767e89b912d079080916ac8ba8bd; \
            ZOXIDE_ASSET=zoxide-0.10.0-x86_64-unknown-linux-musl.tar.gz; \
            ZOXIDE_SHA256=2d93385b99f3e82cf2701609a1bffcad863fbeb75aa3fe7eb6be4d29be68b1ae ;; \
        aarch64) \
            FZF_ASSET=fzf-0.74.2-linux_arm64.tar.gz; \
            FZF_SHA256=1373e3f5ed3c468179d4529942ddd96c234bcad1bcacaf238916e26a5234b5b2; \
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

RUN printf '%s\n%s\n' 'eval "$(fzf --bash)"' 'eval "$(zoxide init bash)"' >> ~/.bashrc

