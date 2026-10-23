# Shared source-only derivation; the flake and devenv use this package.

{
  lib,
  stdenv,
  zig,
  pkg-config,
  linkage ? "static",
  optimize ? "ReleaseFast",
}:

assert lib.assertMsg (zig.version == "0.17.0")
  "libunibreak builds with Zig 0.17.0; got zig ${zig.version}";
assert lib.assertMsg (linkage == "static" || linkage == "dynamic")
  "linkage must be static or dynamic";

stdenv.mkDerivation (finalAttrs: {
  pname = "libunibreak";
  # Upstream C library version.
  version = "8.0.0";

  # Exclude generated state; build.zig.zon defines the package paths.
  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: _type:
      let name = baseNameOf (toString path);
      in !(lib.elem name [
        ".git"
        ".jj"
        ".devenv"
        ".devenv.flake.nix"
        ".direnv"
        ".zig-cache"
        "zig-cache"
        "zig-out"
        "zig-pkg"
        "__pycache__"
      ]) && builtins.match "result(-.*)?" name == null;
  };

  strictDeps = true;

  # pkg-config validates the generated metadata.
  nativeBuildInputs = [
    zig
    pkg-config
  ];

  # Zig owns the build and install phases.
  dontConfigure = true;
  dontBuild = true;
  dontCheck = true;
  # Prevent the Zig hook from adding a second check build.
  dontUseZigCheck = true;

  installPhase = ''
    runHook preInstall

    # Use fresh caches outside the source tree.
    export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
    export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"

    zig build install \
      --prefix "$out" \
      -j"''${NIX_BUILD_CORES:-1}" \
      -Dcpu=baseline \
      -Doptimize=${optimize} \
      -Dlinkage=${linkage}

    runHook postInstall
  '';

  # Locate generated metadata for the install check.
  postFixup = ''
    pc_file=$(find "$out" -type f -name 'libunibreak.pc' | head -n1)
    test -n "$pc_file"
    echo "pkg-config metadata: $pc_file"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    pc_file=$(find "$out" -type f -name 'libunibreak.pc' | head -n1)
    export PKG_CONFIG_PATH="$(dirname "$pc_file")"

    pkg-config --exists libunibreak
    test "$(pkg-config --modversion libunibreak)" = "${finalAttrs.version}"

    # upstream's include_HEADERS, from src/Makefile.am
    for header in unibreakbase.h unibreakdef.h linebreak.h graphemebreak.h wordbreak.h; do
      test -f "$out/include/$header"
    done

    if [ "${linkage}" = static ]; then
      test -f "$out/lib/libunibreak.a"
    else
      ls "$out/lib/"libunibreak.so* > /dev/null
    fi

    test -f "$out/LICENCE"
    test -f "$out/LICENCE-UNICODE.txt"
    test -f "$out/README.upstream.md"
    test -f "$out/share/licenses/${finalAttrs.pname}/NOTICE.md"
    test -f "$out/share/licenses/${finalAttrs.pname}/FORK-LICENSE.md"

    runHook postInstallCheck
  '';

  meta = {
    description =
      "Unicode line breaking (UAX #14), word breaking and grapheme cluster breaking (UAX #29), Unicode 17.0.0";
    longDescription = ''
      libunibreak 8.0 by Wu Yongwei and contributors, compiled from this
      repository's pinned source with Zig 0.17.0. Seven of the nine compiled
      translation units, or their textual includes, are generated Unicode
      Character Database tables, so this output carries upstream's zlib grant
      and the Unicode terms over that data. See
      $out/share/licenses/libunibreak/NOTICE.md.
    '';
    homepage = "https://github.com/adah1972/libunibreak";
    # Code and generated data carry separate terms; see NOTICE.md.
    license = "Zlib AND Unicode-3.0";
    licenseFile = "LICENCE";
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit linkage optimize;
  };
})
