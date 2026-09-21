RUN set -eu; \
    UV_VERSION=0.12.13; \
    case "$(uname -m)" in \
        x86_64) UV_ASSET=uv-x86_64-unknown-linux-gnu.tar.gz; UV_SHA256=745765a3b6e360ad76743599ae5c42e9278c7edf8bbff9fc76d05bf2623a04dd ;; \
        aarch64) UV_ASSET=uv-aarch64-unknown-linux-gnu.tar.gz; UV_SHA256=2eaa5d94f5db7b3a1a092156b9420459e42ab0217d917fe74a876309cef9b5e9 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/uv.tar.gz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/${UV_ASSET}"; \
    echo "${UV_SHA256}  /tmp/uv.tar.gz" | sha256sum -c -; \
    mkdir -p ~/.local/bin; \
    tar -xzf /tmp/uv.tar.gz --strip-components=1 -C ~/.local/bin "${UV_ASSET%.tar.gz}/uv" "${UV_ASSET%.tar.gz}/uvx"; \
    rm /tmp/uv.tar.gz
