{
  description = "Logos Kit conformance: the fake wallet engine (libwallet_engine C ABI, no keys, no chain)";

  inputs = {
    # Pinned: see docs/dev/pins.md. Its nixpkgs builds the library, so the
    # module build shares one toolchain with the plugin.
    logos-module-builder.url = "github:logos-co/logos-module-builder/4b7998272c5ec014bcac4bf1c7dbe7602c63a3c1";
    nixpkgs.follows = "logos-module-builder/nixpkgs";
  };

  outputs =
    { nixpkgs, ... }:
    let
      forAll = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      packages = forAll (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          fake = pkgs.rustPlatform.buildRustPackage {
            pname = "wallet-engine-fake";
            version = "0.1.0";
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;
            doCheck = false;
            # Same layout as the real engine package: lib/ + include/.
            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib $out/include
              cp include/wallet_engine.h $out/include/
              find target -name 'libwallet_engine.dylib' -o -name 'libwallet_engine.so' | grep /release/ | xargs -I{} cp {} $out/lib/
              ls $out/lib/libwallet_engine.*
              runHook postInstall
            '';
            postFixup = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              install_name_tool -id @rpath/libwallet_engine.dylib $out/lib/libwallet_engine.dylib
            '';
          };
        in
        {
          wallet-engine = fake;
          default = fake;
        }
      );
    };
}
