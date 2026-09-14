RUN set -eu; \
    UV_VERSION=0.12.10; \
    case "$(uname -m)" in \
        x86_64) UV_ASSET=uv-x86_64-unknown-linux-gnu.tar.gz; UV_SHA256=173d95a0c32d18c896c46ba6fafbf3cf9c14ab74b033f81b76c883ef492a976b ;; \
        aarch64) UV_ASSET=uv-aarch64-unknown-linux-gnu.tar.gz; UV_SHA256=9ff6b9d4665edcdd3a88dcc73cd1eb641754deb927f14e8c62ebfde6bf4f5f5e ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/uv.tar.gz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_ASSET}"; \
    echo "${UV_SHA256}  /tmp/uv.tar.gz" | sha256sum -c -; \
    mkdir -p ~/.local/bin; \
    tar -xzf /tmp/uv.tar.gz --strip-components=1 -C ~/.local/bin "${UV_ASSET%.tar.gz}/uv" "${UV_ASSET%.tar.gz}/uvx"; \
    rm /tmp/uv.tar.gz
