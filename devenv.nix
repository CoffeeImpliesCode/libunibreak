# Development shell and tasks for this SDK.
# Tasks run from this file's directory, not devenv's caller project.
# Keep Zig caches and install outputs outside the checkout.
# Use consistent cache, job-count and summary options for builds.

{
  pkgs,
  lib,
  ...
}:

let
  zig = pkgs.zig_0_17;
  sdk = linkage: pkgs.callPackage ./package.nix { inherit zig linkage; };

  # Resolve the checkout path without copying it into the Nix store.
  sdkRoot = builtins.toString ./.;

  # Stop if a task cannot enter the checkout.
  inSdk = "cd ${lib.escapeShellArg sdkRoot} || exit 1";

  # Isolate this SDK's local cache under ZIG_LOCAL_CACHE_DIR.
  cacheDir = "$ZIG_LOCAL_CACHE_DIR/libunibreak-cache";

  # Prefer caller-supplied cache paths; otherwise use XDG_CACHE_HOME or TMPDIR.
  chooseCaches = ''
    if [ -z "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        ZIG_LOCAL_CACHE_DIR="$XDG_CACHE_HOME/libunibreak"
      elif [ -n "''${TMPDIR:-}" ]; then
        ZIG_LOCAL_CACHE_DIR="$TMPDIR/libunibreak"
      else
        echo "libunibreak cache: ZIG_LOCAL_CACHE_DIR, XDG_CACHE_HOME and TMPDIR" >&2
        echo "are all unset, so no cache outside this checkout is known. Export" >&2
        echo "one of them at an approved scratch mount, or set ZIG_LOCAL_CACHE_DIR" >&2
        echo "to the directory the builds should use." >&2
        exit 1
      fi
      export ZIG_LOCAL_CACHE_DIR
    fi
    if [ -z "''${ZIG_GLOBAL_CACHE_DIR:-}" ]; then
      # Fall back to a subdirectory of the local cache for global state.
      if [ -n "''${XDG_CACHE_HOME:-}" ]; then
        ZIG_GLOBAL_CACHE_DIR="$XDG_CACHE_HOME/zig-global-cache"
      elif [ -n "''${TMPDIR:-}" ]; then
        ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
      else
        ZIG_GLOBAL_CACHE_DIR="$ZIG_LOCAL_CACHE_DIR/zig-global-cache"
      fi
      export ZIG_GLOBAL_CACHE_DIR
    fi
    mkdir -p "$ZIG_LOCAL_CACHE_DIR" "$ZIG_GLOBAL_CACHE_DIR"
  '';

  # Keep delivery output outside the checkout; honor a caller-selected prefix.
  choosePrefix = ''
    if [ -n "''${LIBUNIBREAK_INSTALL_PREFIX:-}" ]; then
      prefix="$LIBUNIBREAK_INSTALL_PREFIX"
    elif [ -n "''${ZIG_LOCAL_CACHE_DIR:-}" ]; then
      prefix="$ZIG_LOCAL_CACHE_DIR/libunibreak-install"
    elif [ -n "''${XDG_CACHE_HOME:-}" ]; then
      prefix="$XDG_CACHE_HOME/libunibreak-install"
    elif [ -n "''${TMPDIR:-}" ]; then
      prefix="$TMPDIR/libunibreak-install"
    else
      echo "libunibreak install: LIBUNIBREAK_INSTALL_PREFIX, ZIG_LOCAL_CACHE_DIR," >&2
      echo "XDG_CACHE_HOME and TMPDIR are all unset, so no install prefix outside" >&2
      echo "this checkout is known. Export one of them at an approved scratch" >&2
      echo "mount, or set LIBUNIBREAK_INSTALL_PREFIX to the prefix you want." >&2
      exit 1
    fi
    mkdir -p "$prefix"
  '';
in
{
  packages = [
    zig
    pkgs.pkg-config
  ];

  outputs = {
    static = sdk "static";
    shared = sdk "dynamic";
    default = sdk "static";
  };

  # Apply build defaults before caller arguments.
  tasks = {
    "sdk:build" = {
      description = "Install the static archive, the five public headers and the licence material outside this checkout";
      exec = ''
        # Preserve the install failure before printing the result.
        set -e
        ${inSdk}
        ${chooseCaches}
        ${choosePrefix}
        zig build install --prefix "$prefix" --cache-dir "${cacheDir}" -j8 --summary all "$@"
        printf '%s\n' "installed to $prefix"
      '';
    };
    "sdk:test" = {
      description = "Run the facade tests and the API exercise";
      exec = ''
        ${inSdk}
        ${chooseCaches}
        zig build test --cache-dir "${cacheDir}" -j8 --summary all "$@"
      '';
    };
    "sdk:smoke" = {
      description = "Run the example program";
      exec = ''
        ${inSdk}
        ${chooseCaches}
        zig build smoke --cache-dir "${cacheDir}" -j8 --summary all "$@"
      '';
    };
    "sdk:upstream-test" = {
      description = "Run upstream's own src/tests.c against the three Unicode fixtures";
      exec = ''
        ${inSdk}
        ${chooseCaches}
        zig build upstream-test --cache-dir "${cacheDir}" -j8 --summary all "$@"
      '';
    };
    # Exercise the separate consumer through the forwarding build step.
    "sdk:consumer" = {
      description = "Build the separate consumer/ package, and run it when this host can execute the selected target";
      exec = ''
        ${inSdk}
        ${chooseCaches}
        zig build consumer --cache-dir "${cacheDir}" -j8 --summary all "$@"
      '';
    };
    "sdk:check" = {
      description = "Compile the six-target baseline matrix without running it";
      exec = ''
        ${inSdk}
        ${chooseCaches}
        zig build check --cache-dir "${cacheDir}" -j8 --summary all "$@"
      '';
    };
    # Resolve UPSTREAM.sha256 paths from the checkout root.
    "sdk:integrity" = {
      description = "Check the pinned upstream blobs against UPSTREAM.sha256";
      exec = ''
        ${inSdk}
        sha256sum -c UPSTREAM.sha256 "$@"
      '';
    };
    # Run each gate in order; only install needs a prefix.
    "sdk:gate" = {
      description = "Every gate above, in order";
      exec = ''
        set -e
        ${inSdk}
        ${chooseCaches}
        ${choosePrefix}
        zig build install --prefix "$prefix" --cache-dir "${cacheDir}" -j8 --summary all "$@"
        zig build test --cache-dir "${cacheDir}" -j8 --summary all "$@"
        zig build smoke --cache-dir "${cacheDir}" -j8 --summary all "$@"
        zig build upstream-test --cache-dir "${cacheDir}" -j8 --summary all "$@"
        zig build consumer --cache-dir "${cacheDir}" -j8 --summary all "$@"
        zig build check --cache-dir "${cacheDir}" -j8 --summary all "$@"
        sha256sum -c UPSTREAM.sha256
      '';
    };
  };

  assertions = [
    {
      assertion = lib.assertMsg (zig.version == "0.17.0")
        "libunibreak needs Zig 0.17.0; devenv resolved ${zig.version}";
      message = "libunibreak needs Zig 0.17.0.";
    }
  ];
}