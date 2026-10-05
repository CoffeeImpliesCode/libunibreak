# libunibreak: one standalone source-only derivation.
#
# Both entry points call this: flake.nix for the package variants, devenv.nix
# for `devenv build outputs.static` / `outputs.shared`. It returns ONE
# derivation; `linkage` selects the artifact the build graph produces.
#
# The C is compiled by build.zig, never here: translation-unit list, C flags,
# header configuration and the installation of the library, headers, licences
# and pkg-config metadata all belong to the build graph, and this file restates
# none of them. `src` is this directory, so nothing is fetched at build time.
# "static" means a static library artifact, not a statically linked executable.

{
  lib,
  stdenv,
  zig,
  pkg-config,
  linkage ? "static",
  optimize ? "ReleaseFast",
}:

assert lib.assertMsg (zig.version == "0.16.0")
  "libunibreak builds with Zig 0.16.0; got zig ${zig.version}";
assert lib.assertMsg (linkage == "static" || linkage == "dynamic")
  "linkage must be static or dynamic";

stdenv.mkDerivation (finalAttrs: {
  pname = "libunibreak";
  # configure.ac AC_INIT([libunibreak],[8.0],…); src/unibreakbase.h
  # UNIBREAK_VERSION 0x0800. The C library's version, not this packaging's.
  version = "8.0.0";

  # Exclusion of build and tool state only. This is deliberately not a second
  # allowlist: build.zig.zon `.paths` states what the package publishes.
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

  # The graph generates `libunibreak.pc`; pkg-config is the tool that resolves
  # it, in postFixup and in the install check.
  nativeBuildInputs = [
    zig
    pkg-config
  ];

  # installPhase below is the real one, so the configure and build phases must
  # be disabled or the default install phase would build once more.
  dontConfigure = true;
  dontBuild = true;
  dontCheck = true;
  # Without this the Zig setup hook substitutes its own `zig build test` for the
  # check phase, which is a second, differently-flagged build of the same tree.
  # `doInstallCheck` below is unaffected and still runs.
  dontUseZigCheck = true;

  installPhase = ''
    runHook preInstall

    # Both Zig caches under the build directory: $TMPDIR is outside the
    # unpacked source, and the build is not reproducible from a stale cache.
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

  # The build graph writes the pkg-config metadata. Find it where it put it
  # rather than assuming a directory: the assertion that exists is the point,
  # the path is the build graph's choice.
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
      repository's pinned source with Zig 0.16.0. Seven of the nine compiled
      translation units, or their textual includes, are generated Unicode
      Character Database tables, so this output carries upstream's zlib grant
      and the Unicode terms over that data. See
      $out/share/licenses/libunibreak/NOTICE.md.
    '';
    homepage = "https://github.com/adah1972/libunibreak";
    # Two terms: the code is upstream's Zlib text, the data inside the archive is
    # Unicode's. NOTICE.md, installed with this output by the build graph, is
    # the per-file inventory.
    license = "Zlib AND Unicode-3.0";
    licenseFile = "LICENCE";
    platforms = lib.platforms.unix;
  };

  passthru = {
    inherit linkage optimize;
  };
})
