{
  description = "A Basecamp app on the Logos Execution Zone, built with Logos Kit";

  inputs = {
    # The Logos module builder. Pin a commit you have built with.
    logos-module-builder.url = "github:logos-co/logos-module-builder/4b7998272c5ec014bcac4bf1c7dbe7602c63a3c1";
  };

  # The wallet's contract comes from ./logos_kit_wallet.lidl (metadata.json
  # `dependency_overrides`), so building this app never builds the wallet.
  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
