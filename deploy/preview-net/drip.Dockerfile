# Logos Kit drip faucet for the preview network (crates/logos-kit-drip).
FROM debian:trixie-slim
ARG RELEASE=https://github.com/logos-kit/logos-kit/releases/download/preview-net-v0.1.0
ARG DRIP_SHA256=__DRIP_SHA256__
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "$RELEASE/logos-kit-drip-linux-x86_64" -o /usr/local/bin/logos-kit-drip \
    && echo "$DRIP_SHA256  /usr/local/bin/logos-kit-drip" | sha256sum -c - \
    && chmod +x /usr/local/bin/logos-kit-drip && useradd -m -u 1000 drip
USER drip
EXPOSE 8080
ENV LK_DRIP_LISTEN=0.0.0.0:8080 LK_DRIP_TRUST_PROXY=1
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -fsS http://127.0.0.1:8080/ || exit 1
ENTRYPOINT ["/usr/local/bin/logos-kit-drip"]
