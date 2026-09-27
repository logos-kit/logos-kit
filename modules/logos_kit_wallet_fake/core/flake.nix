{
  description = "Logos Kit conformance: logos_kit_wallet built on the fake engine (drop-in for the real core, test profiles only)";

  inputs = {
    # Pinned: see docs/dev/pins.md
    logos-module-builder.url = "github:logos-co/logos-module-builder/4b7998272c5ec014bcac4bf1c7dbe7602c63a3c1";
    fake-engine.url = "path:../engine";
  };

  # The real module's shim, LIDL and CMake, unchanged (a dApp reaches this
  # exactly as it reaches the real wallet), linked against the fake engine.
  # `platforms: {}` in ./metadata.json makes the builder write this metadata
  # over the real module's copy in the source it builds and ships.
  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosModule {
      src = ../../logos_kit_wallet;
      configFile = ./metadata.json;
      flakeInputs = inputs;
      externalLibInputs = {
        wallet_engine = {
          input = inputs.fake-engine;
          packages = {
            default = "wallet-engine";
            portable = "wallet-engine";
          };
        };
      };
    };
}
