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
