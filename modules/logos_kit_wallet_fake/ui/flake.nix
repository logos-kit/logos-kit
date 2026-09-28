{
  description = "Logos Kit conformance: logos_kit_wallet_fake (ui_qml intent provider for the fake wallet)";

  inputs = {
    # Pinned: see docs/dev/pins.md
    logos-module-builder.url = "github:logos-co/logos-module-builder/4b7998272c5ec014bcac4bf1c7dbe7602c63a3c1";
    # The fake core answers the real wallet's contract, so this reads the real LIDL.
    logos_kit_wallet.url = "path:../../logos_kit_wallet";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
