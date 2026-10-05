# nix build .#static / .#shared
#
# Both variants are the one package.nix; the variants live here, not inside it.
# `default` is static, which is this SDK's native linkage policy.
#
# The dev shell holds tools. Putting the SDK package in it would mean building
# the library to enter the shell. `devenv shell` is the canonical way to work in
# this repository.
#
# flake.lock is the driver's; this file pins the revision it wants.

{
  description = "libunibreak: Unicode line, word and grapheme breaking (UAX #14, UAX #29)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";

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
          zig = pkgs.zig_0_16;
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
          # Asserted, not assumed: build.zig.zon declares
          # .minimum_zig_version = "0.16.0".
          packages = [
            (
              assert pkgs.zig_0_16.version == "0.16.0";
              pkgs.zig_0_16
            )
            pkgs.pkg-config
          ];
        };
      });
    };
}