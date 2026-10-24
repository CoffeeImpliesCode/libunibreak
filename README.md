# libunibreak

A Zig 0.17.0 package for upstream libunibreak 8.0, with a typed Zig facade over its C library.
The bundled Unicode data is version 17.0.0.

## Source deviations from upstream

Upstream's C sources, headers, generated tables, fixtures, tools and README are unchanged. The only edited upstream path is `.gitignore`: its 43 original lines remain, followed by this fork's Zig ignore rules. The fork adds the Zig facade (`zig/`), runtime loader (`runtime/`), tests, example, build files and consumer package. `README.upstream.md` preserves upstream's README byte for byte.

See `UPSTREAM.md` for the pinned tag and commit, and `NOTICE.md` and `FORK-LICENSE.md` for file-level licence terms.

## Build deviations

`build.zig` compiles upstream's nine `libunibreak_la_SOURCES` translation units explicitly; it does not glob `src/`. It uses C99 and sets `UNIBREAK_LAZY_INCB=0`. It does not run Autotools, Make or `configure`, and the build downloads no source.

`zig build` installs the selected native library, the five public headers, pkg-config metadata and licence files. `zig build test` runs the facade tests; `zig build upstream-test` runs upstream's unmodified harness from `src/` against the checked-in fixtures. `zig build check` compiles a target matrix without running its binaries.

Nix uses the same Zig build graph. The flake declares static and shared outputs; `default` selects static. Build them with `nix build .#static` or `nix build .#shared`.

## Support matrix

| Route | Targets | Coverage |
|---|---|---|
| `zig build check` | `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`, `x86_64-windows-gnu`, `riscv64-linux-gnu`, `wasm32-wasi` | Compile-only; no binaries run. |
| `cross-test` | 53-target profile | Uses the static, linked test graph. Runs where an executor is available; otherwise reports build-only. |
| Shared linkage | Targets with a dynamic linker | `wasm32-wasi` has no dynamic linker and is refused for `-Dlinkage=dynamic`; static linkage remains available. |
| Nix flake | `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin` | Declares static and shared packages. |

A compile-only or build-only result does not establish runtime support on that target.

## Consumption

Fetch the GitHub dependency into `build.zig.zon`:

```sh
zig fetch --save git+https://github.com/CoffeeImpliesCode/libunibreak#v8.0.0
```

Import the `libunibreak` module; the dependency supplies the facade, translated headers and native library:

```zig
const dep = b.dependency("libunibreak", .{ .target = target, .optimize = optimize });
exe_mod.addImport("libunibreak", dep.module("libunibreak"));
```

The module is `libunibreak`; the native artifact is `unibreak` (`libunibreak.a` for a static POSIX build). Use `dep.artifact("unibreak")` for the library alone, or `@import("libunibreak").c` for the translated C declarations. There is no system-library mode.
A C consumer includes the installed public headers and links `-lunibreak`; the installed `libunibreak.pc` supplies the link flags.

| Option | Default | Effect |
|---|---|---|
| `-Dlinkage=static\|dynamic` | `static` | Select the installed archive or shared library. |
| `-Druntime=true` | `false` | Resolve native calls through an explicit runtime load; independent of linkage. |
| `-Dtarget=<triple>` | Host target | Select the target. |
| `-Doptimize=<mode>` | Zig default | Select the optimization mode. |

See `README.zig.md` for facade types, methods and errors.
