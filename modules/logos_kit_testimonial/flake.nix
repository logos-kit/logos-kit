{
  description = "Logos Kit: logos_kit_testimonial (ui_qml)";

  inputs = {
    # Pinned: see docs/dev/pins.md
    logos-module-builder.url = "github:logos-co/logos-module-builder/4b7998272c5ec014bcac4bf1c7dbe7602c63a3c1";

    # The input name must match metadata.json's dependency name; the builder
    # reads the dependency's published LIDL contract from it.
    logos_kit_wallet.url = "path:../logos_kit_wallet";
  };

  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
