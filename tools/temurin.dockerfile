# Eclipse Temurin 25 (latest LTS), pulled directly from Adoptium's own GitHub releases,
# sha256-verified, and GPG-verified against Adoptium's vendored signing key (keys/adoptium-temurin.asc,
# fingerprint 3B04D753C9050D9A5D343F39843C48A565F8F04B - confirmed against the .sig packet metadata,
# Adoptium's own official container build, and a live keyserver fetch). This is the same source
# SDKMAN's own broker redirects to for this candidate, just fetched with real integrity verification
# and without SDKMAN's per-candidate "post-installation hook" mechanism (a remote script fetched and
# sourced on every install; see prior investigation). Installed ahead of the base image's existing
# OpenJDK on PATH so `java` resolves to this build. Requires gnupg (from apt-packages.dockerfile).
COPY --chown=agent:agent keys/adoptium-temurin.asc /tmp/adoptium-temurin.asc

RUN set -eu; \
    TEMURIN_VERSION=jdk-25.0.4+7; \
    case "$(uname -m)" in \
        x86_64) TEMURIN_ASSET=OpenJDK25U-jdk_x64_linux_hotspot_25.0.4_7.tar.gz; TEMURIN_SHA256=e58fcdcd637b25c03ca84cbbcefc70d11efb8f4b4cbd05decc9f661769d77f94 ;; \
        aarch64) TEMURIN_ASSET=OpenJDK25U-jdk_aarch64_linux_hotspot_25.0.4_7.tar.gz; TEMURIN_SHA256=621f7196f0b682fb557da58bec89bd7dfe5419811fe1c0ba75c9cc8432f084c7 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/temurin.tar.gz "https://github.com/adoptium/temurin25-binaries/releases/download/${TEMURIN_VERSION}/${TEMURIN_ASSET}"; \
    curl -fsSL -o /tmp/temurin.tar.gz.sig "https://github.com/adoptium/temurin25-binaries/releases/download/${TEMURIN_VERSION}/${TEMURIN_ASSET}.sig"; \
    export GNUPGHOME="$(mktemp -d)"; \
    gpg --batch --import /tmp/adoptium-temurin.asc; \
    gpg --batch --verify /tmp/temurin.tar.gz.sig /tmp/temurin.tar.gz; \
    rm -rf "$GNUPGHOME" /tmp/temurin.tar.gz.sig /tmp/adoptium-temurin.asc; \
    echo "${TEMURIN_SHA256}  /tmp/temurin.tar.gz" | sha256sum -c -; \
    mkdir -p ~/.local/share/temurin; \
    tar -xzf /tmp/temurin.tar.gz --strip-components=1 -C ~/.local/share/temurin; \
    rm /tmp/temurin.tar.gz

ENV JAVA_HOME="/home/agent/.local/share/temurin"
ENV PATH="/home/agent/.local/share/temurin/bin:$PATH"
