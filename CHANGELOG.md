# CHANGELOG — fork-only divergences

Upstream's release history lives in its own repository, in `NEWS` in this
checkout. This file records **only** what this fork changed relative to
libunibreak `8.0` (lightweight tag `libunibreak_8_0`, commit
`28a2756b864c343f438cd22537d49d394d4666a5`), and it is written so a re-sync can
replay it. Numbers are stable identifiers; never renumber them.

Statuses below are the workspace's: **source-confirmed** means the change was
read out of a file and involves no gate; **observed** means the driver ran a
gate here and the receipt is named; **pending** means the change has landed and
no gate has looked at it yet; **not established** means a question that was
asked and is not answered by anything here. The current state of every gate is
the one table in [`README.zig.md`](README.zig.md#verification-status), and is not
repeated here. Gates that have run are named there with their receipts; the
filtered-fetch consumer and the package integrity gate are recorded outside this
package, in `local://foundation-matrix-final-package-proof.json`, and CI has
never run.

This package is local, uncommitted and unpublished: nothing in this file has
been published, and no publication is authorized in this expansion.

## 1. Added the Zig 0.16 package

`build.zig`, `build.zig.zon`, `zig/root.zig`, `zig/translate.h`,
`zig/api_exercise.zig`, `tests.zig`, `smoke.zig`, `consumer/` and
`.github/workflows/verify.yml` are new. New module: `libunibreak`. New artifact:
`unibreak`, which Zig emits as `libunibreak.a` — upstream's own file name —
beside the five installed public headers. The build compiles upstream's own
`src/` from this repository. Nothing is downloaded, no upstream build system
runs, and `build.zig.zon` declares no dependencies. **No upstream source file is
touched.** Package `.libunibreak`, fingerprint `0xb4b2629221124f29`; consumer
`.libunibreak_consumer`, fingerprint `0x1e87b0d3decd683e`.

`dep.module("libunibreak")` is the whole dependency surface. A module-only
consumer needs no `dep.artifact`, because the archive and the translated headers
arrive with the module; `dep.artifact("unibreak")` exists for a C-facing or
otherwise module-less consumer and links `-lunibreak`. This is an ABI identity,
not an alias.

**Source-confirmed.** *(observed: `zig build` installed `lib/libunibreak.a` and
the five public headers, and the module-only consumer package ran, in `Debug`,
`ReleaseSafe`, `ReleaseFast` and `ReleaseSmall` —
`local://foundation-matrix-libunibreak-current-debug.log` and the three optimized
receipts. The filtered fetch is recorded outside this package.)*

## 2. Named the nine translation units explicitly instead of globbing `src/*.c`

`src/Makefile.am:11-20` (`libunibreak_la_SOURCES`) is authoritative and its nine
entries are written out one by one. The list is not a glob because a glob would
let a unit be added to or dropped from the archive without a decision, and this
tree is exactly the kind where that mistake is invisible until a link fails: of
the seven generated data files, **six are `static` and textually `#include`d**
while **`linebreakdata.c` is a real translation unit**, defining non-`static`
`lb_prop_supplementary`, `lb_prop_supplementary_len` and `lb_prop_bmp`, declared
`extern` at `src/linebreakdef.h:233-235`. Compiling one of the other six would
be a duplicate definition; omitting `linebreakdata.c` is an undefined symbol.

`src/Makefile.gcc:108-110` lists the same nine, so neither upstream build file
disagrees with the other. `doc/architecture.md:92-98` does disagree and is left
alone — see entry 8.

**Source-confirmed.**

## 3. Pinned `-std=c99` on every C translation unit

`src/unibreakdef.h` declares `ub_bsearch` as a plain `inline` and
`src/unibreakdef.c` closes with `extern inline … ub_bsearch(…)`. Under C89
inline rules that combination never emits the symbol, and the failure appears at
link time as an undefined reference — which reads like a source list problem
rather than a dialect problem. No `-std` flag appears anywhere in upstream's own
build files; upstream relies on the compiler default and this fork does not.

**Source-confirmed.** *(observed: the archive linked in all four native modes,
in the six-target `check` — `43/43 steps succeeded`,
`local://foundation-matrix-libunibreak-six-baseline.log` — and in all 53
cross-target builds, which is what happens only when `ub_bsearch` is emitted.)*

## 4. Left `UNIBREAK_LAZY_INCB` at upstream's default of 0

`src/graphemebreak.c:57-63` carries the comment explaining the default: since
Unicode 16.0, `InCB=Consonant` is assigned to characters whose `GCB` is `Other`,
so the InCB lookup can no longer be skipped. Setting it to 1 is a documented
upstream escape hatch that would change behaviour, and this fork does not flip
it.

**Source-confirmed.**

## 5. Did not set `NDEBUG` deliberately, and recorded what it would change

Upstream's `src/Makefile.gcc:92` sets `-DNDEBUG` for its release configuration,
and Zig's `ReleaseFast` and `ReleaseSmall` define it for the C they compile,
while `Debug` and `ReleaseSafe` do not. The only `assert`s in the core are
`assert(*ip <= len)` in the three decoders and `assert(0)` at
`src/wordbreak.c:453`'s unreachable default, so what is compiled differs between
the two families of mode. This build does not add `NDEBUG` to either; the
consequence is documented rather than papered over.

**Source-confirmed.** *(all four modes compiled and linked this source; which
macros each mode defines for the C it compiles is a build-file fact, and no run
here compared the two.)*

## 6. Added a typed API that checks before it calls, and refused the opcodes upstream cannot express

`zig/root.zig` publishes three method families over caller-supplied buffers —
allocation-free, no globals, no initialiser — and the whole translated C surface
as `pub const c`. Every promise is checked **before** the native call and before
any output byte is written, so a refusal leaves the caller's buffer holding the
caller's own bytes. `Error` is the complete set and covers only these Zig-side
refusals: `OutputTooSmall`, `InputOutputOverlap`, `MalformedUtf8`,
`MalformedUtf16`, `MalformedUtf32`. Upstream has no error channel at all —
nothing returns `NULL`, sets `errno` or can fail.

The per-code-unit methods scan the input once to reject malformed encoding and
then call native, which scans it again: two passes, and the first is the price
of the promise. The per-code-point methods **count the code points in that same
scan**, check capacity against the count, and only then call native — which is
correctness rather than optimisation, because upstream's
`set_linebreaks_*_per_code_point` returns the number of entries it writes and
never tells the caller what that number should have been. Upstream's own harness
sidesteps the question by over-allocating to the line length.

All five `LINEBREAK_*` values are kept, including `INDETERMINATE`, which is a
real fifth opcode with no counterpart in the Unicode test files. Upstream's
harness folds `ALLOWBREAK` and `INDETERMINATE` both into `MUSTBREAK` before
comparing against the oracle; that fold happens here **only** at that comparison,
and the distinction is asserted directly elsewhere.

The per-code-unit methods keep upstream's indexing exactly, and it is worth
writing down because the opposite is easy to guess: a code point's break opcode
is written at that code point's **final** code unit, and every code unit before
it — the lead byte and its continuation bytes — is `inside_char`, the canonical
spelling of upstream's three `*_INSIDEACHAR` macros. No opcode belongs to a
code point's leading unit. In UTF-32 one unit is one code point, so the marker
never appears there.

**Source-confirmed.** *(observed: these tests ran and passed in `Debug` —
`23/23 steps succeeded; 15/15 tests passed` — and in `ReleaseSafe`,
`ReleaseSmall` and `ReleaseFast`, `15/15 tests passed` in each, with the residue
assertions and the whole-fixture replays among them;
`local://foundation-matrix-libunibreak-current-debug.log` and the three optimized
receipts)*

## 7. Omitted `lang` from the typed word and grapheme methods

Upstream takes a `lang` argument on every entry point and ignores it for two of
the three algorithms: `src/wordbreak.c:169-170` is literally a
`/* TODO: Language-specific specialization. */ (void)lang;` and all three
grapheme entry points do `(void)lang`. The typed API therefore has no `lang`
parameter on `Word` or `Grapheme` — a typed option that does nothing is worse
than no option. The raw route still exposes it, because removing it there would
change upstream's signature.

For line breaking the parameter is real, and three of its properties are passed
through rather than tidied up: matching is **by prefix, not equality** (`zh-CN`
matches `zh`, and so would `zhx`), `null` and `""` both mean no tailoring, and
`"-strict"` is the UAX #14 Conditional Japanese Starter tailoring and the one
place the option changes an answer.

`init_linebreak`, `init_wordbreak` and `init_graphemebreak` are upstream API and
are on the raw route. They are empty bodies kept for binary compatibility, so
the typed API omits them rather than presenting required initialisation that does
nothing.

**Source-confirmed.**

## 8. Recorded two stale claims in `doc/architecture.md` instead of fixing them

`doc/architecture.md` ships unmodified and two of its statements are contradicted
by the 8.0 source: the MSVC `bool` fallback at `:88`, which has no counterpart in
the tree (`src/unibreakdef.h:38` includes `<stdbool.h>` unconditionally), and the
`linebreakdata.c` inclusion row at `:92-98`, which claims every generated data
file is `static` and included. Upstream documentation is not this fork's to
edit, and a correct local edit would be a second, silent divergence. Both are
recorded in [`UPSTREAM.md`](UPSTREAM.md#two-stale-claims-in-upstreams-own-documentation).

**Source-confirmed.**

## 9. Used the three conformance fixtures in place, with no `testdata/`

`tests.zig` replays **every** data row of `src/LineBreakTest.txt` (19 338),
`src/WordBreakTest.txt` (1 944) and `src/GraphemeBreakTest.txt` (766) — no
sampling and no skips — asserting those counts against the counts each file
states in its own footer. The expected answers are Unicode's own, printed beside
each row in the fixture, so the oracle is independent of this library's code; and
nothing is fetched to run them, because the fixtures are `@embedFile`d from
`src/` at build time.

`zig build upstream-test` compiles upstream's own `src/tests.c` **unmodified**
and runs it with `src/` as its working directory, because the harness opens the
three files by bare name. Upstream's own build satisfies that with symlinks into
a build directory; running the program where the files already are needs no copy,
no symlink and no fixture rewriting.

**Source-confirmed.** *(observed: upstream's unmodified `src/tests.c` ran three
times and printed `Passed 19338 out of 19338 (100%)`, `Passed 1944 out of 1944
(100%)` and `Passed 766 out of 766 (100%)`; the Zig replay of the same three
whole files is three of fifteen facade tests that passed in all four optimize
modes — `local://foundation-matrix-libunibreak-current-debug.log`, exit 0, and
the three optimized receipts; the same three figures were printed earlier by
`local://foundation-matrix-libunibreak-unicode-r5.log`)*

## 10. Fetched the Unicode terms text verbatim instead of writing licence prose

`LICENCE-UNICODE.txt` is the byte stream of
`https://www.unicode.org/license.txt` — 1 995 bytes, SHA-256
`e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96`, fetched
2026-10-03 — and it is installed beside the archive, because the seven generated
tables it governs are inside the archive. The URL the fixtures name,
`terms_of_use.html`, redirects to `copyright.html`, whose §2(c) assigns all
Unicode Data Files to the Unicode License v3.

Nothing of it is authored here, nothing is paraphrased, and the Zlib text in
`LICENCE` is not claimed to reach it. See entry 11.

**Source-confirmed.**

## 11. Audited every one of the pin's 67 blobs for a notice

[`NOTICE.md`](NOTICE.md) is a file-by-file audit, not a summary. It records the
three terms this tree contains — the Zlib grant in `LICENCE`, the Unicode terms
over the seven generated tables and three fixtures, and a separate broader grant
inside `tools/linebreak_test.c:9-13` — and it names the eight files that carry no
notice of any kind, five of them `tools/` programs. The seven generated tables
are the load-bearing case: they carry only a generation banner, so they are
Unicode-derived by provenance and not by an in-file grant, and seven of the nine
compiled units or their includes consist substantially of them.

Upstream's `WordBreakTest.txt` notice, an open item in the selection screen, is
now closed: all 30 comment lines of all three fixtures were read, the notice is
the same three lines in the same place, and nothing follows it but the legend
and the footer.

**Source-confirmed.**

## 12. Derived every integrity digest from the pinned blobs, not from the working tree

`UPSTREAM.sha256` holds **59** per-file digests over the upstream-owned entries
of `build.zig.zon` `.paths`. Each was computed by reading the blob out of the
pinned commit's object store, not by hashing a file on disk: 59 compared against
the record, **0 disagreements**. An earlier draft quoted a working-tree digest for
`.gitignore` while describing it as upstream's; the build role caught it, and the
whole record was then re-derived from the pinned blobs so that no record in this
package can be polluted by a file the fork edits. Upstream's `.gitignore` blob
is `bbad54185e3da91dacb7854b544440426c2ff2cf71062995cdcdfd5ea56fae07` (549
bytes, 43 lines).

**Source-confirmed.** *(observed: `sha256sum -c UPSTREAM.sha256` ran here at exit
0 with 59 `OK` lines —
`local://foundation-matrix-libunibreak-provenance-checksums.log`; comparing all
67 pinned blobs against this working tree found one difference, `.gitignore`,
the file this fork appends to and this record deliberately omits —
`local://foundation-matrix-source-integrity.json`)*

**Corrected 2026-10-04, by entry 34.** The record holds **66** records now, not
59: the seven `tools/` files joined it when entry 31 put that directory in
`.paths`. The claim above is kept as it was written — 59 digests, each read out
of the pinned commit's object store, compared on 2026-10-03 with 0 disagreements
— and the 2026-10-03 observation is not restated as a 66-record one.

## 13. Appended a Zig ignore block to `.gitignore`, and kept the file out of the record

Upstream's 43 lines are kept verbatim and in place, and this fork appends a
26-line block for `.zig-cache/`, `zig-out/`, `zig-pkg/` and their `consumer/`
equivalents. No upstream ignore rule is removed and no upstream pattern swallows
a fork path. Because the working-tree file is then not byte-identical to
upstream's, it is deliberately absent from `UPSTREAM.sha256`, with that reason
stated in the record's header.

**Source-confirmed.**

## 14. Kept `tools/` in the checkout and out of the published package

`tools/` is **absent from `.paths`**: this package neither compiles those six
example programs nor needs them, and `tools/linebreak_test.c` reaches outside
the standard headers for `<iconv.h>`. They remain in the checkout, byte-identical
and undeleted, with their digests recorded in `NOTICE.md` so a re-sync can
compare them; and their exclusion from `UPSTREAM.sha256` is stated rather than
silent, because a record naming files a fetched package does not carry would fail
in exactly the place it is meant to be useful.

**Superseded 2026-10-04, by entry 31.** The delivery half of this entry no
longer holds: `build.zig`'s install step reads `tools/test.txt`, so `.paths`
carries the directory and a fetched package receives the bytes. The reasoning
about the six example programs is unchanged — still compiled by nothing here,
still byte-identical, still undeleted, still audited file by file in
`NOTICE.md` — and so is the reason they are not built:
`tools/linebreak_test.c:20` reaches outside the standard headers for
`<iconv.h>`. Carrying a file is not a claim that it builds.

**Source-confirmed.**

## 15. Recorded no system-library mode as NOT APPLICABLE

This wave's contract keeps the source pin and the bounded contracts identical in
every mode, so there is no `-Dfsys=` option and no
`b.systemIntegrationOption`. A distribution's libunibreak is not this manifest's
pinned 8.0 with this manifest's headers, and translating these headers against it
is exactly the header/ABI mismatch the rule forbids. The rule is recorded as NOT
APPLICABLE rather than claimed as satisfied.

**Source-confirmed / constraint.**

## 16. Recorded the dependency-breadth question as NOT ESTABLISHED

The selection screen established packaging breadth — Debian in every suite since
bullseye, Gentoo, Fedora rawhide on 8.0, release download counts — and did **not**
establish a large-fraction dependency count or a named dependent.
**Packaging breadth is not proof of dependency breadth.** Global R2 is recorded
as NOT ESTABLISHED, and the disposition rests on the ledger's
missing-capability and source-build rule instead. The maintenance cost is stated
rather than minimised: one current core maintainer and a personal GitHub
account, with an open merge path.

**Not established, and recorded as such.**

## 17. Added a verification workflow that publishes nothing

`.github/workflows/verify.yml` is new and entirely fork-authored — upstream ships
no CI at this pin, so there is no `.github/` directory in the tree and no
upstream workflow to retarget or exclude. It runs the integrity check, the native
build, the installed C surface, the tests and the example, the six-target
compile-only check, and the consumer package. It uploads no artifact, publishes
no release, and grants `contents: read`. It has **never been executed**: CI has
not run and this repository is local and unpublished.

**Source-confirmed.** *(not run: no CI execution exists)*

## 18. Guarded the typed grapheme methods against upstream's empty-length write

`set_graphemebreaks` has no empty-length guard: with `len == 0` it computes
`size_t brksPos = posNext - 1` (`src/graphemebreak.c:212`) with `posNext` still
`0`, so the value wraps, and the GB1 case at `:221` writes one byte **before** the
caller's buffer. `Grapheme.perCodeUnit`, `perCodeUnit16` and `perCodeUnit32` now
return immediately after validation when the input is empty and never make the
native call. `Line` and `Word` need no such guard: `set_linebreaks`
(`src/linebreak.c:1450-1453`) and `set_wordbreaks`
(`src/wordbreak.c:173,177,463`) already return without writing.

**No upstream byte was changed.** `src/graphemebreak.c` still carries no guard at
this pin and `UPSTREAM.sha256` still pins its digest; the defect is documented on
the raw route, where a C caller inherits it, rather than patched into upstream's
file.

**Observed.** Before the guard, `Grapheme.perCodeUnit("", guarded[1..2])` aborted
with `thread 41214 panic: addition of unsigned offset to 0x7ffc681153e5 overflowed
to 0x7ffc681153e4` at `src/graphemebreak.c:221` and exited on signal 6
(`local://foundation-matrix-empty-grapheme-before.log`). After it, the same probe
printed `empty grapheme guard: before=inside_char output=no_break
after=inside_char` and exited 0
(`local://foundation-matrix-empty-grapheme-after.log`).

## 19. Compiled the example and the exercise without installing either, and kept the consumer a real run

`zig build` puts the example's and the API exercise's `Compile.step` under the
default install step's graph, which **compiles** them and installs neither: there
is no `installArtifact` and no `install exe` step for either program, and nothing
appears under `zig-out/bin/`. `README.zig.md` says exactly that, so the word
"installs" is never used of a program this build does not install.

`zig build consumer` remains a nested `zig build run -Dtarget=<triple>
-Doptimize=<mode>` inside `consumer/` with the harness's executor flags
forwarded. It is never replaced by a host-native build, an installed prefix or an
install step, because a substituted build would prove something other than what
the gate claims.

**Observed** for the native target in all four optimize modes: `consumer package
success` (`local://foundation-matrix-libunibreak-current-debug.log` for the
current source, the three optimized receipts, and earlier
`local://foundation-matrix-libunibreak-unicode-r7.log`). The install step of the
current Debug run, and the earlier
`local://foundation-project-matrix-libunibreak-r1-native-install.log`, both list
`install unibreak`, three `install <file>` steps and one `compile exe
libunibreak-smoke`, and no `install exe`.

## 20. Corrected the installed-C surface program's oracles

The C program in `.github/workflows/verify.yml` that compiles against the
installed prefix shipped with two oracles that were wrong about UAX #14, and with
two assertions that proved nothing. All four are corrected:

* **After a space, the answer is `LINEBREAK_ALLOWBREAK`, not `MUSTBREAK`.** That
  position is rule LB18. The program asserted `MUSTBREAK` and printed
  `FAIL  [1] LB7 requires a break after the space`.
* **Before a newline, the answer is `LINEBREAK_NOBREAK`, not `MUSTBREAK`.** That
  is rule LB6, which prohibits a break before LF; the position *after* the
  newline is the mandatory one, by LB5. The program asserted `MUSTBREAK` before
  the newline and printed `FAIL  [0] LB5 requires a break before the newline`.
* A `expect(1)` that compared a value with itself was removed. It could not fail
  and so tested nothing.
* The assertion that pinned `unibreak_version` to a constant was removed; the
  program now prints the version. Version pinning is the provenance gate's job,
  not a C smoke program's.
* The empty-input check is scoped to the **line** function, which is the native
  function that genuinely returns without writing. The grapheme function is not
  called with `len == 0`, because it does not — see entry 18.

**Observed.** Before: `2 check(s) failed`, exit 1
(`local://foundation-matrix-libunibreak-installed-c-run-r0.log`). After: all
checks `ok` and `the installed C surface compiled, linked and ran`, exit 0
(`local://foundation-matrix-libunibreak-installed-c-run-r1.log`, with
`…-installed-c-compile-r1.log` empty at exit 0). All five installed headers were
compiled, and the program asserts real values for line positions 8, 16 and 32,
the per-code-point count, the pair query, and word and grapheme breaking. Run
again against the prefix the current Debug run installed
(`…/libunibreak/install-current`): compile exit 0 with empty output, run exit 0
with every check `ok`
(`local://foundation-matrix-libunibreak-installed-c-current-compile.log` and
`…-installed-c-current-run.log`, 2026-10-03).

## 21. Corrected the documented output placement and rewrote the status from receipts

The per-code-unit output places a code point's break opcode at that code point's
**final** code unit, and marks every earlier code unit of a multi-unit code point
`inside_char` — the canonical spelling of this package's three enums, and the
Zig name for upstream's `LINEBREAK_INSIDEACHAR`, `WORDBREAK_INSIDEACHAR` and
`GRAPHEMEBREAK_INSIDEACHAR`. `README.zig.md` and the `zig/root.zig` doc comments
now say that in those terms, cite the three implementations that establish it,
and explicitly deny the two wrong readings: no opcode belongs to a code point's
leading unit, and none is written at the unit after it.

The four documents no longer carry a blanket "nothing has been built, every gate
is NOT RUN". Each gate that ran is named with its receipt, mode and exit code;
each gate this package makes no claim about is still named, individually; and the
53-platform `cross-test` row records exactly what the harness recorded —
`status: partial`, 53 of 53 built, 20 ran, 33 `build_only`, 0 failed — with no
claim that the library runs everywhere it compiles. At the time of this entry the
four mode receipts predated the current `zig/root.zig`, `zig/api_exercise.zig`,
`consumer/src/main.zig` and `build.zig.zon`, so those rows named the tree they
were taken against and marked the current source `PENDING-VERIFICATION`; entry
22 records the state after the current run.

The typed-API example in `README.zig.md` was also wrong in a way that mattered:
it sized its output buffer at ten entries for a thirteen-byte string and would
have been refused as `OutputTooSmall`. It is now thirteen, states the published
answer, and checks it.

## 22. Replaced every stale gate claim with the receipt that now exists

Entry 21 stopped the documents claiming a blanket `NOT RUN`; this entry records
the gates that have since been observed on this host, and the one that is
deliberately not claimed here. Nothing here is a source change: no upstream byte
moved and no build file, facade, test, workflow or licence file was touched.

**Observed on 2026-10-03, all at exit 0:**

* `zig build install test smoke consumer upstream-test` in `Debug` against the
  current source — `Build Summary: 23/23 steps succeeded; 15/15 tests passed` —
  which installs `lib/libunibreak.a`, the five public headers, `LICENCE`,
  `LICENCE-UNICODE.txt` and `README.md`, runs the exercise, the example and the
  consumer package, and runs upstream's unmodified `src/tests.c` three times at
  100 % on all three fixtures
  (`local://foundation-matrix-libunibreak-current-debug.log`).
* `zig build test smoke consumer` in `ReleaseSafe`, `ReleaseFast` and
  `ReleaseSmall` — `13/13 steps succeeded; 15/15 tests passed` in each.
* `zig build check` — the six-target compile-only matrix,
  `Build Summary: 43/43 steps succeeded`, running nothing
  (`local://foundation-matrix-libunibreak-six-baseline.log`).
* `zig cc` against the installed prefix and headers, then running the program:
  compile exit 0 with empty output, run exit 0 with every check `ok`
  (`…-libunibreak-installed-c-current-compile.log`,
  `…-libunibreak-installed-c-current-run.log`).
* `sha256sum -c UPSTREAM.sha256` — 59 `OK` lines, no failure
  (`…-libunibreak-provenance-checksums.log`); and all 67 pinned blobs compared
  against this working tree, one difference, `.gitignore`
  (`local://foundation-matrix-source-integrity.json`).
* The 53-platform `cross-test` matrix: `status: partial`, 53 of 53 built, 20 ran
  the `test` step with 15 tests each, 33 `build_only` for want of a runtime, 0
  failed (`local://foundation-matrix-libunibreak-cross-full-summary.json`).
* This README's own typed-API example, extracted and run: `6/6 steps succeeded`,
  exit 0 (`…-libunibreak-all-readme-examples-r1.log`).
* `zig fmt` over the nine fork-authored Zig/ZON files, exit 0; the receipt names
  all nine files it wrote (`…-libunibreak-fork-zig-format.log`). A formatter exit
  code is not a green gate and is not recorded as one.

**Not claimed here.** The filtered-fetch consumer and the package integrity gate
are recorded by the driver outside this package, in
`local://foundation-matrix-final-package-proof.json`; only an observed receipt
there establishes a pass, and none had been produced when these documents were
written. CI has still never executed: this package is local and unpublished.

**Every receipt above is reported against the tree it was taken against.** What
the `cross-test` row does not say is the other half of the boundary: 33 of the 53
platforms have no runner on this host, so they are `build_only`, never executed
and never counted as passes.

## 23. Documented the UTF typedef bridge, and both of its edges

`src/unibreakbase.h:45-50` defines `utf8_t`, `utf16_t` and `utf32_t` as
`unsigned char`, `unsigned short` and `unsigned int`, behind an
`UNIBREAK_UTF_TYPES_DEFINED` guard. The typed surface takes `[]const u8`,
`[]const u16` and `[]const u32`, which are those widths exactly, so the typed
methods pass straight through to `set_linebreaks_utf8/16/32` and friends with no
cast and no reinterpretation, and the raw route publishes the same three
typedefs under upstream's own names. Two edges were undocumented and are now
stated in `README.zig.md`: a C caller that defines its own `utf32_t` before
including these headers must make it an `unsigned int`-width type, because
upstream neither redefines nor checks it; and `utf16_t` is read in the machine's
own byte order (`ch = s[(*ip)++]` at `src/unibreakdef.c:132`), so the UTF-16
methods take native-endianness code units and not big-endian ones.

**Source-confirmed.** Both edges are read out of the pinned headers and the
pinned decoder; the behaviour each states is exercised by the UTF-16 conformance
replays, which pass in all four native modes.

---

## 24. Moved upstream's README aside and wrote this fork's own

`README.upstream.md` is upstream's README, byte-identical to the pinned commit's
blob: 2 996 bytes, SHA-256 `cc38c7b8…`, verified against
`local://foundation-contract-upstream-readme-proof.json`. It was extracted before
this entry and is not edited here.

`README.md` is now **this fork's**, in the order this workspace's contract fixes:
current native-source deviations, current native-build deviations with a dated
history link, the current build/run/test matrix, and consumption, with the Zig
interface left in `README.zig.md`. It does not claim to be upstream's document
and does not restate upstream's. Three consequences outside this entry: the
record in [`UPSTREAM.sha256`](UPSTREAM.sha256) now names `README.upstream.md`;
every citation of `README.md:25-26` or `README.md:28-29` in `NOTICE.md` and
`UPSTREAM.md` became a citation of `README.upstream.md`, because those lines are
upstream's prose about its own licence and its own Unicode terms; and
`build.zig.zon`'s `.paths` needs the same entry — a build-graph change, recorded
in [`README.md`](README.md) §2 as pending.

**Source-confirmed** for the bytes and the citations. The README's own claims are
`SOURCE-CONFIRMED` or `PENDING-VERIFICATION`, row by row, and it names no gate
result that was not already in [`README.zig.md`](README.zig.md#verification-status).

## 25. Granted a licence for the files this fork writes

[`FORK-LICENSE.md`](FORK-LICENSE.md) is new, and it records one grant over every
file this fork authors: **Zlib**, SPDX `Zlib`, chosen under the owner's
authorization for a per-project licence matching upstream's primary term. Nothing
upstream wrote is relicensed, no copyright holder is invented, and no fork
addition is attributed to upstream's authors.

`NOTICE.md` §"This fork's own files carry no licence" is replaced by §"This fork's
own files, and the one grant over them", which keeps the full inventory, adds the
new packaging files, and records where the licence material is installed. The
earlier *unassigned* status is described there as what it was: the state before
the authorization, not a grant.

Unchanged and byte-for-byte: `LICENCE` (upstream's Zlib text),
`LICENCE-UNICODE.txt` (the Unicode terms, fetched from `unicode.org`), the ten
Unicode files, `tools/linebreak_test.c`'s separate broader grant, and the five
`tools/` programs that carry no notice at all. The seven generated tables still
carry no in-file grant — six of them are textually included by a compiled
translation unit and the seventh is compiled on its own — so a Zlib label on the
archive would describe the code and misdescribe the data.

**Source-confirmed.** The authorization is a user instruction recorded in
`AGENTS.md` §8 and the wave contract; the file lists are read out of this tree.

## 26. Repointed the integrity record, without moving a byte of upstream

`UPSTREAM.sha256` still holds **59** records and every digest is unchanged. One
path changed: `README.md` became `README.upstream.md`, with the identical digest
`cc38c7b8…`. The record's header now also lists this fork's own files by their
real names, including the packaging added in entry 27, and states that the grant
over them is recorded in `FORK-LICENSE.md` rather than inherited from upstream.

**Pending.** `sha256sum -c UPSTREAM.sha256` has not been re-run since the
re-pointing; the observed 59 `OK` lines in
`local://foundation-matrix-libunibreak-provenance-checksums.log` are from
2026-10-03 and describe the previous path.

## 27. Added standalone Nix packaging and a canonical devenv shell

Five files are new: `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml` and
`.envrc`. `package.nix` is one uncurried function with injected `lib`, `stdenv`
and `zig`, an optional `linkage` argument defaulting to **static** — this SDK's
existing policy — and one derivation out. It compiles nothing itself:
`zig build install --prefix "$out" -j… -Dcpu=baseline -Doptimize=… -Dlinkage=…` is
the whole build, so the C flags, the nine translation units, the five installed
headers and the link metadata stay in `build.zig` where they belong. Both Zig
caches are exported under the sandbox `TMPDIR`, outside the source tree. There is
no fetch, no sibling path, no host account or store path, and no claim that
anything linked against the static archive is wholly static.

The variants live in the entry points: `flake.nix` exposes
`packages.<system>.static`, `.shared` and a `.default` that preserves the static
policy, against a pinned nixpkgs; `devenv.nix` exposes the same derivation as lazy
`outputs.static` and `outputs.shared`.

The derivation installs nothing of its own: `build.zig` installs the library, the
headers, the link metadata, both licence texts, `README.upstream.md`, the licence
records under `share/licenses/libunibreak/` and the conformance data under
`share/libunibreak/`, so no path has two writers. The derivation's install check
asserts that a `libunibreak.pc` exists under `$out`, that the five headers and the
library the variant produced are there, and that the licence texts travel. The
build graph chooses where the `.pc` lands; the check finds it rather than assuming
a directory.

`devenv shell` holds **tools only** — the SDK is never in its `packages`, and
`devenv build outputs.static` is the packaging route. Gates are namespaced
tasks, `devenv tasks run sdk:gate`, that run the commands themselves.

**Not verified.** No derivation has been built, no shell has been entered, and no
lock file has been written: `flake.lock` and `devenv.lock` are the driver's.

**Corrected 2026-10-04, by entry 32.** The last clause described this tree
before the driver wrote the lock: `flake.lock` is present now — 593 bytes,
written 2026-10-04, pinning nixpkgs at
`c7def046b9a883d46974757852106483d741586f` — and `devenv.lock` is still absent.
The first two clauses are unchanged and remain claims this package makes about
itself: nothing here has built a derivation or entered a shell. Reading a lock
file is not running Nix.

## 28. Recorded the delivery contract this wave requires of the build graph

Nothing in this entry changes `build.zig`; it records what that file and the API
role owe, so the requirements are in one place and each carries a pending row in
[`README.md`](README.md) §3:

* `-Dlinkage=static|dynamic`, **default static** — a real shared build with PIC,
  an export surface and a closing dependency closure, not a renamed archive;
* pkg-config metadata generated from upstream's own `libunibreak.pc.in` and
  installed at `lib/pkgconfig/libunibreak.pc`, which is what `package.nix`'s
  install check looks for;
* `-Druntime=true`, under which the facade does not link the source
  library while the native artifact is still built and installed;
* one process-lifetime table per configured module, explicit `.path` or
  `.system`, no fallback, failed candidates never published, explicit retry, and
  an ordinary pre-publication panic in every optimize mode.

The exported symbols are two different kinds of thing and the documentation now
says which is which: `unibreak_version` is `extern const int` — **data**, reached
by address in a loaded image and never called — and `ub_bsearch` is a C99
`inline` definition closed by an `extern inline` external definition at
`src/unibreakdef.c:175`, which is what makes it a real function symbol at all
and what would be missing, as a link error, if that line were dropped.

**Pending.** `build.zig` hard-codes `.linkage = .static` at the time of this
entry, there is no `runtime/` directory, and no gate has observed any of it.

**Corrected 2026-10-04, by entry 32.** Two of those three statements described
the tree at the moment this entry was written and the source no longer supports
them. `build.zig:1115-1126` reads `-Dlinkage` and defaults it to `static`
rather than hard-coding it, and `runtime/` is six files in the tree, imported by
`build.zig:277` and named by `.paths` — the route this entry records is shipped,
not planned. The third clause is the one that has not changed, and it is the
one that matters: no gate has observed any of it.

**Dated.** Entries 24–28 and 30–39 are 2026-10-04; entries 1–23 predate this
migration.

## 29. Corrected the two-code-point UTF-32 exercise

The typed and raw UTF-32 exercises used a two-code-point input but expected EOS
after the first point. Both now check U+0301 and index 2 before EOS. The Unicode
fixture tests keep their independent published expectations; duplicate raw-versus-
typed comparisons were removed.

Observed: `zig build smoke test -j2` passes the exercise and smoke; 17 tests pass
and 2 are skipped. Receipt:
`local://foundation-resumed-libunibreak-two-codepoint-decoding.json`.

## 30. Spelled the delivery option the way the build script declares it

The dispatch option is `runtime`, not `runtime-loading`. `build.zig`'s one
`b.option` call for it declares the name `runtime` (`build.zig:1145-1155`), and
that is also the name `build.zig:1083` forwards into the separate `consumer/`
package. Six documented commands carried the other spelling, so each named an
option no build script declares instead of the mode it meant:
[`README.md`](README.md) §2's option table, §3's pending gate row and §4c;
[`README.zig.md`](README.zig.md)'s option table, the delivery-mode paragraph
below it, and the pending gate row; and the bullet in entry 28 above. All six
are now `-Druntime`.

The sentences that call the delivery *the runtime-loading route* —
[`FORK-NOTES.md`](FORK-NOTES.md) §17 and the pending section of
[`README.zig.md`](README.zig.md) — describe the feature rather than name a flag
and are left as they are. A reader who copies a command needs the flag spelled
the way the build script spells it; a reader who reads a sentence needs the
sentence.

**Source-confirmed** against `build.zig`. Nothing was executed: the defect is in
the spelling, and the corrected commands are the pending rows that no gate has
run. The reasoning, and why the prose was left alone, is
[`FORK-NOTES.md`](FORK-NOTES.md) §28.

## 31. Carried the two files the install step reads

`build.zig.zon`'s `.paths` named neither `FORK-LICENSE.md` nor anything under
`tools/`, and `build.zig`'s install step reads both:
`b.installFile("FORK-LICENSE.md", "share/licenses/libunibreak/FORK-LICENSE.md")`
at `build.zig:1200`, and
`b.installFile("tools/test.txt", "share/libunibreak/test.txt")` at
`build.zig:1205`. In this working tree both files are present, so `zig build
install` succeeds here and the defect is invisible. In a package materialised
from `.paths` — a fetched copy, which is how the filtered-package gate obtains
this package — neither file is in the copy, and the install step fails naming a
file the source tree has always had. That is why this manifest's rule is
completeness rather than convenience: an entry has to be there because something
reads it.

`FORK-LICENSE.md` joins the fork's own records. `tools` joins as one directory
rather than as the single file the install reads: `test.txt` is the sample input
for the six programs beside it, upstream's `Makefile.am:12` distributes the
directory as a unit, and picking one file out of it would be the second, quieter
claim about what this package is that the `src` entry refuses to make. Nothing
compiles any of them, so no build step changes: `core_sources` still names nine
translation units, and `tools/linebreak_test.c:20`'s reach for `<iconv.h>` is
still why it is not one of them. Carrying the bytes is not a claim that they
build.

Two records outside this entry's scope were behind the source and have since
been repointed by their owner, with this entry as the reason:
`UPSTREAM.sha256` named `tools/ (7 files)` as deliberately absent and now
records all seven, with its header stating that they travel because the install
step reads `tools/test.txt` (entry 34), and `NOTICE.md:221-224` said the same in
prose and now says `tools/` travels. The third was not a record file at all:
`build.zig:402-408` said nothing here builds "or installs" the directory and that
it stays "out of the filtered package closure", and both clauses are now
corrected in place (entry 36).

**Source-confirmed.** No build, fetch, `zig build install`, provenance or Nix
command was run for this entry: the defect and the fix are read out of
`build.zig`, `package.nix`'s install check and the manifest. The gate that would
observe it is the driver's filtered-package gate,
`local://foundation-matrix-final-package-proof.json`, and it is still
`PENDING-VERIFICATION`. The general form of this defect — an allowlist and a
build graph that reads files, with nothing making them agree — is
[`FORK-NOTES.md`](FORK-NOTES.md) §27.

## 32. Corrected two dated status sentences the current source no longer supports

Neither original sentence is deleted. Each said something true about the tree on
the day it was written, and each is corrected here against the tree as it is.

* Entry 27's "**Not verified.** No derivation has been built, no shell has been
  entered, and no lock file has been written: `flake.lock` and `devenv.lock` are
  the driver's." — `flake.lock` is present now: 593 bytes, written 2026-10-04,
  pinning nixpkgs at `c7def046b9a883d46974757852106483d741586f`.
  `devenv.lock` is still absent. The first two clauses are untouched and remain
  claims this package makes about itself; nothing here has built a derivation or
  entered a shell, and no receipt for one is claimed.
* Entry 28's "**Pending.** `build.zig` hard-codes `.linkage = .static` at the
  time of this entry, there is no `runtime/` directory, and no gate has observed
  any of it." — `build.zig:1115-1126` reads `-Dlinkage` and defaults it to
  `static`, and `runtime/` is six files in the tree, imported by `build.zig:277`
  and named by `build.zig.zon`'s `.paths`. The third clause is unchanged, and it
  is the one that governs every row: no gate has observed any of it.

**Source-confirmed** for both, read out of `build.zig`, `build.zig.zon` and the
two lock files in this tree. No Nix evaluation, shell, build or gate was run and
no receipt is claimed for one. The reasoning is
[`FORK-NOTES.md`](FORK-NOTES.md) §29.

## 33. Carried the Nix and devenv entry points the README advertises

Entry 27 added `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml` and
`.envrc` beside the build, and §5 of [`README.md`](README.md) tells a reader to
run `devenv shell`, `devenv tasks run sdk:gate`, `devenv build outputs.static`
and `nix build .#static` from this tree. `.paths` named none of them, so the
advertised routes existed only in a checkout and not in the package: a
dependent who fetched this package could read about `nix build` and could not
run it. The five entry points are now named in `.paths`, together with
`flake.lock`, which the driver wrote on 2026-10-04 and which is the reproducible
half of the flake — a flake without its lock pins nothing.

`devenv.lock` is named in no list, because it does not exist in this tree. An
empty file standing in for it would be a file this package does not have, and a
`.paths` entry that is not there fails the fetch that reads it.

This is not in tension with `package.nix`'s own source filter. A Nix derivation
filters the sources it hands to the build and may exclude lock files from them
after the flake frontend has resolved the locked inputs; that is a statement
about the sandbox's source set, and `.paths` is a statement about what this
package publishes. Neither is a defect in the other, and the file that owns each
one keeps its own.

**Source-confirmed**: the five entry points and `flake.lock` are all present in
this tree, `devenv.lock` is absent, and no build, fetch, evaluation or gate was
run for this entry. The Nix and devenv rows in §5 and in
[`README.zig.md`](README.zig.md)'s package table were corrected to match, and the
reasoning is [`FORK-NOTES.md`](FORK-NOTES.md) §30.

## 34. Recorded the seven `tools/` files in the integrity record

`.paths` began carrying `tools/` whole in entry 31, and `UPSTREAM.sha256` now
holds **66** records: the 59 of entry 12 plus `tools/graphemebreak_bench.c`,
`tools/graphemebreak_test.c`, `tools/linebreak_bench.c`,
`tools/linebreak_test.c`, `tools/test.txt`, `tools/wordbreak_bench.c` and
`tools/wordbreak_test.c`. The header's set statement was repointed with it —
"the upstream-owned entries of `.paths`" is now true at 66 — and its
"deliberately absent" entry for `tools/` is gone, because a record that omitted
files the package ships would fail in the one place it exists to be used.

Provenance is stated rather than inflated, and the difference matters. The first
59 were each read out of the pinned commit's object store and compared against
the record on 2026-10-03: 59 compared, 0 disagreements. The seven were read from
the working-tree files on 2026-10-04 and all seven agree with `NOTICE.md`'s
table; **no new pinned-object comparison was run for them**, and the header says
so rather than implying a 66-record extraction that has not happened.

**Source-confirmed.** The seven digest lines were read out of the record and
checked against `sha256sum tools/*`: seven compared, 0 disagreements. No build,
fetch, provenance gate or Nix command was run for this entry, and
`sha256sum -c UPSTREAM.sha256` over the 66-record file is still
**PENDING-VERIFICATION** — the 59 `OK` lines in the receipts are an observation
about the earlier record.

## 35. Qualified the example's determinism claim to the lines it covers

[`README.zig.md`](README.zig.md) said "Nothing in it depends on timing, on a
locale or on an environment variable", without saying which lines that covered.
`smoke.zig:32-34` carried the same sentence — "Nothing here depends on timing, on
a locale or on an environment variable" — and nine lines below it the same file
documents that `resolveProvider` reads `LIBUNIBREAK_TEST_PROVIDER` and fails a
run told neither, so one file held both halves of a contradiction.

The README now names the two lines that are not configuration-independent: the
version line, which under `-Druntime=true` prints whatever the provider named by
`--provider` or `LIBUNIBREAK_TEST_PROVIDER` reported, and the route line, which
names the configuration. In a linked build both are fixed and nothing is read
from the environment, so the claim holds there in full. Everything after those
two lines is this package's own assertions against literals keyed by fixture
line, and that is the part a reader may diff across hosts.

**Source-confirmed** against `smoke.zig:32-34`, `:59-97` and `:155-164`. The
program is not changed by this entry; its module comment is the code owner's, and
no gate was run. The receipts recorded for `zig build smoke` are pre-migration
linked-build runs and are unchanged by this wording.

## 36. Corrected the build graph's own account of `tools/`

The comment on `core_sources` listed `tools/` among the files this build
deliberately does not compile, and then went on to say that nothing here "builds
or installs" the directory and that it stays "out of the filtered package
closure". Both of those went false when `.paths` began naming the directory and
the install step began reading `tools/test.txt` out of it (entry 31). A build
graph whose own comment describes a closure its manifest does not have is the
same defect one file over, and it is the comment a reader trusts first.

What is still exactly true is kept: none of the seven files is compiled here,
`Makefile.am:7-12` lists the directory under `EXTRA_DIST`, and
`tools/linebreak_test.c:20` reaches outside the standard headers for
`<iconv.h>`, which no target in this matrix is promised. What changed is stated
next to it: the directory travels, because the install step reads one file out of
it and a package materialised from `.paths` could not install without it. Carrying
those bytes is not a claim that they build — the sentence that keeps the two
facts from being read as one.

**Source-confirmed** against `Makefile.am:7-12`, the install step at
`build.zig:1200` and `:1205`, and `build.zig.zon`'s `.paths`. A comment changed
and nothing else did: no build, fetch, test, gate, formatter or Nix command was
run, and no step, default, flag, path or output moved. The two install calls this
entry cites shifted from `:1194` and `:1199` to `:1200` and `:1205` because this
comment grew above them; entry 31's citations were repointed to match.

## 37. Decided the end of a UTF-32 decode by position, not by value

`Decode.Step.end` is how a caller knows to stop. All three decoders built the
answer from the returned value, comparing it with `EOS` — which is right for
UTF-8 and UTF-16 and wrong for UTF-32, because `EOS` is `0xFFFFFFFF`
(`src/unibreakdef.h:52`) and a UTF-32 buffer may legitimately hold that value.
Upstream returns the stored unit and an end-of-input as the same `utf32_t`
(`src/unibreakdef.c:168-172`) and tells them apart only by the index: it answers
`EOS` without advancing, and returns a stored unit by advancing one. The facade
folded those together, so a stored `0xFFFFFFFF` came back as `end = true` with a
zeroed code point, and a walk that stops on `end` lost the rest of the buffer.

`Decode.utf32` now answers on position — `verbatim(value, at, index == units.len)`
— so a unit holding `0xFFFFFFFF` comes back as itself with `end` false, and only
an index that was already at `units.len` ends the walk, leaving the index it was
given. UTF-8 and UTF-16 keep the value comparison and now say why it is sound
there: a `utf8_t` is `unsigned char` (`src/unibreakbase.h:47`) and a UTF-16 answer
is at most `U+10FFFF`, so neither can return the sentinel as a character. The
rule is stated where it is enforced — the `Decode` overview, `Step.index`,
`Step.end`, `Decode.utf32`, `step` and `verbatim` — and asserted by a regression
in `tests.zig` that decodes `{ 0x0061, 0xFFFFFFFF, 0x0062 }`, requires the
sentinel verbatim with `end` false, requires the unit behind it still to be
reachable, and requires the real end of the range to end the walk without moving
the index.

**Observed before and after, on the probe only.** The defect was an actual
failure, not a reading: the pre-fix probe swallowed a stored `0xFFFFFFFF` and
reported `end` true for it (`bg7275`). After the fix the same probe reports every
decoder observation correctly: the sentinel's `code_point` is retained, its
`index` is 2 and `end` is false; the complete walk reaches 3 with `index` 3; the
UTF-8 and UTF-16 controls are unchanged; and the four `MalformedUtf32` break
refusals still refuse (`bg762`).

That is the scope of the observation, stated exactly: a scratch consumer outside
the package. It is **not** the package suite and not the new regression — the
test added in `tests.zig` has still not been run, and neither has
`zig build test`. The rule, the doc comments and the regression are
`SOURCE-CONFIRMED` from the tree; the before-and-after pair is `OBSERVED` from
the probe; the package gates stay `PENDING-VERIFICATION`.

**Source-confirmed** against `zig/root.zig:470-474`, `:494-502`, `:533-553` and
`:555-583`, `tests.zig:1075-1100`, and the upstream lines they cite
(`src/unibreakdef.h:52`, `src/unibreakdef.c:168-172`, `src/unibreakbase.h:47`).
No build, test or gate was run by the entry's author or by this record: the
facade, the tests and the doc comments are read out of the tree, and the gates
that would observe them are listed in [`README.zig.md`](README.zig.md)'s pending
table. The probe lives outside the package, in the driver's scratch, and is run
by the driver; this record names its receipts and nothing more.

## 38. Named the CI step that exists instead of one that does not

`.github/workflows/verify.yml` said `build.zig` runs the loader's own tests under
a `runtime-test` step. No such step is registered: `build.zig` defines exactly
six — `smoke`, `test`, `exercise`, `upstream-test`, `consumer` and `check` — and
the loader's cases run inside `test`. The comment now names the step by its
registration text rather than by line number, which cannot go stale when a
comment above it grows, and it states what a runner does with the loader cases: a
CI runner sets no `LIBUNIBREAK_TEST_PROVIDER`, so those cases report the missing
provider rather than passing, and what the job establishes is that the generated
dispatch, the facade and the explicit exercise agree on the translated types.

**Source-confirmed**: the six `b.step` registrations in `build.zig`, the
corrected comment in `.github/workflows/verify.yml`, and `LIBUNIBREAK_TEST_PROVIDER`
being read only when a provider is required. CI remains **NOT RUN** and no
receipt is claimed; nothing in this entry says a runner has observed it.

## 39. Repointed the Unicode-revision citations

`runtime/library.zig:87` named `src/linebreak.h:34` and `src/graphemebreak.h:39`
as the places this tree's UAX #14 revision 55 and UAX #29 revision 47 are
written. The first was one line short and the second was wrong: the revision
banner is `src/linebreak.h:33-34` and `src/graphemebreak.h:31-32`, and line 39 of
the grapheme header is the start of its file-header comment. The same wrong pair
was corrected in `zig/root.zig` by the behaviour owner's edit; this entry is the
one file that still carried it, because that role does not own the runtime
directory.

**Comment-only.** Both citations were read out of the two headers before the edit
(`Revision 55, for` / `Unicode 17.0.0:` and `Revision 47, for` / `Unicode 17.0.0:`),
no logic changed, and no build, test, gate or formatter was run. The comment's
claim — a provider generated from a different revision answers differently on the
rows that changed — is unaffected and now points at the lines that say so.

## 40. Made every devenv task name this tree, and gave the installing ones a prefix outside it

`devenv.nix` only. No build graph, manifest, API, test, header or upstream byte
changed, and the task names are the ones this SDK has always used:
`sdk:build`, `sdk:test`, `sdk:smoke`, `sdk:upstream-test`, `sdk:consumer`,
`sdk:check`, `sdk:integrity` and `sdk:gate`.

Every exec body now begins by changing into this SDK's own directory, taken
from `./.` in the module and rendered once as `builtins.toString ./.` through
`lib.escapeShellArg`. Before this, a body inherited whatever directory the
caller stood in, and the acceptance driver enters this shell with `devenv
--from path:<this SDK>` from a scratch project directory that holds no
`build.zig`, no `UPSTREAM.sha256` and no `consumer/`. That is what two gates
reported on 2026-10-04: `sha256sum: UPSTREAM.sha256: No such file or directory`
from `sdk:integrity`, and `error: no build.zig file found, in the current
directory or any parent directories` from `sdk:consumer` — acceptance run
`nix-acceptance-20261004T175328Z`, receipts
`nix-acceptance-evidence/20261004T175328Z/libunibreak-devenv-integrity.log:20`
and `…-libunibreak-devenv-consumer.log:22`.
`$DEVENV_ROOT` names that project, so it was never the variable to trust;
`builtins.toString` rather than an interpolated `${./.}` is what keeps the path
this working tree instead of a read-only store copy of it.

The two bodies that install — `sdk:build` and the aggregate `sdk:gate` — pass
`--prefix` themselves. `zig build install`'s own default is `zig-out` beside the
build root, and this checkout is on the volume the driver digests before and
after a run, so a delivery tree written there is both in the wrong place and in
the comparison. The prefix is `$LIBUNIBREAK_INSTALL_PREFIX` when the caller
exported one, else `$ZIG_LOCAL_CACHE_DIR/libunibreak-install`, else
`$XDG_CACHE_HOME/libunibreak-install`, else `$TMPDIR/libunibreak-install`; with
none of the four set the task names what is missing and exits non-zero instead
of choosing a location of its own. `sdk:test`, `sdk:smoke`, `sdk:upstream-test`,
`sdk:consumer` and `sdk:check` install nothing — `build.zig` hangs the example's
and the exercise's compile steps under the install step (`build.zig:1223`,
`:1256`) and never the reverse — so they carry no prefix. Every body that
invokes `zig build` ends its command with `"$@"`, so a caller's `-Doptimize=`,
`-j8` or `--summary all` still reaches the build runner; no default, step name
or linkage changed.

The two gates that were failing are otherwise unchanged. `sdk:consumer` still
runs `zig build consumer`, which runs the separate `consumer/` package as its
own `zig build run` and forwards the selected target, optimize mode, linkage and
runtime route to it (`build.zig:1064-1102`) — the real native consumer, reached
through this build graph rather than by hand from `consumer/`. `sdk:integrity`
still runs `sha256sum -c UPSTREAM.sha256` over **all 66** records, the 59 pinned
upstream blobs and the seven `tools/` files; the record is neither filtered nor
trimmed.

**Source-confirmed, `PENDING-VERIFICATION`.** The two failure receipts are
observed; the repair is read out of `devenv.nix`, and no devenv, Nix, build, test
or formatter was run to produce it. §5 of [`README.md`](README.md) and
[`README.zig.md`](README.zig.md)'s pending rows are unchanged in status: the
`devenv shell`, task and packaged-output rows there are still
`PENDING-VERIFICATION` and are the driver's to move. The reasoning is
[`FORK-NOTES.md`](FORK-NOTES.md) §34.

## 41. Completed the installed-material table with the six records that directory already received

`NOTICE.md` and `FORK-LICENSE.md` documentation only. No build graph, manifest,
API, test, header, licence text, fixture or upstream byte changed, and the
install step still writes exactly what it wrote.

The row for `share/licenses/libunibreak/` named `NOTICE.md`, `FORK-LICENSE.md`
and `UPSTREAM.md` — the three records the install step installs by name
(`build.zig:1199-1201`) — and stopped there. Six more reach the same directory:
`build.zig:1213` calls `installLicenceRecords`, whose loop (`build.zig:586-587`)
walks `licence_records` (`build.zig:547-554`) into
`share/licenses/libunibreak/`. An installed output therefore carried **nine**
records and the table described three, which is a statement about a directory no
recipient receives. `build.zig`'s own module comment already named all nine
(`build.zig:250-255`), so the audit and the build graph disagreed inside one
package about what a recipient gets.

Two rows were short as paths rather than as counts. `libunibreak.pc` was placed
"under `$out`"; `addPkgConfig` writes `lib/pkgconfig/libunibreak.pc`
(`build.zig:194-195`, `:1015-1036`), which is now the path stated.
`$out/include/*.h` named no header and "or the shared library" named no file, so
the row now gives the five names of upstream's `include_HEADERS`
(`src/Makefile.am:1-6`) and the fixed shared-install names per platform
(`build.zig:176-186`).

One byte claim was added and it is checkable. `LICENCE` (1 045 bytes,
`0c57e2ec…`), `LICENCE-UNICODE.txt` (1 995, `e7a93b00…`), `AUTHORS` (697,
`34e46e31…`) and `README.upstream.md` (2 996, `cc38c7b8…`) were measured in this
working tree and all four agree with what `UPSTREAM.sha256` records for them at
`:64`, `:66`, `:69` and `:40` — three of that file's 66 checkable records, plus
`LICENCE-UNICODE.txt`, whose digest sits in the header comment because it is not
an upstream file. The other five records are this fork's own documents and are
deliberately given no byte count: their sizes move as they are edited, so a count
in a file that installs itself would be a count of a moment. `package.nix`'s
install check asserts five of the paths by name (`package.nix:120-124`); the table
is the whole statement and that check is a sample of it.

Two further statements of the same facts were completed with them, and neither
gained an assertion it did not already make. `FORK-LICENSE.md`'s own "Where
licence material is installed" table carried the same three-record view and the
same "`libunibreak.pc` under `$out`"; it now names the six `installLicenceRecords`
adds, gives the exact `.pc` path, and says the directory receives nine. Its
grant, its authorization, its file lists and its SPDX identifier are untouched.
`NOTICE.md`'s exclusion list said three files in this tree are not this fork's
and named `LICENCE`, `LICENCE-UNICODE.txt` and `README.upstream.md`; `AUTHORS` is
a fourth — an upstream blob pinned at `UPSTREAM.sha256:64`, and a file the four
copyright lines quoted near the top of that audit are drawn from — so it is now
named there too.

**Documentation-only, `SOURCE-CONFIRMED`.** Every path, line number and digest
above was read out of `build.zig`, `package.nix`, `UPSTREAM.sha256`,
`src/Makefile.am` and `AUTHORS` in this working tree. No build, install,
integrity gate, formatter or Nix step was run to produce it, so nothing here is a
gate result.
The reasoning is [`FORK-NOTES.md`](FORK-NOTES.md) §35.

## 42. Gave every canonical build this workspace's flags and a cache outside this tree

`devenv.nix`, plus the two paragraphs of §5 in [`README.md`](README.md) that
describe these bodies. No build graph, manifest, API, test, header, licence
text, fixture or upstream byte changed, and the task names are the ones this
SDK has always used: `sdk:build`, `sdk:test`, `sdk:smoke`, `sdk:upstream-test`,
`sdk:consumer`, `sdk:check`, `sdk:integrity` and `sdk:gate`.

Twelve `zig build` invocations in that file reached the build runner naming none
of the three flags this workspace's recipe names: one in each of `sdk:build`,
`sdk:test`, `sdk:smoke`, `sdk:upstream-test`, `sdk:consumer` and `sdk:check`, and
all six in the aggregate `sdk:gate` (`devenv.nix:175`, `:184`, `:192`, `:200`,
`:213`, `:221`, `:246-251`). Each now writes `--cache-dir`, `-j8` and
`--summary all`, in that order, before `"$@"` (`devenv.nix:71` holds the cache
path). Nothing in the file named `NIX_BUILD_CORES`, so `-j8` is a fixed count
rather than the `-j"${NIX_BUILD_CORES:-8}"` default, which is 8 only while that
variable is unset.

The cache is the other half, and it was the missing one. `zig build`'s own local
cache default is `.zig-cache` beside the build root — this checkout — and no
body named a cache at all, so each of the twelve would have written into the
tree the driver digests before and after a run. Every body that reaches a
compiler now runs a `chooseCaches` preamble first (`devenv.nix:78-107`): a
`ZIG_LOCAL_CACHE_DIR` or `ZIG_GLOBAL_CACHE_DIR` the caller exported is used
exactly as it is and never overwritten, only a missing one is filled — from
`$XDG_CACHE_HOME`, then `$TMPDIR` — and with `ZIG_LOCAL_CACHE_DIR`,
`$XDG_CACHE_HOME` and `$TMPDIR` all unset the body names what is missing and
exits before any compiler runs. The global cache falls back last to the local
cache root, which is known by then. The fill is in the bodies rather than in
`enterShell` because `devenv tasks run` materialises a task as a generated
program and does not run the shell's hooks.

That repair also fixed the prefix this file already documented. `choosePrefix`
could resolve to `$TMPDIR/libunibreak-install` while no cache was exported, so
the delivery tree landed beside a cache nothing had named; it now runs after the
cache fill and takes its `ZIG_LOCAL_CACHE_DIR` branch in every case where the
body got that far (`devenv.nix:109-141`). The resolution order and the
fail-closed message are otherwise unchanged, as is the fact that only the two
installing bodies pass `--prefix`: `build.zig` hangs the example's and the
exercise's compile steps under the install step and never the reverse
(`build.zig:1223`, `:1256`), and the consumer's `run` step is independent of its
own install step (`consumer/build.zig:66-70`), so `test`, `smoke`,
`upstream-test`, `consumer` and `check` install nothing and name no prefix.

Everything else about the bodies is unchanged: every one still changes into this
SDK's own directory before it runs anything, `"$@"` is still last so a caller's
flags — including a `--cache-dir`, `-j` or step of its own — still reach the
build runner after these, the step names and linkage defaults are the same, and
`sdk:integrity` still checks all 66 records of `UPSTREAM.sha256`.

**Source-confirmed, `PENDING-VERIFICATION`.** Nothing was executed to produce
this entry: no devenv, Nix, build, test or formatter was run. The lines above
were read out of `devenv.nix`, `build.zig` and `consumer/build.zig` in this
working tree. Every gate row in [`README.md`](README.md) and
[`README.zig.md`](README.zig.md) is unchanged in status; the driver owns them.
The reasoning is [`FORK-NOTES.md`](FORK-NOTES.md) §36.

## 43. Gave the nested consumer build its CPU, its global cache, its job count, its summary and the caller's arguments

`build.zig`'s `runConsumer` and `consumer/build.zig`, and nothing else. Six
argument-list lines across two existing bodies; no option added, no default
changed, no step renamed, no upstream byte, header, test or fixture touched.

The conditions, read from the pinned compiler:

* **The CPU.** The triple does not carry one — `Query.zigTriple` writes the
  architecture and nothing else (`lib/std/Target/Query.zig:421-423`) — so
  `-Dcpu=` now comes from `Query.serializeCpuAlloc` (`:530-533`) beside it. The
  consumer's `b.standardTargetOptions(.{})` declares `cpu` beside `target` and
  passes both to `b.dependency`, so this is that build's own input, not a
  default.
* **The global cache.** `--global-cache-dir`, two tokens, from
  `b.graph.global_cache_root.path`, with no `/consumer` subdirectory because it
  is content-addressed package storage meant to be shared — which is why the
  compiler forwards it verbatim from a build script
  (`lib/std/Build/Step/Compile.zig:1477-1480`), where the local pair is not. The
  two caches are not interchangeable fields: `cache_root` is on `Build`
  (`lib/std/Build.zig:58`) and `global_cache_root` is on `Graph` (`:122`, inside
  `pub const Graph` at `:112`), so `b.global_cache_root` does not exist. The
  runner populates it unconditionally (`lib/compiler/build_runner.zig:53-54`,
  `:73-76`, `:89`) and spells the option as two tokens at `:1675`.
* **Width and summary.** `-j8`, and `--summary all` as two tokens
  (`lib/compiler/build_runner.zig:1639`, `:1640-1644`). Nothing can append a
  `-j` to a `Run` step's command, so the nested build took `cpu_count - 1`; and
  `--summary` left at its default reports `.failures`, which prints nothing on
  a consumer that passed.
* **The caller's arguments.** `--` then `b.args`, last. `consumer/build.zig:69-74`
  is the other half: `Step.Run` does not forward `b.args` itself, so without
  that line the nested build's arguments stop before the program.

Changed arguments, in the order they now appear: `-Dcpu=…`, `-j8`,
`--summary all`, `--global-cache-dir …`, `--` plus the caller's own. Unchanged:
`-Dtarget=` still serialized from `target.query` and not `target.result`,
`-Doptimize=`, `-Dlinkage=`, `-Druntime=` still written on both sides of the
branch, all five executor switches, `--libc-runtimes`, `--cache-dir` with its
`/consumer` subdirectory, always `run`, and `has_side_effects`.

This entry moves `runConsumer` from `build.zig:1064-1102` to `:1068-1169` and
everything below `:1102` by 67 lines. Earlier entries keep the numbers they were
written with, per entry 32's rule; the same pointers in `FORK-NOTES.md`,
`README.md`, `README.zig.md`, `NOTICE.md`, `FORK-LICENSE.md`, `build.zig.zon`
and `devenv.nix` are outside this entry's two files and are reported to the
parent rather than edited.

**Source-confirmed, `PENDING-VERIFICATION`.** No build, test, compiler, Nix,
devenv, formatter or linter was run, and no gate has run `zig build consumer`
over this source. The receipt the driver still needs is
`zig build consumer -j8 --cache-dir <scratch>/libunibreak/consumer
--global-cache-dir <approved> --summary all`, and then the same with
`-- --provider <prefix>/lib/libunibreak.so` under
`-Dlinkage=dynamic -Druntime=true`, which is the cell that makes the argument
forwarding observable rather than theoretical. Gate rows in
[`README.md`](README.md) and [`README.zig.md`](README.zig.md) are unchanged in
status; the driver owns them.

**Corrected 2026-10-04, by entry 44.** The `:1068-1169` range and the 67-line
shift above describe `build.zig` as this entry left it. Entry 44's `--prefix`
relay lengthened `runConsumer` again, so the range has moved a second time and
the four documents this migration owns now name the symbol `runConsumer` instead
of a range. Nothing else in this entry changed: the arguments, their order and
both hops are as written above.

## 44. Carried the outer install prefix into the nested consumer build, and made both READMEs state what that build receives

`build.zig`'s `runConsumer`, plus this file, [`README.md`](README.md),
[`README.zig.md`](README.zig.md) and [`FORK-NOTES.md`](FORK-NOTES.md). One new
argument in one existing function; no option added, no default changed, no step
renamed, no API, header, test, fixture or upstream byte touched.

`runConsumer` forwards the selections, both caches, the width, the summary and
the caller's arguments to the nested `zig build run` in `consumer/` (entry 43),
and it forwarded no prefix. A caller's `zig build consumer --prefix <path>`
therefore installed the consumer under the nested build's own default,
`<its build root>/zig-out`, rather than the prefix the caller named. The step
does not install the library, so this never affected the library's own install
layout — it was the consumer's delivery going somewhere the caller did not
choose.

It now emits `--prefix` when, and only when, `b.install_prefix` differs from
`b.build_root.join("zig-out")`, the nested build's default. A relative prefix is
made absolute against `b.graph.cache.cwd` first, because the nested build's
working directory is `consumer/` and a relative path handed to it resolves
somewhere else. The relay sits after `--global-cache-dir` and before the `--`
handover, so it cannot be read as a program argument, and there was no prior
`--prefix` in this file, so nothing is duplicated. A dependency's install
prefix is chosen by the build system and by neither caller, which is why the
relay is the whole of what can be said about it — the same reason, and the same
shape, as `tzdata`.

The documentation half names symbols instead of line numbers. The `runtime` and
`linkage` options, the two `b.getInstallStep().dependOn` calls,
`installLicenceRecords`, `licence_records`, `addPkgConfig` and `runConsumer`
itself had all shifted under the citations in entries 28, 30, 31 and 32 and in
`FORK-NOTES.md` §28, §29, §34, §35 and §36; those pointers inside the four
documents this entry owns are now the declarations themselves. Earlier entries
keep the numbers they were written with, per entry 32's rule.

`README.md` §5 and `README.zig.md`'s `consumer` step row said the nested build
receives "the selected target, optimize mode, linkage and runtime route". It
receives those four plus the CPU, the selected executor flags, the local cache
with its `/consumer` subdirectory, the global cache verbatim, `-j8`,
`--summary all`, the outer prefix when the caller moved it, and `--` plus the
caller's own arguments — and `consumer/build.zig` then forwards `b.args` to the
program's `run_exe`, so `zig build consumer -- --provider <path>` reaches the
program on both hops. Both documents now say so, and both say why the two
caches differ: the local cache holds this graph's manifest directory and is
locked for the life of the process holding it, while the global cache holds
content-addressed package directories meant to be shared between builds.

**Source-confirmed.** Every flag, field name and comparison was read out of
`build.zig` and `consumer/build.zig` in this working tree. No build, test,
compiler, Nix, devenv, formatter or linter was run here, and this entry moved no
gate row in [`README.md`](README.md) or [`README.zig.md`](README.zig.md). The
reasoning is [`FORK-NOTES.md`](FORK-NOTES.md) §37.

**One cell observed, bounded.** Nested delivery-proof run
`20261004T220323250122Z-515d06adcbbf` recorded **9/9 PASS** over
`zig build consumer` and the `consumer/` package across all four delivery
routes — static and dynamic, each linked and each runtime-loaded — each
exercised once with the selections omitted and once with `target`, backend,
`linkage`, `runtime`, both caches and the prefix named explicitly. Three
results in that run bear on this entry: the nested prefix relay's actual command
line and the installed inventory agree; the loaded routes reached their provider
through `--provider` on argv with every provider environment variable absent, so
there is no second handoff to be ambiguous with; and the same run without a
provider exited 1 with the refusal. That is nine cases of the nested consumer
build. It does not move the `zig build test smoke consumer upstream-test` row,
the six baseline targets, the 53-platform matrix, the filtered-fetch consumer,
the packaged Nix outputs or the devenv tasks, all of which stay
`PENDING-VERIFICATION`, and it is not a claim about any cache-fallback guard.
The receipt the driver still needs for this entry is a gate over the remaining
rows, not another consumer run.

## 45. Loaded this tree's own image into all eight configurations, and measured the external one against it

Documentation only: this file and short pointers in [`README.md`](README.md),
[`README.zig.md`](README.zig.md) and [`FORK-NOTES.md`](FORK-NOTES.md). No build
graph, manifest, API, test, header, fixture, licence text or upstream byte changed,
and no earlier entry or historical count is restated.

`verify_native_final.py --loaded`, run `20261004T232823091897Z-23133`, named this
tree's own shared object (`kind: own`, `libunibreak.so.8.0.0`) as the provider for
all eight configurations — `{static, dynamic}` × `{Debug, ReleaseSafe,
ReleaseFast, ReleaseSmall}` — under `-Druntime=true`. **Eight of eight passed**,
each with `Build Summary: 32/32 steps succeeded; 20/20 tests passed`, `smoke
success`, `test success` and `tests_skipped` 0. Receipt
`…/loaded-final-evidence/20261004T232823091897Z-23133/run.json`.

The same eight cells against an external image, run
`20261004T233121760876Z-12541`, **failed 8 of 8**: each `smoke success` and then
`17/20 tests passed (3 failed)`, exit 1, with the three failures the same in every
cell — `LineBreakTest.txt:35`, `WordBreakTest.txt:1059`, `GraphemeBreakTest.txt:771`
— the three replays of the Unicode fixtures, through `tests.zig:314` `failOpcode`.
Receipt `…/loaded-final-evidence/20261004T233121760876Z-12541/run.json`. The
provider reported `0x501`; its own Unicode revisions are in neither receipt and none
is asserted.

Same source, same fixtures, same loader, same dispatch; the static-Debug install
inventory digest is `73421ff9…` in both runs, so the cells delivered the same tree
and differ only in which image answered. That is the boundary
`runtime/library.zig:85-89` and `:106-137` already names — this tree is UAX #14
revision 55 and UAX #29 revision 47, and resolving nineteen symbols is not proof of
provider compatibility. Nothing was re-run, no fixture was relaxed, and no loader,
ABI or source change follows.

The earlier external probe (run `20261004T232439Z`) is narrower than either: one
target, one linkage and mode, four external successes and five refusals against a
fixed known answer, and no replay of the fixtures through a loaded provider. It
supports none of the eight cells and contradicts neither result.

What did run, from `tests.zig`: all twenty cases in both runs, including both loader
controls — the nameless-request refusal (`:130`) and the unopenable-provider retry
(`:141`) — whose `:131`/`:142` guards do not fire under `-Druntime=true`. No case in
this SDK builds a provider that opens and lacks a required symbol, and
`runtime/graph.zig:83-112` leaves `provider_optional` and `provider_excluded`
empty, so all nineteen names are required; the missing-symbol case is untested here
by design, and the driver-owned map records no `alien_path` for it.

## 46. Let the consumer step choose `run` or `install` instead of always asking for a run

`build.zig`'s `runConsumer` and its new private predicate, plus the
current-facing statements in [`README.md`](README.md) §5,
[`README.zig.md`](README.zig.md)'s `consumer` step row and [`FORK-NOTES.md`](FORK-NOTES.md)
§20. One argument and one function; no option, default, step name, API, header,
test, fixture, licence text or upstream byte changed.

`runConsumer` asked the nested build for `run` whatever the target was, which is
the wrong question: on a target this host cannot execute the nested `Run` step
fails and takes the whole `consumer` step with it, and on a target reachable only
through an executor the build runner was never told to use, nothing fails and the
answer is wrong the other way. It now asks `std.zig.system.getExternalExecutor`
about the resolved target — the predicate `std.Build.Step.Run` itself asks about
the artifact it is about to spawn — with each `allow_*` carried from this build's
own executor switches, so the chooser and the nested run read the same facts and
cannot disagree. `run` for every executor it is allowed to use, `install` for
`.bad_dl`, `.bad_os_or_cpu`, and for a cross GNU-libc target given no
`--libc-runtimes` directory, which `Run` fails rather than skips.

Everything else the nested build receives is untouched: the target triple and CPU
serialized from `target.query`, the optimize mode, the linkage, `-Druntime`, the
executor switches, `--libc-runtimes`, `-j8`, `--summary all`, both caches, the
install prefix when the caller moved it, and the caller's own arguments behind
`--`. `consumer/` already installed its executable, so the `install` branch needed
no new step, no new option and no change in `consumer/`.

The statements this replaces are corrected where they are current-facing;
entry 19 and §20's history are left as written, and this entry with §39 name what
changed. An install is compile evidence and nothing more, so it is not a consumer
exchange and a foreign cell stays `INSTALL_ONLY`.

**Source-confirmed.** Every field, comparison and cited line was read out of the
pinned compiler's `lib/std` and out of this working tree. No build, test,
compiler, Nix, devenv, formatter or linter ran here, and no gate row in either
README moved.

## 47. Recorded the current graph's own waves, and a linked cell as a partial rather than a pass

Documentation only: this file, and the matrix rows in [`README.md`](README.md) §3
and [`README.zig.md`](README.zig.md)'s Verification status. No build graph,
manifest, API, test, header, fixture, generated table, licence text or upstream
byte changed; no earlier entry and no historical count is restated. Entries 45
and 46 keep their numbers and their receipts; this entry adds the four waves
that were not yet written down and corrects the two rows that had gone stale
against them.

**The 53-target cohort, re-run on this graph.** Epoch
`20261004T221720228710Z-45046`, receipt `libunibreak-53-target-8.json`, at
`target_jobs=8` and `jobs_per_build=8`, `source_unchanged: true` and
`jobs_honoured: true`. **53 targets: 20 runtime PASS, 33 `build_only`, 0 fail,
driver exit 0.** Every one of the 20 that ran recorded `raw_run_tests: 18`, the
same eighteen the linked route reaches. The 33 are `build_only`, reason
`runtime_unavailable`: a compiled foreign test binary is not a pass, so this
cohort is **twenty runtime passes and thirty-three compiles**, and "53 targets
built" is not "53 targets ran".

**The six baseline targets, compile-only.** Epoch `20261005T014547Z-797a73f2`,
row `baseline-libunibreak-check`: one whole-graph `check` over the six declared
targets, `Build Summary: 43/43 steps succeeded`, exit 0, `failed: false`,
`runtime_pass_claimed: false`. The receipt says so in its own words — a
compile-only row derives no runtime result under any exit code — so this is
compilation evidence and nothing more.

**The native eight-cell wave is a partial, and it is not eight passes.** Epoch
`20261004T233628757747Z-69351`, `{static, dynamic}` × `{Debug, ReleaseSafe,
ReleaseFast, ReleaseSmall}`, no `-Druntime`. Every cell is `status:
"skipped-tests"`, exit 0, each `Build Summary: 31/31 steps succeeded; 18/20
tests passed (2 skipped)`, and the run names its own skip sites: `tests.zig:131`
and `tests.zig:142`, both guarded
`if (!libunibreak.runtime_loaded) return error.SkipZigTest;`. Those two cases
only exist on the loaded route, so a linked cell cannot reach them. Entry 45's
`20/20` is therefore not contradicted by this wave; it is the same suite on a
route where the two loader tests run, and 18 is the ceiling on the other one.

**What the external failure is, and what it is not.** The provider is
`/lib64/libunibreak.so.5.0.1`, sha256
`dca1509ee9cac0e321eef98a83eb38fd1bed52c6c45eaba6d4d383f36139b10d`, from the
route wave `20261004T232439Z`, receipt `libunibreak-index.json`
(`kind: compatible-external`).
Its file name and soname carry `5.0.1` and `5`, and its exported
`unibreak_version` word reads `0x0501`, while the probe prints that this package
is pinned to `0x0800` and that no comparison is made. **That is the whole of
what was observed about the provider, and the cause of the three failing rows in
entry 45 is not established.** A soname is an ABI tag rather than a release
number; no external Unicode or UCD version was queried, and none is assumed
here. What is therefore not claimed: that the provider is an upstream release of
any particular version, that these three failures are a Unicode or
table-version difference, full compatibility with any external provider,
Unicode-version agnosticism of this SDK, and the result a provider matching this
package's own pin would give — that run was never made.

The loader's side of the same wave is a fact about the header, and it is why the
provider was usable at all: that object exports four names this header does
not declare (`set_linebreaks`, `lb_init_break_context`, `lb_process_next_char`,
`ub_is_extended_pictographic`) and omits `ub_bsearch`. Extra exports are never
consulted, and `ub_bsearch` is a C99 inline whose body sits in
`src/unibreakdef.h` and which the translation copies rather than routes, so
requiring it would refuse a provider over a name no caller is asked to reach.

**Documentation-only, and nothing is re-gated.** No build, test, compiler, Nix,
devenv, formatter or linter ran while writing this entry. Every number above is
read out of a named receipt, and the driver's foreign-delivery candidate
`libunibreak.txt` remains an analysis that has not been executed, so no foreign
cell is claimed here in either direction.


