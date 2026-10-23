# Fork notes

## Source deviations

| Upstream path | Fork change | Reason |
|---|---|---|
| `.gitignore` | Appends ignores for Zig and development-tool output; upstream rules remain intact. | Keep fork build artifacts out of the source tree. |
| `README.md` | Replaced by this package's guide; upstream's original is `README.upstream.md`, unchanged. | Separate fork instructions from upstream documentation. |

All upstream C sources, headers, generated tables, fixtures, harnesses, tools and documentation are otherwise unchanged. The fork-owned Zig facade, tests and build files are separate additions.

## Build graph

- `build.zig` compiles upstream's nine `libunibreak_la_SOURCES` in listed order. It does not glob `src/`.
- `src/linebreakdata.c` is a translation unit because it defines externally referenced tables. The six tables in `linebreakauxdata.c`, `wordbreakdata.c`, `graphemebreakdata.c`, `indicconjunctbreakdata.c`, `eastasianwidthdata.c` and `emojidata.c` are included by core units; compiling them separately would duplicate definitions.
- The build uses `-std=c99` for the `inline`/`extern inline` definition of `ub_bsearch`, and sets `UNIBREAK_LAZY_INCB=0` to retain upstream's Unicode lookup behavior.
- Zig compiles the C sources and translates the public headers through `zig/translate.h`; upstream's autotools and make files are not run. Builds require no downloads.
- `-Dlinkage=static` is the default. `-Dlinkage=dynamic` creates a PIC shared library with upstream's `8:0:0` ABI version. The public headers have no import/export annotations, so Windows DLL exports are not declared by the source.
- `-Druntime=true` uses the generated dispatch and explicit provider loader instead of linking the library into the facade. The selected native artifact is still built and installed. There is no system-library mode.
- Installation includes the selected library, five public headers, relocatable pkg-config metadata, licence and provenance records, upstream's README, and `tools/test.txt`. The example and API exercise compile but are not installed.
- `test` runs the facade tests; `exercise` compiles every public method; `smoke` runs the example; `upstream-test` runs upstream's harness from `src/` against the fixtures in place; `consumer` exercises the separate dependency package; `check` compiles the graph for its default target matrix.
- `package.nix`, `flake.nix` and `devenv.nix` invoke the Zig build graph. Nix does not maintain a second list of C sources.

## Platform boundaries

- A C99-capable compiler and Zig 0.16 are required. No other build dependency is fetched or required.
- The default compile-only matrix covers x86_64 Linux GNU, aarch64 Linux GNU, aarch64 macOS, x86_64 Windows GNU, riscv64 Linux GNU and wasm32 WASI.
- `check` proves compilation, not execution. The 53-target `cross-test` profile executes tests only where a runner is available; other targets are build-only.
- Shared delivery requires a dynamic loader. `wasm32-wasi` has none, so a dynamic request fails rather than substituting a static archive; static delivery remains the supported mode there.
