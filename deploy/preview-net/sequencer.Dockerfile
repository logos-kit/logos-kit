# Logos Kit preview network: LEZ v0.3.0-rc1 sequencer (standalone, real
# proof verification: never RISC0_DEV_MODE), our genesis, key from env.
# Binaries come from this repo's GitHub release (built by build-seq.sh from
# vendor/lez at the pin), checked against the hashes below.
FROM debian:trixie-slim
ARG RELEASE=https://github.com/logos-kit/logos-kit/releases/download/preview-net-v0.1.0
ARG SEQ_SHA256=ee668b895ba64e5e1d92049ae0413a8354d7b55bf6fcd1fb2cc83b5bdabfacb9
ARG R0VM_SHA256=36c016a5bb2ded5bd1f8f92cc487e6ffaeb1e95ec05850c983081a0f716b515b
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL "$RELEASE/sequencer_service-linux-x86_64" -o /usr/local/bin/sequencer_service \
    && curl -fsSL "$RELEASE/r0vm-3.0.5-linux-x86_64" -o /usr/local/bin/r0vm \
    && echo "$SEQ_SHA256  /usr/local/bin/sequencer_service" | sha256sum -c - \
    && echo "$R0VM_SHA256  /usr/local/bin/r0vm" | sha256sum -c - \
    && chmod +x /usr/local/bin/sequencer_service /usr/local/bin/r0vm \
    && useradd -m -u 1000 sequencer && mkdir -p /etc/sequencer_service /var/lib/sequencer_service \
    && chown sequencer /var/lib/sequencer_service
# Build context: deploy/preview-net (Coolify builds from the repo).
COPY sequencer_config.json /etc/sequencer_service/sequencer_config.json
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
USER sequencer
VOLUME /var/lib/sequencer_service
EXPOSE 3040
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD curl -fsS http://127.0.0.1:3040 \
  -H 'content-type: application/json' -d '{"jsonrpc":"2.0","id":1,"method":"getLastBlockId","params":[]}' || exit 1
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
