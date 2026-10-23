# FORK-LICENSE.md

## Grant

The owner of this SDK authorized, for this migration wave, a **per-project licence for fork-authored additions, matching the project's primary upstream terms where appropriate**. The authorization is recorded in `AGENTS.md` and `foundation-contract-implementation.md`.

This grant does not extend upstream's licence or name a copyright holder. Fork additions are not attributed to upstream authors.

| Item | Term |
|---|---|
| Grant | Zlib (`SPDX-License-Identifier: Zlib`) |
| Upstream term matched | `LICENCE` (1,045 bytes, unchanged) |
| Upstream project | libunibreak; pin and source inventory are in `UPSTREAM.md` |
| Covered files | Fork-authored files listed below |
| Excluded files | All other files; see the table below |

## Covered fork-authored files

Every file listed here was written for this fork. No listed file is upstream's or Unicode's.

| File(s) | Contents |
|---|---|
| `build.zig` | Zig build graph |
| `build.zig.zon` | Package manifest and `.paths` allowlist |
| `zig/root.zig` | Typed facade and translated `pub const c` interface |
| `runtime/generate.zig`, `runtime/loader.zig`, `runtime/sync.c`, `runtime/sync.h` | Runtime-loading route selected by `-Druntime=true`; Zlib identifiers |
| `runtime/graph.zig`, `runtime/library.zig` | Runtime graph and provider checks; MIT identifiers |
| `zig/api_exercise.zig` | Public facade and translated-entry-point instantiations |
| `zig/translate.h` | Translation header naming upstream's five public headers; declares none |
| `tests.zig` | Behavioral and fixture-conformance tests |
| `smoke.zig` | Deterministic `zig build smoke` example |
| `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig` | Downstream package using this package by relative path |
| `cross-test.profile.sh` | Settings sourced by `cross-test` |
| `package.nix` | Standalone Nix derivation |
| `flake.nix` | Nix packages and development shell |
| `devenv.nix`, `devenv.yaml` | Development shell and pinned nixpkgs input |
| `.envrc` | direnv integration |
| `README.md` | Fork build, support, and consumption instructions |
| `README.zig.md` | Zig facade API reference |
| `CHANGELOG.md` | Fork-only changes |
| `FORK-NOTES.md` | Source and build deviations |
| `FORK-LICENSE.md` | This grant and file inventory |
| `NOTICE.md` | Per-file audit of upstream's 67 blobs and fork files |
| `UPSTREAM.md` | Upstream pin and imported/removed-path inventory |
| `UPSTREAM.sha256` | Digests of upstream-owned files and carried Unicode terms |

The upstream `.gitignore` retains its 43 original lines with fork-specific rules appended; `UPSTREAM.md` and `NOTICE.md` record both digests. `flake.lock` travels with the package but is generated from `flake.nix`, not hand-authored under this grant.

## Excluded material and terms

| Material | Term and scope |
|---|---|
| Upstream C sources, headers, generators, harness, tools, build files, and `doc/architecture.md` | Upstream Zlib grant in [`LICENCE`](LICENCE), unmodified |
| Seven generated UCD tables compiled into the library and three conformance fixtures carried with it | Unicode License v3; fixture headers and [`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) |
| `tools/linebreak_test.c` | Separate, broader grant in its own text |
| `tools/wordbreak_test.c`, `tools/graphemebreak_test.c`, `tools/linebreak_bench.c`, `tools/wordbreak_bench.c`, `tools/graphemebreak_bench.c`, `tools/test.txt` | Upstream material without file notices; covered by `LICENCE` and listed in `NOTICE.md` |
| [`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) | Unicode's own text, carried unchanged; not a grant by this fork |
| [`README.upstream.md`](README.upstream.md) | Upstream README under its Zlib grant, byte-identical to the pinned blob; see `UPSTREAM.md` and `UPSTREAM.sha256` |

Six generated tables (`linebreakauxdata.c`, `wordbreakdata.c`, `graphemebreakdata.c`, `indicconjunctbreakdata.c`, `eastasianwidthdata.c`, `emojidata.c`) are textually included; `linebreakdata.c` is compiled separately. These seven Unicode-derived files make up seven of the archive's nine translation units. Redistributors remain bound by Unicode terms for this data; the Zlib grant does not override them.

## SPDX identifiers

The grant's identifier is:

```
SPDX-License-Identifier: Zlib
```

`runtime/graph.zig` and `runtime/library.zig` declare MIT; `runtime/generate.zig`, `runtime/loader.zig`, `runtime/sync.c`, and `runtime/sync.h` declare Zlib. The difference between those headers and the grant is unresolved.

## Installed licence material

Install outputs carry the terms of their contents.

| Prefix path | Contents and terms |
|---|---|
| `$out/lib/libunibreak.a` or shared library, `$out/include/*.h`, `$out/lib/pkgconfig/libunibreak.pc` | Library, public headers, and link metadata |
| `$out/LICENCE` | Upstream Zlib grant |
| `$out/LICENCE-UNICODE.txt` | Unicode terms for generated data |
| `$out/README.upstream.md` | Upstream README |
| `$out/share/licenses/libunibreak/` | `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md`, `LICENCE`, `LICENCE-UNICODE.txt`, `AUTHORS`, `README.upstream.md`, `FORK-NOTES.md`, `UPSTREAM.sha256` |
| `$out/share/libunibreak/` | Three Unicode conformance fixtures and upstream's `tools/test.txt`; terms are installed under `$out/share/licenses/libunibreak/` |
