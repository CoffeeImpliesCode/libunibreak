# Upstream

| Field | Value |
|---|---|
| Project | libunibreak, Unicode line, word and grapheme breaking in C |
| Canonical repository | `https://github.com/adah1972/libunibreak.git` |
| Version | C library 8.0; package manifest 8.0.0 |
| Upstream reference | Lightweight tag `libunibreak_8_0` |
| Commit | `28a2756b864c343f438cd22537d49d394d4666a5` |
| Data | Unicode 17.0.0; UAX #14 Revision 55 and UAX #29 Revision 47 |
| Source acquisition | Full clone of the canonical Git repository; no upstream patch series |
| SHA-256 of deterministic `git archive` stream at the pin | `f9b8ff046faf06a0ca5dd61aeddb430b456aaf4959ef4e91beb48481b5df7408` |
| Release asset SHA-256 (`libunibreak-8.0.tar.gz`, GitHub release API) | `9c4fad6e517338a098373acc9f35579ae2c325e6446666fb9ac2666ba15ceba4` |

## Imported files

The pinned upstream tree has 67 blobs. The package ships 66 upstream-owned files; their digests are in `UPSTREAM.sha256`.

| Package path | Files |
|---|---:|
| `src/` | 45 |
| `doc/architecture.md` | 1 |
| `tools/` | 7 |
| Upstream root files | 13 |
| Total | 66 |

The `src/` tree includes the nine library translation units, headers, generated Unicode data, conformance fixtures, upstream's test harness and generators. `tools/` is shipped because the install step includes `tools/test.txt`; its example programs are not built. The source file list comes from upstream's `src/Makefile.am`.

## Renamed, modified and omitted upstream paths

- Upstream's `README` is carried byte-identically as `README.upstream.md`.
- `.gitignore` retains upstream's rules and adds fork-specific Zig ignores; it is excluded from `.paths` and `UPSTREAM.sha256` because it is no longer byte-identical.
- No upstream files were removed. The archive's empty `objs/` directory is not packaged.

`UPSTREAM.sha256` records the 66 upstream-owned package files. Run `sha256sum -c UPSTREAM.sha256` to check the per-file digests.
