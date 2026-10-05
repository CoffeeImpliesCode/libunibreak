# devenv shell   — canonical development shell
# devenv build outputs.static / outputs.shared
# devenv tasks run sdk:gate
#
# packages holds tools only: the SDK is not built to enter the shell. The
# packages below it are the same package.nix the flake uses, evaluated lazily —
# `devenv build outputs.static` is the packaging route.
#
# Every task body below names this directory and changes into it before it runs
# anything. devenv materialises a task as a generated program that inherits the
# *caller's* working directory, and `devenv --from path:<this SDK>` hands that
# program the project directory beside this tree — one that holds no
# `build.zig`, no `UPSTREAM.sha256` and no `consumer/`. `$DEVENV_ROOT` names that
# project, so trusting it is what failed on 2026-10-04: `sdk:consumer` printed
# `error: no build.zig file found, in the current directory or any parent
# directories` and `sdk:integrity` printed `sha256sum: UPSTREAM.sha256: No such
# file or directory` (receipts `…-libunibreak-devenv-consumer.log`,
# `…-libunibreak-devenv-integrity.log`). The path is named here, from this file,
# because `./.` is the directory of the file that writes it and so does not
# depend on where the caller stood.
#
# Scratch locations are the caller's to name and this file erases none of them.
# `TMPDIR` and the rest of the environment are only read. Two things are filled
# in, and only where the caller left them unset: the Zig caches, from
# `$XDG_CACHE_HOME` and then `$TMPDIR`, and the prefix a task that installs
# something writes to. Both are filled in each body rather than in
# `enterShell`, because `devenv tasks run` materialises a task as a generated
# program and does not run the shell's hooks. Both are filled because each has
# a default that lands in this checkout — `zig build`'s local cache is
# `.zig-cache` beside the build root and its install prefix is `zig-out` beside
# the same root — and this checkout is the volume the driver digests before and
# after every run. With nothing to fill either from, a body names what is
# missing and stops before any compiler runs. No location here is invented, and
# no small system temporary directory is chosen.
#
# Every `zig build` below also carries the flags this workspace's recipe names:
# `--cache-dir` naming this SDK's own directory under the local cache, `-j8`,
# and `--summary all`. All three are written before `"$@"`, so a caller naming
# its own `--cache-dir`, `-j` or summary still reaches the build runner after
# them.

{
  pkgs,
  lib,
  ...
}:

