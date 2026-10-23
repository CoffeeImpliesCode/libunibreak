# Static/shared derivations and the development shell.

{
  description = "libunibreak: Unicode line, word and grapheme breaking (UAX #14, UAX #29)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/02c087f3fe673c9e317f206a627cb6b910336dbe";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems =
        f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      packageFor =
        pkgs:
        linkage:
        pkgs.callPackage ./package.nix {
          zig = pkgs.zig_0_17;
          inherit linkage;
        };
    in
    {
      packages = forAllSystems (pkgs: {
        static = packageFor pkgs "static";
        shared = packageFor pkgs "dynamic";
        default = packageFor pkgs "static";
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          # Require the Zig version declared by the package manifest.
          packages = [
            (
              assert pkgs.zig_0_17.version == "0.17.0";
              pkgs.zig_0_17
            )
            pkgs.pkg-config
          ];
        };
      });
    };
}