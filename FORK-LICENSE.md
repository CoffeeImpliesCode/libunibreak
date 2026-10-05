# FORK-LICENSE.md — the grant for the files this fork writes

This file records one thing: **what licence covers the code, build files, tests,
documentation and packaging this fork adds**, and where every file that is *not*
under that grant keeps its own. It is the companion to [`NOTICE.md`](NOTICE.md),
which is the per-file audit of **upstream's** 67 blobs and is not repeated here.

Both files exist because this tree is not one licence. The single most common way
to get that wrong is to read the whole package as "zlib", which is what the
dominant file says and what the compiled core is, and which is false for ten of
the compiled material's files and for one upstream tool.

## The authorization

The owner of this SDK authorized, for this migration wave, a **per-project
licence for fork-authored additions, matching the project's primary upstream
terms where appropriate**. That authorization is recorded in the workspace rules
this repository works under — `AGENTS.md` §8 ("Material a package carries is
licensed by its own file … The owner has now authorized per-project licences for
those additions, matching the project's primary upstream terms where
appropriate") — and in the wave contract at
`local://foundation-contract-implementation.md` §"Licence authorization".

Two things it does **not** do, and this file therefore does not do them either:

* it does not extend any upstream grant. Upstream's `LICENCE` covers upstream's
  own code and never covered anything this fork writes;
* it does not name a copyright holder. No personal copyright identity is invented
  here, and fork additions are **not** attributed to upstream's authors.

Earlier records in this repository that said "this fork's own files carry no
licence" / "their status is **unassigned**" described the state *before* that
authorization. They are superseded by this file for the files it lists, and
[`NOTICE.md`](NOTICE.md) now points here instead.

## The chosen grant

| | |
|---|---|
| Grant | Zlib (the zlib/libpng licence) |
| SPDX identifier | `Zlib` |
| Upstream term it matches | `LICENCE` — upstream's own Zlib grant, 1 045 bytes, unmodified |
| Files covered | every file listed under [What this grant covers](#what-this-grant-covers) |
| Files **not** covered | everything else in the tree; see [What this grant does not cover](#what-this-grant-does-not-cover) |

**Why this term.** libunibreak's primary upstream term is Zlib, and the
authorization is to match it. The two conditions Zlib places on a redistributor
— do not misrepresent the origin, and plainly mark altered sources — are the two
this fork already discharges for upstream's code in
[`NOTICE.md`](NOTICE.md) §"The Zlib obligations". The additions are new files
rather than altered upstream files: each is itemised in
[`CHANGELOG.md`](CHANGELOG.md) and carries the SPDX identifier below.

## What this grant covers

Every file below was written for this fork. Nothing in this list is upstream's,
and nothing in it is Unicode's.

| File | What it is |
|---|---|
| `build.zig` | Zig 0.16 build graph |
| `build.zig.zon` | package manifest, `.name = .libunibreak`, `.fingerprint = 0xb4b2629221124f29`, `.paths` allowlist |
| `zig/root.zig` | the typed Zig facade, and `pub const c` for the whole translated surface |
| `runtime/generate.zig`, `runtime/graph.zig`, `runtime/library.zig`, `runtime/loader.zig`, `runtime/sync.c`, `runtime/sync.h` | the runtime-loading route `build.zig` substitutes for `translate.createModule()` under `-Druntime=true`, one directory because the loader core, its generated dispatch and the descriptor that binds them travel together. Four carry `SPDX-License-Identifier: Zlib`; `runtime/graph.zig` and `runtime/library.zig` carry `MIT` — see below |
| `zig/api_exercise.zig` | explicit instantiation of every public facade method and every translated entry point |
| `zig/translate.h` | the one header `addTranslateC` translates: it names upstream's five public headers and re-declares nothing |
| `tests.zig` | behavioural and fixture-conformance tests |
| `smoke.zig` | the deterministic example behind `zig build smoke` |
| `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig` | a separate package that depends on this one by relative path and runs it |
| `cross-test.profile.sh` | settings-only harness configuration sourced by `cross-test` |
| `.github/workflows/verify.yml` | this fork's own verification workflow; it publishes nothing and uploads nothing |
| `package.nix` | the standalone Nix derivation: static and shared variants, both built by `build.zig` |
| `flake.nix` | pinned-nixpkgs entry points: `packages.<system>.default`, `.static`, `.shared`, and a dev shell |
| `devenv.nix` | the canonical development shell: tools only, no SDK package |
| `devenv.yaml` | the pinned development-shell nixpkgs input |
| `.envrc` | direnv integration: `devenv direnvrc` and `use devenv`, no pinned URL of this fork's own |
| `README.md` | this fork's README: current native-source deviations, current native-build deviations and their history, the current build/run/test matrix, and consumption |
| `README.zig.md` | the Zig interface documentation, kept separate from `README.md` |
| `CHANGELOG.md` | numbered fork-only divergences |
| `FORK-NOTES.md` | what went wrong while forking this library and what was decided |
| `FORK-LICENSE.md` | this file |
| `NOTICE.md` | the per-file audit of upstream's tree, and the inventory of this fork's own files |
| `UPSTREAM.md` | the pin, the archive receipt, what is compiled and how, and the verification boundary |
| `UPSTREAM.sha256` | per-file digests of the upstream blobs this package ships, plus the carried Unicode terms text |

The `.gitignore` in this tree is **not** in that list: upstream's 43 lines are
kept verbatim and this fork appends its own block, so the file is upstream's file
with an addition, and `UPSTREAM.md` and `NOTICE.md` name both digests.

`flake.lock` also travels with the package and is in that list's neighbourhood
without being in it: it is generated by evaluating `flake.nix`, not written by
hand, so it carries no grant of its own. `devenv.lock` does not exist — no devenv
shell has been entered — and nothing here invents one.

## What this grant does not cover

The grant above is a grant over the files this fork writes. It changes nothing
about the terms of any other file in the tree, and in particular it does not
reach:

| Material | Its own term | Where it is stated |
|---|---|---|
| upstream's C sources, headers, generators, harness, tools, build files and `doc/architecture.md` | Zlib, upstream's own grant | [`LICENCE`](LICENCE), unmodified |
| the 7 generated UCD tables and the 3 conformance fixtures compiled into, or carried with, the library | the Unicode terms — Unicode License v3 | each fixture's own first lines, plus [`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt), carried verbatim |
| `tools/linebreak_test.c` | its own separate, broader grant | its own text, `tools/linebreak_test.c:9-13` |
| `tools/wordbreak_test.c`, `tools/graphemebreak_test.c`, `tools/linebreak_bench.c`, `tools/wordbreak_bench.c`, `tools/graphemebreak_bench.c`, `tools/test.txt` | no notice of any kind in the files; they are upstream material under the tree-level `LICENCE` grant | named in [`NOTICE.md`](NOTICE.md) so an auditor is not left looking for a header that was never written |
| [`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) | Unicode's own text, fetched and carried unchanged; not a grant by this fork | its own header lines |
| [`README.upstream.md`](README.upstream.md) | upstream's README, byte-identical to the pinned commit's blob, under upstream's Zlib grant | [`UPSTREAM.md`](UPSTREAM.md), [`UPSTREAM.sha256`](UPSTREAM.sha256) |

The seven generated tables are the load-bearing exception and the reason this file
exists. Six of them (`linebreakauxdata.c`, `wordbreakdata.c`,
`graphemebreakdata.c`, `indicconjunctbreakdata.c`, `eastasianwidthdata.c`,
`emojidata.c`) are **textually included** by a compiled translation unit and the
seventh (`linebreakdata.c`) is compiled on its own, so seven of the nine
translation units in the delivered archive are substantially or entirely
Unicode-derived data. A Zlib label on this package would be a misdescription of
the shipped archive even though it is a correct description of the code.

**No single label overrides those file-specific terms.** A downstream that
redistributes the archive is bound by the Unicode terms for the data inside it,
whether or not it reads this file.

## Identifier for newly authored files

Other roles add this identifier to the source and build files they author:

```
SPDX-License-Identifier: Zlib
```

In a C header or a `.c`/`.h` file it is a `/* … */` comment; in Zig, ZON, Nix or
YAML a `// …` or `# …` comment on its own line. It is a machine-readable pointer
to this record, not a substitute for it: the per-file inventory above, and
`NOTICE.md`'s audit of the 67 upstream blobs, are the authority for which term
covers which file.

**Two files in the tree carry a different identifier.** `runtime/graph.zig` and
`runtime/library.zig` open with `SPDX-License-Identifier: MIT`, not `Zlib`,
while the four files beside them in that directory carry `Zlib`. That is what
the source says; this record does not restate either licence's terms, and it
does not resolve the difference. The grant over the files this fork writes is
the one above and the inventory above is where each file's own header is
recorded, so a reader who needs to know which identifier a given file carries
has the answer without this file paraphrasing either term.

## Where licence material is installed

An installed output carries the terms of what it contains. `build.zig` installs
all of it, through `zig build install --prefix "$out"`, and `package.nix` adds
nothing: one writer per path.

| Path | Contents |
|---|---|
| `$out/lib/libunibreak.a` (or the shared library), `$out/include/*.h`, `$out/lib/pkgconfig/libunibreak.pc` | the library, its five public headers, its link metadata; `build.zig`'s `addPkgConfig` writes the `.pc` under `lib/pkgconfig/`, and `package.nix` looks it up there by `find` |
| `$out/LICENCE` | upstream's Zlib grant, unmodified |
| `$out/LICENCE-UNICODE.txt` | the Unicode terms that govern the data inside the archive |
| `$out/README.upstream.md` | upstream's README, byte-identical to the pinned blob |
| `$out/share/licenses/libunibreak/NOTICE.md` | the per-file audit of upstream's 67 blobs |
| `$out/share/licenses/libunibreak/FORK-LICENSE.md` | this file |
| `$out/share/licenses/libunibreak/UPSTREAM.md` | the pin and the provenance record |
| `$out/share/licenses/libunibreak/{LICENCE,LICENCE-UNICODE.txt,AUTHORS,README.upstream.md,FORK-NOTES.md,UPSTREAM.sha256}` | upstream's grant, the carried Unicode terms, upstream's authorship file, upstream's README, and this fork's own two records, installed into that directory by `installLicenceRecords` walking `licence_records` |
| `$out/share/libunibreak/` | the three Unicode conformance fixtures and upstream's `tools/test.txt`, under the terms already installed beside them |

That directory receives **nine** records: the three named by their own
`b.installFile` calls in `build.zig`'s `build` and the six in the row above it.
`LICENCE`, `LICENCE-UNICODE.txt` and `README.upstream.md` install there and at
the prefix root, from the same `b.installFile` call each.

## Status

| Claim | Status |
|---|---|
| The grant, the identifier, the file lists and the install paths above | `SOURCE-CONFIRMED` — read out of the files named, at commit `28a2756b864c343f438cd22537d49d394d4666a5` and in this working tree |
| That `zig build install` and `package.nix` produce exactly those paths | `PENDING-VERIFICATION` — the contract is declared here and the build-graph and derivation work landed in this wave; no gate has observed the install layout since |
| Anything about the terms' own text | not restated: `LICENCE` and `LICENCE-UNICODE.txt` ship verbatim and are not paraphrased anywhere in this fork |