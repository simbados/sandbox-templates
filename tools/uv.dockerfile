RUN set -eu; \
    UV_VERSION=0.12.6; \
    case "$(uname -m)" in \
        x86_64) UV_ASSET=uv-x86_64-unknown-linux-gnu.tar.gz; UV_SHA256=8681d8921e7d520fb368991dcf5f9c1905b80f5bf2a265a0ed085c8d8e342477 ;; \
        aarch64) UV_ASSET=uv-aarch64-unknown-linux-gnu.tar.gz; UV_SHA256=d58030acd26159499ac82f32da12d1b3c12a3a1bfc414232d9082070c03e128d ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/uv.tar.gz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_ASSET}"; \
    echo "${UV_SHA256}  /tmp/uv.tar.gz" | sha256sum -c -; \
    mkdir -p ~/.local/bin; \
    tar -xzf /tmp/uv.tar.gz --strip-components=1 -C ~/.local/bin "${UV_ASSET%.tar.gz}/uv" "${UV_ASSET%.tar.gz}/uvx"; \
    rm /tmp/uv.tar.gz
