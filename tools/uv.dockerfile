RUN set -eu; \
    UV_VERSION=0.12.11; \
    case "$(uname -m)" in \
        x86_64) UV_ASSET=uv-x86_64-unknown-linux-gnu.tar.gz; UV_SHA256=4ae93e0f148a18434cc094072547cec88912fc4a72b984183c7d0d0e9586cb5e ;; \
        aarch64) UV_ASSET=uv-aarch64-unknown-linux-gnu.tar.gz; UV_SHA256=e9933d907fb9cd27d606d819bbded419f2844c0e2efc98225ecfa409288eb28d ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/uv.tar.gz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_ASSET}"; \
    echo "${UV_SHA256}  /tmp/uv.tar.gz" | sha256sum -c -; \
    mkdir -p ~/.local/bin; \
    tar -xzf /tmp/uv.tar.gz --strip-components=1 -C ~/.local/bin "${UV_ASSET%.tar.gz}/uv" "${UV_ASSET%.tar.gz}/uvx"; \
    rm /tmp/uv.tar.gz
