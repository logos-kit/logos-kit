# Logos Kit drip faucet for the preview network (crates/logos-kit-drip).
FROM debian:trixie-slim
ARG RELEASE=https://github.com/logos-kit/logos-kit/releases/download/preview-net-v0.1.0
# v2: durable ledger, proxy-aware per-IP limit, global budget, Retry-After.
ARG DRIP_SHA256=7b1eb50fd38fdb170e53761065001173a70814d1aa7362f3039bd39d4c2ee9cd
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "$RELEASE/logos-kit-drip-v2-linux-x86_64" -o /usr/local/bin/logos-kit-drip \
    && echo "$DRIP_SHA256  /usr/local/bin/logos-kit-drip" | sha256sum -c - \
    && chmod +x /usr/local/bin/logos-kit-drip && useradd -m -u 1000 drip \
    && mkdir -p /var/lib/drip && chown drip /var/lib/drip
USER drip
VOLUME /var/lib/drip
EXPOSE 8080
ENV LK_DRIP_LISTEN=0.0.0.0:8080 LK_DRIP_TRUST_PROXY=1
HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD curl -fsS http://127.0.0.1:8080/ || exit 1
ENTRYPOINT ["/usr/local/bin/logos-kit-drip"]