let
  zig = pkgs.zig_0_16;
  sdk = linkage: pkgs.callPackage ./package.nix { inherit zig linkage; };

  # This SDK's own directory, as a plain string.
  #
  # `builtins.toString`, not an interpolated `${./.}`: interpolating the path
  # itself asks Nix for the store copy of this whole tree, and that copy is
  # read-only and is not the working tree `sha256sum -c` describes.
  # `lib.escapeShellArg` is this workspace's quoting convention
  # (`htscodecs/package.nix` uses the same function), so a checkout path holding
  # a space or a quote still reaches the shell as a single argument.
  sdkRoot = builtins.toString ./.;

  # The first line of every exec body. The `exit 1` matters: a body that
  # continued after a failed `cd` would build in, or check, whatever directory
  # it happened to be standing in.
  inSdk = "cd ${lib.escapeShellArg sdkRoot} || exit 1";

  # This SDK's own cache directory, as the shell reads it when the body runs
  # rather than as a path this file writes at eval time. It is a per-SDK
  # directory under the caller's local cache, with the delivery prefix beside
  # it — the arrangement `box2d/devenv.nix` already uses.
  cacheDir = "$ZIG_LOCAL_CACHE_DIR/libunibreak-cache";

  # The Zig caches, filled before any compiler runs. A value the caller exported
  # is used exactly as it is and never overwritten; only a missing one is
  # filled, from `$XDG_CACHE_HOME` and then `$TMPDIR`, both locations the caller
  # exported. With neither, the body says what is missing and exits rather than
  # letting `zig build` fall back to `.zig-cache` in this checkout.
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
      # By now `ZIG_LOCAL_CACHE_DIR` is set, so there is always a location the
      # caller named for this one too, and no second refusal is needed: its own
      # cache root is the last resort, kept a directory away from the local
      # cache so the two do not share one manifest.
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

  # Where a delivery install lands. `zig build`'s default prefix is `zig-out`
  # beside the build root, which here is the checkout itself, so a task that
  # installs has to say where instead: the caller's `ZIG_LOCAL_CACHE_DIR`
  # first, then `$XDG_CACHE_HOME`, then `$TMPDIR` — the order this workspace's
  # other SDKs use, and every one of them a location the caller exported. A
  # caller that wants one particular prefix sets
  # `LIBUNIBREAK_INSTALL_PREFIX`, which is also how it asks for one without a
  # second `--prefix` on a command line that already carries this file's. With
  # none of the four set, the task names what is missing and stops rather than
  # writing an install tree into a working tree the driver compares.
  # Every body that installs runs `${chooseCaches}` above this, so by the time
  # these lines execute `ZIG_LOCAL_CACHE_DIR` is set — exported by the caller or
  # filled from `$XDG_CACHE_HOME` or `$TMPDIR` — and the first branch below is
  # the one it takes. A prefix chosen from `$TMPDIR` therefore sits beside the
  # cache that run also uses, instead of beside a cache nothing named.
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

  # The three flags this workspace's recipe names are written on every body
  # that invokes `zig build`: `--cache-dir` for this SDK's own directory,
  # `-j8`, and `--summary all`. They precede `"$@"`, so the job count, the
  # summary and the cache location are this file's own and not a function of
  # the host, and a caller's own `--cache-dir`, `-j`, `-Doptimize=ReleaseSafe`,
  # `-Dlinkage=dynamic` or step name still reaches the build runner after them.
  # The step names, the linkage the tasks default to and the commands
  # themselves are unchanged.
  tasks = {
    "sdk:build" = {
      description = "Install the static archive, the five public headers and the licence material outside this checkout";
      exec = ''
        # `set -e` because this body has a command after the build: without it a
        # failed install would be masked by the `printf` and the task would
        # report success for an install that did not happen.
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
    # The real consumer: this build graph drives the separate package in
    # `consumer/` as its own `zig build run` (`build.zig`'s `runConsumer`,
    # reached through its `consumer` step), or as `zig build install` when this
    # host cannot execute the selected target. That helper forwards the selected
    # target and CPU, the optimize mode, linkage and runtime route, the
    # selected executor and its libc runtimes, `-j8`, `--summary all`, the
    # caller's `--cache-dir` and `--global-cache-dir`, a caller-named
    # `--prefix`, and the caller's own arguments behind `--`; reaching it
    # through `build.zig`'s `consumer` step rather than from `consumer/` by hand
    # is what keeps that whole selection in the proof.
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
    # `sha256sum -c` resolves every path in the record against the working
    # directory, so this body changes directory rather than naming the record
    # by absolute path. It checks all 66 records: upstream's 59 pinned blobs
    # plus the seven `tools/` files added on 2026-10-04. Narrowing it would
    # weaken the gate it exists to be.
    "sdk:integrity" = {
      description = "Check the pinned upstream blobs against UPSTREAM.sha256";
      exec = ''
        ${inSdk}
        sha256sum -c UPSTREAM.sha256 "$@"
      '';
    };
    # The aggregate of the seven above, in the order they are listed. Its
    # install is the only one here that writes a delivery tree, so it is the
    # only one that chooses a prefix; every one of them chooses a cache.
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
      assertion = lib.assertMsg (zig.version == "0.16.0")
        "libunibreak needs Zig 0.16.0; devenv resolved ${zig.version}";
      message = "libunibreak needs Zig 0.16.0.";
    }
  ];
}