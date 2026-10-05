# libunibreak — this fork's README

**This file is not upstream's README.** Upstream's own README is carried
unchanged, byte for byte, as [`README.upstream.md`](README.upstream.md) (2 996
bytes, SHA-256 `cc38c7b8…`, the pinned commit's blob) and is also recorded by
digest in [`UPSTREAM.sha256`](UPSTREAM.sha256). Upstream's project page is
`https://github.com/adah1972/libunibreak`.

| | |
|---|---|
| What this is | upstream's own libunibreak 8.0 C library, compiled from source in this repository, with a Zig 0.16.0 facade, static and shared delivery, optional runtime loading, and standalone Nix/devenv packaging |
| Upstream | [`adah1972/libunibreak`](UPSTREAM.md), tag `libunibreak_8_0`, commit `28a2756b864c343f438cd22537d49d394d4666a5` |
| Version of the C library built here | 8.0 (`src/unibreakbase.h`'s `UNIBREAK_VERSION 0x0800`) |
| Unicode revision of the data | **17.0.0** — UAX #14 Revision 55, UAX #29 Revision 47 |
| Zig package | `.libunibreak`, fingerprint `0xb4b2629221124f29`, minimum Zig 0.16.0 |
| Requires | Zig 0.16.0 and a C99 compiler. No other dependency, and nothing is downloaded at build time. |
| Licence | zlib over upstream's code, the Unicode terms over the generated tables and fixtures. See [`FORK-LICENSE.md`](FORK-LICENSE.md) and [`NOTICE.md`](NOTICE.md). |

The Zig interface — types, methods, error taxonomy, examples and the
authoritative gate table — is documented separately in
[`README.zig.md`](README.zig.md). This file is the orientation document:
deviations, delivery, status, and how to consume the result.

---

## 1. Current native-source deviations

**None.** No upstream C source, header, generated table, conformance fixture,
test harness, generator or documentation file is altered, reformatted or
patched in this fork.

That statement is checkable rather than asserted: [`UPSTREAM.sha256`](UPSTREAM.sha256)
records **66** of upstream's 67 blobs by digest — 59 derived from the pinned
commit's object store on 2026-10-03, and the seven `tools/` files added
2026-10-04 when `.paths` began carrying that directory, each read again from the
working tree and in agreement, with no new pinned-object comparison run for them
— and `sha256sum -c UPSTREAM.sha256` is the first step of this fork's own CI job.
The comparison of all 67 pinned blobs against this tree found exactly one difference,
and it is not source:

| File | What differs | Where it is recorded |
|---|---|---|
| `.gitignore` | upstream's 43 lines are kept verbatim; this fork appends its own Zig block, so the working-tree file is not upstream's bytes | [`NOTICE.md`](NOTICE.md), [`UPSTREAM.md`](UPSTREAM.md) §"What is upstream's and is shipped unmodified" — both digests are named |

Everything else in the tree is either upstream's byte-identical file or a file
this fork wrote ([`FORK-LICENSE.md`](FORK-LICENSE.md) lists the fork's own
files).

### The data this fork ships, and its terms

Seven of the nine compiled translation units, or their textual includes, are
**generated Unicode Character Database tables**, and the licence of the compiled
core is therefore not the same question as the licence of the source text:

* `src/linebreakdata.c` is a compiled translation unit in its own right
  (`src/linebreakdef.h` declares `lb_prop_supplementary` and `lb_prop_bmp`
  `extern`);
* `src/linebreakauxdata.c`, `src/wordbreakdata.c`, `src/graphemebreakdata.c`,
  `src/indicconjunctbreakdata.c`, `src/eastasianwidthdata.c` and
  `src/emojidata.c` are **textually included** by a translation unit rather than
  compiled separately — compiling them as well would be a duplicate definition
  of every table they contain;
* the three conformance fixtures `src/LineBreakTest.txt`,
  `src/WordBreakTest.txt` and `src/GraphemeBreakTest.txt` are Unicode material
  used in place as this package's own oracle.

The seven tables carry **no in-file grant at all**, only a generation banner; the
three fixtures carry the Unicode notice in their own first lines. The terms that
cover all ten are carried verbatim as
[`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) and installed beside the archive.
Upstream's Zlib grant is carried verbatim as [`LICENCE`](LICENCE). The per-file
inventory, including `tools/linebreak_test.c`'s separate broader grant and the
five `tools/` programs that carry no notice at all, is [`NOTICE.md`](NOTICE.md).

### Unicode 17 here, Unicode 18 there

This library is **Unicode 17.0.0**. The `utf8proc` package in the same workspace
is **Unicode 18.0.0**. The two do not agree on grapheme clusters for text using
characters or properties that changed between those revisions, so comparing
their answers to each other compares two different standards; no test in this
package assumes they match. The revision is a property of this package and is
recorded in [`UPSTREAM.md`](UPSTREAM.md).

---

## 2. Current native-build deviations

Upstream builds with autoconfiscation, `Makefile.gcc` and `Makefile.msvc`. None
of them is executed here, and none of them is patched.

### What `build.zig` does now — `SOURCE-CONFIRMED`

| Deviation | Why | Where the source says it |
|---|---|---|
| The nine translation units of `libunibreak_la_SOURCES` are named explicitly, in upstream's order, rather than globbed | a `src/*.c` glob would compile the six textually included tables and fail on duplicate definitions | `src/Makefile.am:11-20`, `build.zig`'s `core_sources` |
| `-std=c99` on every translation unit | load-bearing, not stylistic: `ub_bsearch` is a C99 `inline` definition (`src/unibreakdef.h:65`) closed by `extern inline` at `src/unibreakdef.c:175`, and under C89 that emits no symbol at all, so every translation unit that binary-searches a table fails to **link** — a failure that looks like a missing symbol, not like a dialect problem. No upstream makefile passes a dialect flag and relies on the compiler default | `build.zig`'s `c_flags` |
| `-DUNIBREAK_LAZY_INCB=0` stated on the compile line | the retained upstream default of the one macro that changes how the library compiles; since Unicode 16.0 `InCB=Consonant` is assigned to characters whose `GCB` is `Other`, so the lookup cannot be skipped | `src/graphemebreak.c:57-63` |
| `-D_DEBUG`/`-DNDEBUG` is left to the chosen optimize mode, exactly as upstream's own configurations map it | so `wordbreak.c`'s unreachable-default `assert(0)` and `unibreakdef.c`'s three `assert(*ip <= len)` are present in Debug and ReleaseSafe and gone in ReleaseFast and ReleaseSmall, as upstream arranged them | `src/Makefile.gcc:91-92` |
| Upstream's `src/tests.c` is built and run three times, from `src/`, against the three fixtures in place | no copy, no symlink, no rewritten fixture, and upstream's own exit status is the result | `src/Makefile.am:121-134` |
| `tools/` is carried in the package because the install step reads one file out of it, and **none of its six programs is compiled here** | `zig build install` ships `tools/test.txt` under `share/libunibreak/`, so a fetched copy that lacked the directory would fail to install on a file this tree has always had. Carrying the bytes is not a claim that they build: `tools/linebreak_test.c` still reaches outside the standard headers for `<iconv.h>`, which is why `build.zig`'s `core_sources` still names nine translation units and globs nothing | [`FORK-NOTES.md`](FORK-NOTES.md) §14 and §27, [`CHANGELOG.md`](CHANGELOG.md) entry 31 |
| No system-library mode, recorded as NOT APPLICABLE | a real installed libunibreak with matching headers cannot be promised for the six matrix targets, so nothing here links `-lunibreak` from outside the tree | `build.zig`'s header comment |

### Delivery modes

Two build options change how the library arrives, not the interface:

| Option | Default | Effect |
|---|---|---|
| `-Dlinkage=static\|dynamic` | `static` | which artifact is installed and linked: `libunibreak.a`, or the shared object. `static` means a static *library artifact*; nothing here promises a statically linked executable. A shared build is PIC with a real export surface — a `.so` name on an object that exports nothing is not a shared build |
| `-Druntime=true` | off | the facade stops linking the source library. The caller calls `load(.{ .path = … })` or `load(.{ .system = … })` once, then makes ordinary module calls. One process-lifetime table per configured module, published atomically; a failed candidate never publishes; no fallback from an explicit path to a system name, and no automatic retry; an ordinary panic before publication in every optimize mode, `ReleaseFast` and `ReleaseSmall` included. See §4c for the ABI this library actually requires |

The native artifact is built and installed either way, and the root exports
`load` and its source and error types under the second option. The gates for both
are in §3.

### History

Every change this fork has made to this library is one numbered entry in
[`CHANGELOG.md`](CHANGELOG.md), and the numbers are stable identifiers. Entries
1–23 are the source, facade, test and documentation work, taken before this
migration. Entries 24–28 are this migration, dated 2026-10-04: the README
relocation, the licence grant for fork-authored files, the integrity record's
re-pointing, the Nix/devenv packaging, and the delivery contract this wave
requires of the build graph and the API. Entry 29 is the two-code-point UTF-32
correction. Entries 30–33, also 2026-10-04, are this correction pass: the
option name as it is actually declared, the two files the install step reads
that `.paths` did not carry, two dated status sentences the current source no
longer supports, and the Nix and devenv entry points §5 advertises, which now
travel with the package. Entries 34–39 are the same day's later passes: the
integrity record's `tools/` additions, a documentation qualification, a
corrected comment, and the two citation repairs. Entry 40, also 2026-10-04, is
the devenv repair §5 describes — every task now names this tree for itself, and
the two that install choose a prefix outside it. The problems met while doing
all of it, and what was decided, are in [`FORK-NOTES.md`](FORK-NOTES.md).

---

## 3. Build, run and test matrix

Every row is either a receipt or a row the driver has not run yet. Rows marked
**pre-migration** were taken on 2026-10-03, against the tree as it stood then, and
predate the delivery options, the link metadata and the packaging; they are not
results for those. The rows dated 2026-10-04 and 2026-10-05 are the current
graph's own waves, and each names the epoch it came from. No row claims a result
no run printed, and no row counts a cell that compiled but never ran as a pass.
Full receipts, with optimize modes, exit codes and receipt paths, are in
[`README.zig.md`](README.zig.md#verification-status).

| Gate | Command | Status |
|---|---|---|
| Build, install, tests, exercise, example, consumer, upstream's harness — Debug, pre-migration | `zig build install test smoke consumer upstream-test` | **OBSERVED** 2026-10-03, exit 0: `23/23 steps succeeded; 15/15 tests passed`; upstream's `src/tests.c` ran three times, each fixture at 100 % |
| Tests, example, consumer — ReleaseSafe / ReleaseFast / ReleaseSmall, pre-migration | `zig build test smoke consumer -Doptimize=…` | **OBSERVED** 2026-10-03, exit 0 in each: `13/13 steps succeeded; 15/15 tests passed` |
| Six-target compile-only check, pre-migration | `zig build check` | **OBSERVED** 2026-10-03, exit 0: `43/43 steps succeeded`, nothing run |
| Installed C surface, pre-migration | `zig cc` against the installed prefix and headers, then run | **OBSERVED** 2026-10-03, compile and run both exit 0, every check `ok` |
| Integrity, pre-migration | `sha256sum -c UPSTREAM.sha256` | **OBSERVED** 2026-10-03, exit 0, 59 `OK` |
| 53-platform `cross-test`, pre-migration | `cross-test` | **PARTIAL** 2026-10-03: 53 of 53 targets built, **20 ran** the test step with 15 tests each, **33 `build_only`** for want of a runtime, 0 failed |
| Typed-API example in `README.zig.md` | extracted from the document and run | **OBSERVED** 2026-10-03, exit 0: `6/6 steps succeeded` |
| Static native output, four optimize modes | `zig build install -Dlinkage=static -Doptimize=…` | **PENDING-VERIFICATION** |
| Shared native output, four modes, export list read | `zig build install -Dlinkage=dynamic -Doptimize=…`, then read the exports | **PENDING-VERIFICATION** |
| Behavioural and fixture gates on the current tree | `zig build test smoke consumer upstream-test`, Debug and ReleaseSafe | **PENDING-VERIFICATION** |
| Typed and raw consumers | `zig build check` | **PENDING-VERIFICATION** |
| Runtime-loaded route: startup, failure, retry, idempotence, provider change, atomic publication, release-mode panic | the `-Druntime=true` builds and their consumer checks, `ReleaseFast` and `ReleaseSmall` included | **PENDING-VERIFICATION** |
| Installed C consumer and its link metadata | `zig cc` against the prefix; `pkg-config --cflags --libs libunibreak` against the packaged output | **PENDING-VERIFICATION** |
| Fetched, filtered Zig consumer | driver-owned; `local://foundation-matrix-final-package-proof.json` | **PENDING-VERIFICATION** |
| Six baseline targets and the 53-platform matrix, on the current graph | `zig build check` for the six; `cross-test` for the fifty-three | **OBSERVED** on the current graph, twice, and neither is a runtime pass on its own. Cohort `20261004T221720228710Z-45046`, receipt `libunibreak-53-target-8.json`: **53 targets, 20 runtime PASS, 33 `build_only`, 0 failed**, driver exit 0, `source_unchanged: true`, `jobs_honoured: true`, 18 tests in each of the 20 that ran. Baseline `20261005T014547Z-797a73f2`, row `baseline-libunibreak-check`: compile-only whole-graph `check` over the six declared targets, `43/43 steps succeeded`, exit 0, `failed: false`, `runtime_pass_claimed: false`. A green baseline row proves compilation and nothing about running |
| `devenv shell` and its tasks | canonical shell; `devenv tasks run sdk:gate` | **PENDING-VERIFICATION** |
| Packaged static and shared outputs | `devenv build outputs.static` / `outputs.shared`, or `nix build .#static` / `.#shared`; `nix-store --query --references` on each output | **PENDING-VERIFICATION** |
| Integrity after the README relocation and the `tools/` addition | `sha256sum -c UPSTREAM.sha256` | **PENDING-VERIFICATION** — the record now names `README.upstream.md` and holds 66 records; the 59 `OK` lines above are the earlier observation, not this one |
| Nested consumer delivery: four routes, nine cases | `zig build consumer`, the `consumer/` package, one case per route | **OBSERVED**, bounded, nested-delivery-proof run `20261004T220323250122Z-515d06adcbbf`: **9/9 PASS**. All four routes — static and dynamic delivery, linked and runtime-loaded dispatch — each with the selections omitted and each with `target`, backend, `linkage`, `runtime`, both caches and the prefix named explicitly; the loaded route reached its provider through `--provider` on argv with every provider environment variable absent; the same run without a provider exited 1 with the refusal. The nested prefix relay's actual argv and the installed inventory both agree |
| Own provider loaded into all eight configurations | `zig build test smoke install -Druntime=true`, two linkages × four optimize modes | **OBSERVED**, pass: run `20261004T232823091897Z-23133`, **8/8 cells**, each `Build Summary: 32/32 steps succeeded; 20/20 tests passed`, `smoke success` and `test success`, none skipped |
| This tree's own source linked into all eight configurations — the native route | `zig build test smoke install`, `{static, dynamic}` × `{Debug, ReleaseSafe, ReleaseFast, ReleaseSmall}`, no `-Druntime` | **OBSERVED**, partial, run `20261004T233628757747Z-69351`: **8 cells, none of them a pass**. Every cell is `status: skipped-tests`, exit 0, each `Build Summary: 31/31 steps succeeded; 18/20 tests passed (2 skipped)`. The two skips are the runtime-loading guards at `tests.zig:131` and `tests.zig:142`, both `if (!libunibreak.runtime_loaded) return error.SkipZigTest;`; those two tests exist only on the loaded route, so a linked cell cannot reach them. 18 of 20 is the ceiling on this route, not a shortfall |
| External provider in the same eight configurations | the same command with `LIBUNIBREAK_TEST_PROVIDER` naming `/lib64/libunibreak.so.5.0.1` (sha256 `dca1509ee9cac0e321eef98a83eb38fd1bed52c6c45eaba6d4d383f36139b10d`) | **OBSERVED**, failing: run `20261004T233121760876Z-12541`, **0/8 cells**, exit 1; each `Build Summary: 30/32 steps succeeded (1 failed); 17/20 tests passed (3 failed)` after `smoke success` at `library version 0x+501`. The three failures are the three Unicode conformance replays, identical in every cell: `LineBreakTest.txt` line 35 position 0 (expected a break marker, got `no_break`), `WordBreakTest.txt` line 1059 position 0 (got `allow_break`), `GraphemeBreakTest.txt` line 771 position 1 (got `no_break`). **This is three failing fixture rows against an external provider, not a defect in this SDK and not a pass.** What was observed about that provider is its image path, its sha256, its file name and soname carrying `5.0.1` and `5`, and its `unibreak_version` word `0x0501`; this package is pinned to `0x0800`, whose tables were generated from UAX #14 revision 55 and UAX #29 revision 47 (Unicode 17.0), and the route probe states outright that it makes no comparison. **The cause of the three failures is not established**: a soname is an ABI tag rather than a release number, and no external Unicode or UCD version was queried. Nothing here shows this SDK is Unicode-version-agnostic, nothing shows that a table-version difference is what failed, and nothing shows what a provider matching this package's own pin would do — that run was not made. The narrower external probe it does not replace, and the loader boundary, are in [`CHANGELOG.md`](CHANGELOG.md) §45 |
| CI | `.github/workflows/verify.yml` | **NOT RUN** — local and unpublished |

**What that one row covers.** Nine cases of the nested consumer build and
nothing else. It does not move the `zig build test smoke consumer upstream-test`
row above it, which also runs three other steps in two optimize modes, and it
is not evidence for the six baseline targets, the 53-platform matrix, the
filtered-fetch consumer, the packaged outputs or the devenv tasks. What it does
establish is that the four delivery routes a caller can ask for are four routes
that run, that the provider reaches a loaded program through the argument the
caller typed rather than through an environment variable it might also have
set, and that a missing provider is refused instead of resolved some other way.

Three routes, eight configurations each, one source tree. **Linked against this
tree's own image, all eight cells are partial**: 18 of 20, with the two loader
tests unreachable by construction. **Loaded with this tree's own
`libunibreak.so.8.0.0` as the provider, all eight pass**: 20 of 20, because there
the two loader tests do run. **Loaded with the external image
`/lib64/libunibreak.so.5.0.1`, all eight fail**: 17 of 20, the same three
fixture rows in every cell, and why those three fail is not established. Those
three numbers describe three
different routes, not three qualities of one; the only route on which all twenty
tests run is the loaded one, and the only provider that has answered all twenty
correctly is the one this tree built. The earlier external probe covered one
target, one linkage and mode and a handful of named rules, and never replayed the
fixtures through a loaded provider, so it supports none of the eight cells.
[`CHANGELOG.md`](CHANGELOG.md) §45 carries the numbers and the boundary this
package already documents.

A compiled foreign test binary is `build_only`, never a pass. In cohort
`20261004T221720228710Z-45046` (receipt `libunibreak-53-target-8.json`) 20 of the
53 published platforms ran the test step and 33 built with no runner available, so
the cohort is **20 runtime passes and 33 compiles, not 53 passes**, and the
driver's exit 0 means every target compiled, not that every target ran. Nothing
in this package claims the library runs everywhere it compiles, and nothing here
claims conformance for a provider this SDK did not build.

The driver's foreign-delivery candidate for this SDK, `libunibreak.txt`, is a
**candidate analysis only** — the twelve-byte check has not been executed, so no
foreign cell is claimed here in either direction.

---

## 4. Consumption

### 4a. The Zig facade

```zig
// build.zig.zon
.dependencies = .{
    .libunibreak = .{ .path = "../libunibreak" },
},

// build.zig
const dep = b.dependency("libunibreak", .{
    .target = target,
    .optimize = optimize,
});
exe_mod.addImport("libunibreak", dep.module("libunibreak"));
```

`dep.module("libunibreak")` carries `link_libc`, `src/` on its include path, the
translated headers as `c`, and the compiled library behind all three. That
module name is the SDK's name; the C library's own name is `libunibreak`, and
Zig's `lib` prefixing is why the artifact is named `unibreak` and the emitted
file is `libunibreak.a` — upstream's own file name. The methods, the error
taxonomy and the examples are in [`README.zig.md`](README.zig.md).

### 4b. The raw C route, the artifact, and an installed C consumer

`@import("libunibreak").c` is the translated headers themselves, for a caller
that needs a declaration the facade does not name: `zig/root.zig` re-exports the
translate-c module as `pub const c`, unchanged.
`dep.artifact("unibreak")` is the compiled library for a caller that wants the
archive without the module.

An installed C consumer needs only the headers and the archive:

```sh
cc -std=c99 -I out/include app.c -L out/lib -lunibreak
```

or, from the Nix output, `pkg-config --cflags --libs libunibreak`, which is
generated from upstream's own `libunibreak.pc.in` and asserts
`-L$out/lib -lunibreak`. The installed output also carries `LICENCE`,
`LICENCE-UNICODE.txt`, the per-file audit under `share/licenses/`, and the three
conformance fixtures under `share/libunibreak/`.

### 4c. The runtime-loaded route

With `-Druntime=true` the facade does not link the source library. The
caller loads explicitly and then makes ordinary module calls:

```zig
const libunibreak = @import("libunibreak");
try libunibreak.load(.{ .path = "/usr/lib/libunibreak.so" });   // or .{ .system = "libunibreak.so" }
```

One global table per configured module instance, published atomically; a failed
candidate never publishes; there is no automatic retry and no fallback from an
explicit path to a system name. **The contract:** the loader publishes a
completely resolved and library-validated table, and a call before publication
is an ordinary panic in every optimize mode rather than a null dereference.

**What the ABI actually requires here**, stated rather than assumed:

* `utf8_t`, `utf16_t` and `utf32_t` are upstream's own typedefs for
  `unsigned char`, `unsigned short` and `unsigned int`, behind an
  `UNIBREAK_UTF_TYPES_DEFINED` guard (`src/unibreakbase.h:45-50`). A caller that
  defines its own `utf32_t` before including these headers must make it an
  `unsigned int`-width type: upstream neither redefines nor checks it.
* `utf16_t` is read in the machine's own byte order
  (`src/unibreakdef.c:132`), so the UTF-16 entry points take native-endianness
  code units, not big-endian ones.
* The break buffers are `char`-typed and one byte per code unit, and
  `is_line_breakable` returns `int`. None of that changes with loading, and all
  of it is taken from the installed headers rather than restated here.

### 4d. An exported data symbol and a C99 inline function are two different things

This library exports both shapes, and a symbol table does not distinguish them
for you:

| | `unibreak_version` | `ub_bsearch` |
|---|---|---|
| Declared as | `extern const int` (`src/unibreakbase.h:42-43`), defined at `src/unibreakbase.c:40` | `inline … { … }` with a body (`src/unibreakdef.h:65`), closed by an **external** definition `extern inline …` (`src/unibreakdef.c:175`) |
| What it is in the compiled library | an **exported data symbol**: an address in the image, not a callable entry point | an ordinary **exported function symbol**. C99's `extern inline` is what makes the external definition exist at all; drop it and the symbol disappears, and every translation unit that searches a table fails to link |
| How a loaded image reaches it | **by address**, in the loaded image — never by copying its bytes into the caller's address space | **by calling through the dispatch table** |
| Public route? | yes: it is the one value `libunibreak.version()` returns | no: it is declared only at `src/unibreakdef.h:65`, in a header that is not one of the five installed ones and not part of the public facade. It is nonetheless a real symbol inside the archive |

Two things follow. A loader that treats every resolved name as callable will
"resolve" `unibreak_version` and then call whatever bytes happen to sit there.
And a `ub_bsearch` that is missing from a shared image is not a missing inline:
it is the C99 external definition not having been emitted, which is the same
link-time failure §2 describes, arriving by a different route.

Which symbols a **shared** image exports is a property of the shared build and
has not been observed yet: `PENDING-VERIFICATION` until the driver runs the
shared gate and reads the export list.

---

## 5. Development and packaging

```sh
devenv shell                                  # canonical shell: tools, not the SDK
devenv tasks run sdk:gate                     # every gate in this repository
devenv tasks run sdk:build                    # zig build install, into a prefix outside this tree
devenv tasks run sdk:integrity                # sha256sum -c UPSTREAM.sha256, all 66 records
devenv build outputs.static                   # package the static variant
devenv build outputs.shared                   # package the shared variant
nix build .#static                            # the same derivation, from the flake
nix build .#shared
```

| Route | File | What it is |
|---|---|---|
| Package | [`package.nix`](package.nix) | one standalone source-only derivation; `linkage` picks the variant, default static; the C is compiled by `build.zig`, not by Nix |
| Flake | [`flake.nix`](flake.nix) | pinned nixpkgs; `packages.<system>.static`, `.shared`, and `.default` = static, plus a tools-only dev shell |
| Development shell | [`devenv.nix`](devenv.nix), [`devenv.yaml`](devenv.yaml), [`.envrc`](.envrc) | canonical devenv with lazy `outputs.static` / `outputs.shared`; the SDK is never in the shell's packages |

Every task body names this repository's own directory and changes into it
before it runs anything. That directory comes from `./.` in `devenv.nix` — the
directory of the file that writes it — and not from `$DEVENV_ROOT`, which
`devenv --from path:<this SDK>` points at the *project* directory it creates
beside this tree. devenv runs a task as a generated program that inherits the
caller's working directory, so a body that trusted either one searched for
`build.zig`, `UPSTREAM.sha256` and `consumer/` in a directory that has none of
them; that is what the two canonical entries did on 2026-10-04, and
`FORK-NOTES.md` §34 records it. Every body that invokes `zig build` carries the
three flags this workspace's recipe names — `--cache-dir` for this SDK's own
directory, `-j8`, and `--summary all` — and carries them before `"$@"`, so the
job count, the summary and the cache location are the file's own rather than
the host's core count or a variable a caller has to export. `"$@"` is still
last, so a caller's `--cache-dir`, `-j`, `-Doptimize=`, `--summary all` or step
name of its own still reaches the build runner.

The two bodies that install something — `sdk:build` and the aggregate
`sdk:gate` — pass `--prefix` themselves, because `zig build`'s own default is
`zig-out` beside the build root, which here is this checkout on a volume whose
contents are compared before and after every run. The prefix is
`$LIBUNIBREAK_INSTALL_PREFIX` if the caller exported one, else
`$ZIG_LOCAL_CACHE_DIR/libunibreak-install`, else `$XDG_CACHE_HOME/…`, else
`$TMPDIR/…`; with none of the four set the task names what is missing and exits
non-zero rather than choosing a location of its own. Changing the location
means exporting `LIBUNIBREAK_INSTALL_PREFIX`, not adding a second `--prefix`
to a command line that already carries this file's: every body forwards
`"$@"`, so a caller's flags reach the build runner and a repeated option would
be two answers to one question.

`test`, `smoke`, `upstream-test`, `consumer` and `check` install nothing —
`build.zig` hangs the example's and the exercise's compile steps under the
install step (`b.getInstallStep().dependOn`, one call for each), never the other
way round — so they name no prefix. The consumer is the real one: `zig build
consumer` drives the separate package in `consumer/` as its own `zig build run`,
or as `zig build install` when this host cannot execute the selected target, and
`runConsumer` in `build.zig` forwards the selected target, the selected CPU,
the optimize mode, the linkage, the runtime route and the selected executor
flags to it. It also gives the nested build this workspace's own job count and
summary, both caches, the install prefix when the caller moved it, and the
caller's own arguments:

| What the nested build receives | Where it comes from |
|---|---|
| `-Dtarget=<triple>`, `-Dcpu=<model+features>`, `-Doptimize=<mode>`, `-Dlinkage=<mode>`, `-Druntime=<bool>` | the outer build's own selections, serialized from `target.query` |
| `-fdarling`, `-fqemu`, `-frosetta`, `-fwasmtime`, `-fwine`, `--libc-runtimes <dir>` | the executor the outer build selected, and only when it selected one |
| `--cache-dir <b.cache_root.path>/consumer` | the local cache, with a `/consumer` subdirectory because the local cache holds this graph's manifest directory and is locked for the life of the process holding it |
| `--global-cache-dir <b.graph.global_cache_root.path>` | the global cache, verbatim and with no subdirectory, because it holds content-addressed package directories that are meant to be shared |
| `-j8`, `--summary all` | this workspace's own width and summary, so a passing consumer prints its steps instead of nothing |
| `--prefix <b.install_prefix>` | the outer install prefix, and only when the caller moved it off this build root's default `zig-out`; a relative prefix is made absolute against `b.graph.cache.cwd`, the build runner's working directory, because the nested build's own is `consumer/` |
| `--` then the caller's own arguments | `b.args`, last, so `zig build consumer -- --provider <path>` reaches the program |

The two caches are not interchangeable fields: `cache_root` is on `Build` and
`global_cache_root` is on `Graph`, so `b.global_cache_root` does not exist. The
nested build is always `run` for the selected target, and `consumer/build.zig`
adds `b.args` to the program's own `run_exe`, because a `Step.Run` does not
forward them itself. `CHANGELOG.md` entry 44 and `FORK-NOTES.md` §37 record this
and the reason.

`TMPDIR` and the rest of the scratch environment come from the caller and are
only read; nothing here erases one. `ZIG_LOCAL_CACHE_DIR` and
`ZIG_GLOBAL_CACHE_DIR` are used exactly as the caller exported them, and only a
missing one is filled — from `$XDG_CACHE_HOME`, then `$TMPDIR` — in each body's
own preamble, before the compiler runs. It cannot live in the shell's hook:
`devenv tasks run` materialises a task as a generated program and does not run
`enterShell`. With `ZIG_LOCAL_CACHE_DIR`, `XDG_CACHE_HOME` and `TMPDIR` all
unset the body names what is missing and exits before `zig build` starts, rather
than letting it fall back to `.zig-cache` in this checkout; the global cache
follows the same order and falls back last to the local cache root, which is
known by then. The build cache is `$ZIG_LOCAL_CACHE_DIR/libunibreak-cache`, so
the two installing bodies' prefix always sits beside the cache that run used.
The flake lock and the devenv lock are generated and owned by the driver. Of
the two, `flake.lock` is present in this tree — 593 bytes, written 2026-10-04,
pinning nixpkgs at `c7def046b9a883d46974757852106483d741586f` — and
`devenv.lock` is not. That is
the state of the tree, read out of the files; no derivation has been built and
no shell has been entered by this package's own gates, and no Nix result is
claimed anywhere in it.

All six of those files, the lock included, travel with the Zig package:
`build.zig.zon`'s `.paths` names `package.nix`, `flake.nix`, `flake.lock`,
`devenv.nix`, `devenv.yaml` and `.envrc`, so a dependent who fetches this
package reaches the same routes this section advertises rather than reading
about them. `devenv.lock` is named in no list because it does not exist, and an
empty one would be a file this package does not have.

---

## 6. Provenance, licence and integrity

| File | What it is |
|---|---|
| [`UPSTREAM.md`](UPSTREAM.md) | the pin, the archive receipt, what is compiled and in what order, the include closure, the fixture audit, the two stale upstream documentation claims, and why this library was selected |
| [`UPSTREAM.sha256`](UPSTREAM.sha256) | 66 per-file digests: 59 derived from the pinned commit's blobs on 2026-10-03, plus the seven `tools/` files added 2026-10-04; `sha256sum -c UPSTREAM.sha256`, not re-run since either change |
| [`README.upstream.md`](README.upstream.md) | upstream's README, byte-identical to the pinned blob |
| [`NOTICE.md`](NOTICE.md) | the per-file audit of all 67 upstream blobs: the Zlib grant, the ten Unicode files, `tools/linebreak_test.c`'s separate grant, the five `tools/` programs with no notice, and the inventory of this fork's own files |
| [`FORK-LICENSE.md`](FORK-LICENSE.md) | the grant for the files this fork writes, the authorization behind it, the SPDX identifier (`Zlib`), and the install paths of the licence material |
| [`LICENCE`](LICENCE), [`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) | upstream's grant and the Unicode terms, both carried verbatim and neither restated |
| [`FORK-NOTES.md`](FORK-NOTES.md) | what went wrong while forking this library, and what was decided |
| [`CHANGELOG.md`](CHANGELOG.md) | numbered fork-only divergences; entries 24–28 are this migration and entries 30–33 its correction pass, both dated 2026-10-04 |

This package is local, uncommitted and unpublished. Nothing in it has been
published, and no publication is authorized in this expansion.