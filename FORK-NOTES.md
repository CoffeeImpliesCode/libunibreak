# FORK-NOTES.md — what actually went wrong, and what was decided

Problems met while packaging libunibreak 8.0 as a Zig 0.16 package, and the
decisions they forced. Written in the shape a later wave can reuse: **condition,
symptom, cause, fix, what it is bound to**. Statuses are the workspace's:
`SOURCE-CONFIRMED` (read out of a file at the pin, never executed), `OBSERVED`
(a gate the driver ran here, with its receipt, mode and exit code named),
`PENDING-VERIFICATION` (landed, no gate has looked at it), `NOT RUN` (no receipt
exists at all).

**The driver has since run the native gates on this host**: in `Debug`, the
install of the current source together with the facade tests, the API exercise,
the example, the consumer package and upstream's own harness (exit 0,
`23/23 steps`, `15/15 tests`); the same tests, example and consumer in
`ReleaseSafe`, `ReleaseFast` and `ReleaseSmall` (exit 0, `13/13 steps`,
`15/15 tests` each); the six-target compile-only `check` (exit 0,
`43/43 steps`); the 53-platform `cross-test` matrix; an installed-C program
compiled against the install prefix and run against that archive;
`sha256sum -c UPSTREAM.sha256` (exit 0, 59 `OK`); this working tree against the
pinned blobs; this package's own README example, run as a program; and `zig
fmt` over the nine fork-authored Zig/ZON files. The filtered-fetch consumer and
package integrity gate are recorded outside this package, in
`local://foundation-matrix-final-package-proof.json`; nothing here claims a
result for them, and neither CI nor any linter has run. Entries below say which
claim a run has settled; the authoritative table is
[`README.zig.md`](README.zig.md#verification-status), and every `OBSERVED` line
here names the receipt it rests on.

Two entries — 3 and 4 — are not build problems. One is a documentation defect in
upstream's own repository, and one was a mistake in this fork's own provenance
record. Both are kept because a record that only contains other people's
mistakes is not a record.

---

## 1. Seven generated tables, six of which are not translation units

**Condition.** `src/Makefile.am:11-20` lists nine sources in
`libunibreak_la_SOURCES`, and one of them, `linebreakdata.c`, is a generated
Unicode table 8 988 lines long. Six more generated tables sit in `src/` beside
them.

**Symptom.** Not a failure — a question with several wrong answers available.
Which files are translation units? Three plausible sources give three different
lists.

**Cause.** The distinction is invisible in the file names, and it lives in
storage class. `src/linebreakdata.c:9,791,795` define `lb_prop_supplementary`,
`lb_prop_supplementary_len` and `lb_prop_bmp` with **no `static`**; all three
are declared `extern` at `src/linebreakdef.h:233-235` and referenced from
`src/linebreak.c:613`. Cross-translation-unit references mean it cannot be an
include. The other six define `static const` arrays (`linebreakauxdata.c:12`,
`wordbreakdata.c:8`, `graphemebreakdata.c:8`, `indicconjunctbreakdata.c:8`,
`eastasianwidthdata.c:10`, `emojidata.c:8`) and are `#include`d by bare name into
a core unit. Compiling one of those six as well would be a duplicate definition
of every table in it; omitting `linebreakdata.c` is an undefined symbol at link
time.

**Fix.** The nine-unit list is written out literally in `build.zig` and
tabulated in [`UPSTREAM.md`](UPSTREAM.md#what-is-compiled-and-with-which-switches)
with the storage class that proves each entry. No glob, because a glob would let
a unit be added to or dropped from the archive without a decision.

**Bound to.** Any C project that mixes generated data files into its source
directory. The test is storage class, not file name, and it works everywhere.

**Status.** `SOURCE-CONFIRMED` for the storage classes, and `OBSERVED` for the
consequence: all nine units compiled and linked into `libunibreak.a` in the
native `Debug`, `ReleaseSafe`, `ReleaseSmall` and `ReleaseFast` builds, and all
53 cross-target builds succeeded
(`local://foundation-matrix-libunibreak-unicode-r7.log` and the three optimized
receipts). Had `linebreakdata.c` been omitted, or one of the six included files
been compiled as well, those builds could not have succeeded.

---

## 2. The screen report's own source claims were wrong three times

**Condition.** The selection screen for this library
(`local://foundation-project-matrix-ScreenLibunibreak.md`) made three specific,
checkable claims about the source at this pin.

**Symptom.** All three were wrong, in the direction that matters, and two of them
would have been copied straight into this fork's build.

**Cause.** A report assembled from headers and `Makefile` fragments without
reading the two files the claims were actually about.

**Fix.** Each was checked against the source at the pinned commit:

| Claim | What the source says |
|---|---|
| "`src/Makefile.gcc` lists only eight files in `CFILES`" | It lists **nine** (`src/Makefile.gcc:108-110`), identical to `src/Makefile.am`. The six textually included files are correctly absent from it and `linebreakdata.c` is correctly present. |
| "`graphemebreak.c` reaches `unibreakdef.h` only transitively" | It includes it directly, at `src/graphemebreak.c:55`. |
| The pinned tree has 65 blobs | It has **67**, read from the pin's tree object. |

`src/` goes on the include path for every translation unit regardless, so the
second one changed no behaviour — but a record that says "transitively only"
would send the next reader looking for the wrong thing.

**Bound to.** Any secondary source about a codebase, including one produced by a
careful agent in this same workspace. Read the file the claim is about.

**Status.** `SOURCE-CONFIRMED`, with the corrections recorded here and in
[`UPSTREAM.md`](UPSTREAM.md).

---

## 3. Upstream's own architecture document is stale in two places

**Condition.** `doc/architecture.md` ships with this package, unmodified.

**Symptom.** Two of its statements are contradicted by the 8.0 source.

**Cause.** The document was not updated with the code.

**Fix.** Recorded, **not edited**. Upstream documentation is not this fork's to
change, and a correct local edit would be a silent second divergence.

* `doc/architecture.md:88` lists "A `bool` fallback for MSVC older than VS2013"
  among the contents of `unibreakdef.h`. There is no such fallback:
  `src/unibreakdef.h:38` includes `<stdbool.h>` unconditionally and no `_MSC_VER`
  or `bool` fallback appears anywhere in the tree. This is a documentation
  defect, not a portability limitation — any VS2013-or-newer compiler has
  `<stdbool.h>`.
* `doc/architecture.md:92-94` says every generated `*data.c` "defines `static
  const` arrays and is `#include`d directly into the module's `.c` file (it is
  not compiled separately)", and its table row at `:98` therefore lists
  `linebreakdata.c` as included by `linebreak.c`. Both halves are false; see
  entry 1. The other six rows of that table are correct.

**Bound to.** This pin and this file. A future upstream release may fix either.

**Status.** `SOURCE-CONFIRMED`.

---

## 4. A `sha256sum` of the working tree is a digest of this fork, not of upstream

**Condition.** `UPSTREAM.sha256` must record upstream's bytes. The build role
appends a Zig block to upstream's `.gitignore`, which makes the working-tree
file differ from the pinned blob.

**Symptom.** The first draft of the record quoted a digest for
`.gitignore` **as upstream's**, measured from the file on disk after that append
had landed. The build role caught it: the quoted digest was of the 69-line
forked file, not of upstream's 43-line one.

**Cause.** A working tree is a mutable thing. Reading a digest from it and
labelling it "upstream" is a category error that only shows up when someone
compares the two numbers.

**Fix.** Two changes, and the second is the one that matters. First, the quoted
digest was replaced with one read from the pinned commit's blob:
`bbad54185e3da91dacb7854b544440426c2ff2cf71062995cdcdfd5ea56fae07`, 549 bytes,
43 lines, with the forked working-tree digest `47aad4f8…` named separately as
what it is. Second — and this generalises past the one file — **all 59 records
were re-derived from the pinned commit's blobs and compared against the record:
59 compared, 0 disagreements.** The record is now a claim about upstream's bytes
rather than about a directory a build could have touched. The tree walk also
confirms there are no symlinks and no non-regular entries under `src/` and
`doc/`, so every digest is of the file's own bytes.

**Bound to.** Any integrity record that claims to describe an upstream. The
general rule: hash the **pinned object**, not the working tree, and if only the
working tree is available, say which one the number is.

**Status.** `SOURCE-CONFIRMED` for how the digests were derived, and `OBSERVED`
for the check itself: `sha256sum -c UPSTREAM.sha256` ran on this host at exit 0
with 59 `OK` lines and no failure
(`local://foundation-matrix-libunibreak-provenance-checksums.log`, 2026-10-03).
A wider comparison of all 67 pinned blobs against this working tree found one
difference — `.gitignore`, the file entry 13 explains —
(`local://foundation-matrix-source-integrity.json`).

---

## 5. C99 inline is load-bearing, and its failure mode is a missing symbol

**Condition.** `src/unibreakdef.h` declares `ub_bsearch` as a plain `inline` and
`src/unibreakdef.c` closes with `extern inline … ub_bsearch(…)`.

**Symptom.** Under C89 inline rules that combination never emits the symbol, and
the failure appears at link time as an undefined reference — which reads like a
missing file in the source list, not like a dialect problem.

**Cause.** No `-std` flag appears anywhere in upstream's own build files;
upstream relies on the compiler default, and each compiler has one.

**Fix.** `-std=c99` is stated explicitly on every C translation unit of this
build, on the translation as well as the compile line, because it is a
requirement and not a preference.

**Bound to.** Any project using the C99 `inline` + `extern inline` idiom for
linkage. A future upstream release that changed the idiom would remove the
requirement.

**Status.** `SOURCE-CONFIRMED` for the source, and `OBSERVED` for the link: the
archive linked in all four native modes, in the six-target `check`
(`43/43 steps succeeded`,
`local://foundation-matrix-libunibreak-six-baseline.log`) and in all 53
cross-target builds, which is the outcome that only happens when the C99
`inline`/`extern inline` pair emits `ub_bsearch`.

---

## 6. The library's own name and the module's name are different, on purpose

**Condition.** `zig build` must emit upstream's archive name, and a dependent
must have a short, unsurprising name for the dependency.

**Symptom.** One name cannot be both `libunibreak` and `unibreak`.

**Cause.** Zig prepends the target's `lib` prefix to a library artifact's
`Compile.name`, so a `Compile.name` of `unibreak` emits `libunibreak.a` — which
is what `src/Makefile.gcc` and `libunibreak.pc.in` both call the result — while
the registered module and the dependency-map key are `libunibreak`.

**Fix.** The driver's choice, recorded here because it looks like an alias and is
not: `dep.module("libunibreak")` is the whole dependency surface, and a consumer
needs no `dep.artifact` at all, because the archive and the translated headers
arrive with the module. `dep.artifact("unibreak")` exists for a C-facing or
otherwise module-less consumer and links `-lunibreak`. Adding a second
`linkLibrary` in a module-only consumer would put the same archive on the link
line twice and prove nothing.

**Bound to.** This package. It is an ABI identity, not a rename: a different
artifact name would ship a different file name than upstream's.

**Status.** `SOURCE-CONFIRMED` (names in `build.zig`), and `OBSERVED` for the
link: `zig build` installed `lib/libunibreak.a`
(`local://foundation-project-matrix-libunibreak-r1-native-install.log`), and the
module-only consumer package ran in all four native modes
(`local://foundation-matrix-libunibreak-unicode-r7.log` and the three optimized
receipts).

---

## 7. There is no system mode, and that is recorded rather than satisfied

**Condition.** The workspace rule is that system-library mode is used only where
a real compiled system library exists, and must translate the headers it links.

**Symptom.** Rule W14 applies to forks with a system mode. This one has none.

**Cause.** This wave's contract keeps the source pin and the bounded contracts
identical in every mode. A distribution's libunibreak is not this manifest's
pinned 8.0 with this manifest's headers, and translating these headers against
it is exactly the header/ABI mismatch the rule forbids — bundled new-release
headers against an older installed library compile and fail silently.

**Fix.** No `-Dfsys=` option, no `b.systemIntegrationOption`, no claim about any
system-installed libunibreak. The rule is recorded as **NOT APPLICABLE**, in
`build.zig` and in [`README.zig.md`](README.zig.md), rather than presented as
satisfied. A user who has installed a matching 8.0 can still use the raw C route
against their own headers; that is their decision, not a mode this package
offers.

**Bound to.** This wave's contract. It is a decision, not a finding, and a later
wave could reverse it if a real matching system build were established.

**Status.** `SOURCE-CONFIRMED` / `CONSTRAINT`.

---

## 8. Validation costs a pass, and one method makes that pass do double duty

**Condition.** The typed API promises to reject undersized output, overlapping
buffers and malformed encoding — and the native library validates **nothing**:
no decoder checks its input, and the only `assert`s vanish under `NDEBUG`.

**Symptom.** Every method needs a scan the native function will then repeat.

**Cause.** The C cannot be trusted to notice, so the check has to happen before
the call.

**Fix.** Two shapes, chosen so the cost is explicit:

* the **per-code-unit** methods scan once to reject malformed encoding, then call
  native, which scans again: **two passes**, and the first is the price of the
  promise;
* the **per-code-point** methods **count the code points in that same validation
  scan** rather than walking the input a second time, then check capacity against
  that count and only then call native. The validation pass is paid once and its
  result is not thrown away.

That second point is not an optimisation, it is correctness: native
`set_linebreaks_*_per_code_point` returns the number of entries it wrote and
never tells the caller what that number should have been, and upstream's own
harness sidesteps the question by over-allocating to the line length
(`src/tests.c:186-196`). Sizing a buffer to the code point count requires
knowing the code point count.

**Bound to.** This API shape. A caller who already knows the input is well-formed
and does not want the first pass should use the raw C route, which does exactly
one scan; that trade is stated in [`README.zig.md`](README.zig.md) rather than
hidden.

**Status.** `SOURCE-CONFIRMED` for the source facts; the cost itself is not
measured and no performance claim is made anywhere.

---

## 9. Refusals are ordered so that nothing is written before anything fails

**Condition.** A method takes the caller's output buffer and can refuse.

**Symptom.** A partial write would leave the caller holding a plausible-looking
half-result with no way to tell.

**Cause.** Order of operations, which is a design decision and not an accident.

**Fix.** Overlap, capacity and encoding are all checked **before** the native
call is made. Every failure therefore leaves the caller's buffer holding exactly
the caller's own bytes — nothing zeroed, nothing half-filled, nothing to discard.
The test suite asserts that residue property for all four refusals rather than
just the error value.

**Bound to.** The typed API's contract. The raw C route has no such guarantee,
because the raw C route is upstream's behaviour and upstream does not promise
one.

**Status.** `SOURCE-CONFIRMED` for the code's shape, and `OBSERVED` for the
residue property: the tests that assert it for all four refusals passed in all
four native modes, and the consumer prints the untouched-buffer counts for the
same four refusals in each of them.

---

## 10. `lang` does nothing for two of the three algorithms

**Condition.** Every upstream entry point takes a `lang` argument.

**Symptom.** For word and grapheme breaking it is ignored:
`src/wordbreak.c:169-170` is literally a
`/* TODO: Language-specific specialization. */ (void)lang;` and all three
grapheme entry points do `(void)lang`.

**Cause.** Upstream kept the parameter for a uniform signature and left the
specialization unwritten.

**Fix.** The typed API **omits** `lang` from `Word` and `Grapheme` entirely. A
typed option that does nothing is worse than no option, because a caller will
build a behaviour on it. The raw route still exposes the parameter, because
dropping it there would change upstream's signature.

For line breaking the parameter is real, and three of its properties have to be
passed through rather than tidied up: matching is **by prefix, not equality**
(`strncmp` over 2-byte codes, so `"zh-CN"` matches `zh` and so would `"zhx"`),
`null` and `""` both mean no tailoring, and `"-strict"` is the UAX #14
Conditional Japanese Starter tailoring — the one place the option changes an
answer.

**Bound to.** This pin. Upstream's TODO could be implemented, and a later wave
would then need to add the parameter back.

**Status.** `SOURCE-CONFIRMED`.

---

## 11. `INDETERMINATE` is a fifth opcode the oracle cannot express

**Condition.** `src/linebreak.h:59-63` defines five line opcodes, not four.
`INDETERMINATE` is written at the final position of text that does not end in an
explicit break (`src/linebreak.c:1512-1515`), where `MUSTBREAK` is written
otherwise.

**Symptom.** The Unicode test files have no way to say "indeterminate".

**Cause.** The conformance format has three states — break, no break, inside a
character — and this one is not among them.

**Fix.** Upstream's own harness folds `ALLOWBREAK` and `INDETERMINATE` both into
`MUSTBREAK` before comparing (`src/tests.c:266-273`), with the comment "The
Unicode test data doesn't differentiate between these states". This package
keeps all five values in `LineOpcode` and performs that fold **only** at the
comparison against the fixture, exactly where upstream does it, and nowhere
else; its own direct behavioural tests assert the difference between an explicit
break and an ordinary one. Silently dropping the distinction in the facade would
lose information the C actually produces.

**Bound to.** The conformance format. If Unicode adds a way to express it, the
fold becomes unnecessary and the comparison can assert the real value.

**Status.** `SOURCE-CONFIRMED`.

---

## 12. The fixtures are used in place, and the upstream harness runs where they are

**Condition.** Three multi-megabyte conformance files live in `src/`.
`src/tests.c:131,139,147` opens them by **bare name**, and
`src/Makefile.am:129-131` satisfies that with symlinks into the build directory.

**Symptom.** Copying them into a `testdata/` directory would create a second,
divergent source of truth; symlinking them would create a second path to the
same bytes; running the harness from the package root would simply not find them.

**Cause.** All three options are ways of not fixing the working directory.

**Fix.** `zig build upstream-test` runs upstream's unmodified `src/tests.c` with
`src/` as its **working directory**. No copy, no symlink, no fixture rewriting,
and every fixture byte is upstream's. The Zig tests `@embedFile` the same three
files from `src/` at build time, so there is no `testdata/` directory in this
package at all and nothing is fetched to run the suite. The row counts — 19 338,
1 944 and 766 — are asserted against the counts each file states in its own
footer, which is what makes "the whole file" checkable.

**Bound to.** The working-directory mechanism of `addRunArtifact`. It is not a
substitute for a package that must work when its fixtures are somewhere else,
and it does not apply to a fork whose fixtures are generated.

**Status.** `SOURCE-CONFIRMED` for the file layout and the counts, and
`OBSERVED` for the run: upstream's unmodified `src/tests.c` executed three times
with `src/` as its working directory — the `line`, `word` and `grapheme` steps —
and printed `Passed 19338 out of 19338 (100%)`, `Passed 1944 out of 1944 (100%)`
and `Passed 766 out of 766 (100%)`, in a command that exited 0
(`local://foundation-matrix-libunibreak-current-debug.log`, Debug, native,
2026-10-03). The same three figures appeared earlier in
`local://foundation-matrix-libunibreak-unicode-r5.log`, a command that as a
whole exited 1 for an unrelated reason. This package's own replay of the same
three whole files is three of its fifteen facade tests, and those fifteen passed
in all four native modes.

---

## 13. This tree is three licences and eight files with none

**Condition.** `LICENCE` is Zlib. Three fixtures carry a Unicode notice. Seven
generated tables carry **no** grant at all, only a generation banner. One
`tools/` program carries a different, broader grant in its own text. Five more
`tools/` programs and `tools/test.txt` carry nothing whatsoever.

**Symptom.** Every summary of this tree as "zlib" is wrong in a way an auditor
would notice, and the seven generated tables are seven of the nine compiled
translation units or their includes.

**Cause.** Generated data files are usually emitted without a licence header,
and tools get written without one.

**Fix.** [`NOTICE.md`](NOTICE.md) audits **all 67** blobs at the pin, file by
file, and names the exceptions rather than smoothing them over. The Unicode
terms text the fixtures point at is **fetched and carried verbatim** as
[`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) — the primary text from
`unicode.org`, not licence prose authored here — and installed beside the
archive, because the tables it covers are inside the archive.

What the grant over this fork's **own** files is, is a separate record and a
separate question: see [`FORK-LICENSE.md`](FORK-LICENSE.md) and §24. Matching
upstream's Zlib for the additions does not make the audit above wrong — it keeps
the ten Unicode files and the `tools/` exceptions exactly as they are.

`WordBreakTest.txt`'s notice was an open item in the screen report and is now
closed: all 30 comment lines of all three fixtures were read, the notice is the
same three lines in the same place, and nothing follows it but the legend and
the footer.

**Bound to.** This pin. A new release can move a file between the generated and
hand-written sets, and `UPSTREAM.md`'s synchronisation checklist says to
re-audit all of it.

**Status.** `SOURCE-CONFIRMED`.

---

## 14. `tools/` is carried but is not part of the package

**Condition.** Upstream ships six example programs and a sample text file.

**Symptom.** They are in the checkout and not in `.paths`, which is the state
that looks like a mistake and is not one.

**Cause.** This package neither compiles them nor needs them, and
`tools/linebreak_test.c` reaches outside the standard headers for `<iconv.h>`,
so it is not a portable example of anything.

**Fix.** They are **absent from `.paths`** — a fetched package does not receive
them — and **present and byte-identical in the upstream checkout**, with their
digests recorded in [`NOTICE.md`](NOTICE.md) so a re-sync can still compare
them. They are not deleted, and `UPSTREAM.sha256` names them as a deliberate
exclusion with that reason rather than omitting them silently: a record naming
files a fetched package does not carry would fail in exactly the place it is
meant to be useful.

**Bound to.** The filtered-package decision for this wave.

**Status.** `SOURCE-CONFIRMED`.

**Corrected 2026-10-04, by §27.** The heading above, and the whole delivery half
of this section, describe the package before §27 and are kept as the record of
it. The condition, the cause and the whole reasoning about the six programs are
unchanged, and they still decide what this package compiles. The fix is no
longer the whole answer: `build.zig`'s install step reads `tools/test.txt`, so
`.paths` now carries the directory. A fetched package receives the bytes and
still compiles none of them — the same distinction this section was making,
applied to a file rather than to a directory.

---

## 15. Two different digests describe two different things, and neither is this one

**Condition.** Three SHA-256 values are in play for one pin.

**Symptom.** They are easy to quote interchangeably and none of them substitutes
for another.

**Cause.** They digest different objects.

**Fix.** Each is named for what it is, in [`UPSTREAM.md`](UPSTREAM.md):

* `f9b8ff046faf06a0ca5dd61aeddb430b456aaf4959ef4e91beb48481b5df7408` — the
  driver's measured `git archive` **tar stream** of the whole pin. A whole-tree
  digest.
* `sha256:9c4fad6e…` — the GitHub releases API's digest of the uploaded asset
  `libunibreak-8.0.tar.gz`. An **asset** digest, describing an archive the
  project uploaded, not a git checkout.
* `UPSTREAM.sha256` — **59 per-file digests**, derived from the pinned blobs.
  Check it with `sha256sum -c UPSTREAM.sha256`, which ran here at exit 0 with 59
  `OK` lines (`local://foundation-matrix-libunibreak-provenance-checksums.log`).

**Bound to.** Provenance records in general.

**Status.** `SOURCE-CONFIRMED` for the per-file record; the archive receipt is
the driver's measurement and is reproduced, not re-derived, here.

---

## 16. The selection rests on a missing capability, not on a dependency count

**Condition.** The workspace's ledger admits a fork when shipping complete native
source under our own build serves a missing primitive, with one evidence
standard the screen was asked to meet.

**Symptom.** The screen's evidence for that standard was packaging breadth —
Debian in every suite since bullseye, Gentoo, Fedora rawhide on v8.0, release
download counts — and no demonstrated large-fraction dependency count and no
named dependent.

**Cause.** Different questions. Distribution reach is not the same fact as
dependency breadth, and one is not evidence for the other.

**Fix.** Recorded as **NOT ESTABLISHED** in
[`UPSTREAM.md`](UPSTREAM.md#why-this-library-stated-honestly), with the packaging
evidence attributed to what it actually shows. The disposition rests on the
missing-capability limb instead: the matrix has bidirectional text and no line,
word or grapheme breaking; utf8proc has grapheme breaking only and does not ship
in this workspace; SheenBidi is UAX #9 and computes no break opportunities; and
libunibreak performs no normalization, so it duplicates nothing.

The maintenance cost is stated rather than minimised: one current core
maintainer, a personal GitHub account, and an open merge path (the tag sits on
`master`, and there is no CLA, `CONTRIBUTING` or DCO file at this pin).

**Bound to.** This selection. A library that duplicated something already in the
matrix would fail the need limb regardless of its popularity.

**Status.** `SOURCE-CONFIRMED` for the source overlaps;
**NOT ESTABLISHED** for global dependency breadth, which is stated as such
rather than argued around.

---

## 17. What is verified, what is not, and where each claim lives

**Condition.** Source preparation is this role's job and the gates are the
driver's. Every claim in this package's documentation has to say which of the
two it is.

**Symptom.** These four files originally carried a blanket "nothing has been
built, every gate is NOT RUN", written at a moment when that was true. Left as
it was after the driver ran the gates, the sentence would have become its own
kind of false statement: a claim about the state of the world that no longer
matched it.

**Cause.** A blanket claim is only as good as the moment it was written. What
does not go stale is the rule underneath it: a status is a status, and it names
a receipt.

**Fix.** Every gate that has run is named with its receipt, its optimize mode
and its exit code in the table in
[`README.zig.md`](README.zig.md#verification-status), and nothing else claims a
result. The gates this package makes no claim about are named one by one: the
filtered-fetch consumer and the package integrity gate, which the driver records
outside the package in `local://foundation-matrix-final-package-proof.json`,
where only an observed receipt establishes a pass, and CI. The 53-platform
`cross-test` run is recorded as what it is — `status: partial`,
53 of 53 targets built, 20 ran the test step with 15 tests each (that is the
2026-10-03 wave; §40 records the current cohort's eighteen), 33 `build_only`
for want of a runtime, 0 failed — and is explicitly not a claim that the library
runs everywhere it compiles. Every receipt named above was taken against the
source as it stands. The formatter ran last over the nine fork Zig/ZON files; its
exit code and file list are recorded in the README's table, and no other claim
here is derived from it.
`UPSTREAM.md` and `CHANGELOG.md` carry the same boundary in their own words.

**Bound to.** This wave's receipt set. A later gate changes one row and one
entry, and it changes with a receipt named.

The same boundary governs the receipts that already exist. They were taken on
2026-10-03, against the tree before this migration's shared and runtime-loading
delivery, its pkg-config metadata and its Nix/devenv packaging. They are history,
not proof of anything in this wave: every gate the wave required was listed as
`PENDING-VERIFICATION` in [`README.md`](README.md) §3 when this section was
written, and §3 has since moved several of those rows — each with the receipt
named in it. The rule is unchanged by that: a historical
`23/23 steps succeeded` cannot be quoted as a result for a `-Dlinkage=dynamic`
build that has never been run, and a moved row is moved because a run produced
it, not because a date did.

---

## 18. `set_graphemebreaks` writes one byte *before* the buffer when `len == 0`

**Condition.** The typed `Grapheme` methods were written to leave the caller's
buffer untouched for empty input, on the strength of `Line` and `Word` both
returning before writing anything.

**Symptom.** The promise was false for grapheme breaking, and it failed loudly
rather than quietly: a probe calling `Grapheme.perCodeUnit("", guarded[1..2])`
aborted instead of returning —

```
thread 41214 panic: addition of unsigned offset to 0x7ffc681153e5 overflowed to 0x7ffc681153e4
src/graphemebreak.c:221:27: 0x11ef354 in set_graphemebreaks
```

— and the process exited on signal 6 (Debug, native, 2026-10-03,
`local://foundation-matrix-empty-grapheme-before.log`).

**Cause.** `set_graphemebreaks` has no empty-length guard. It reads the first
character, gets `EOS` back with `posNext` still `0`, and computes
`size_t brksPos = posNext - 1` (`src/graphemebreak.c:212`), which wraps to
`SIZE_MAX`; the GB1 case at `:221` then writes `brks[brksPos]`. At `len == 0`
that index is one byte **before** the caller's buffer. `set_linebreaks`
(`src/linebreak.c:1450-1453`) and `set_wordbreaks`
(`src/wordbreak.c:173,177,463`) both return without writing, which is why the
defect is specific to the grapheme pass and why inferring the behaviour from its
two siblings missed it entirely.

**Fix.** `Grapheme.perCodeUnit`, `perCodeUnit16` and `perCodeUnit32` now return
immediately after validation when the input is empty, so the native call is
never made. The same probe printed `empty grapheme guard: before=inside_char
output=no_break after=inside_char` and exited 0
(`local://foundation-matrix-empty-grapheme-after.log`, same mode and day). This
is not a bounds check standing in for one upstream lacks; it is this package
declining to make a call it knows is out of bounds. **No upstream byte
changed** — `src/graphemebreak.c` still carries no guard and `UPSTREAM.sha256`
still pins its digest — and the hazard is stated plainly on the raw route, where
a C caller inherits it, instead of being quietly patched away upstream.

**Bound to.** This pin's `set_graphemebreaks`. The rule generalises: *a decoder
loop that stores `pos - 1` after its first read is unsafe at length zero*, and a
wrapper promising "empty input writes nothing" has to check each entry point
against its own source rather than infer it from a sibling.

---

## 19. Depending the install step on a `Compile.step` compiles; it does not install

**Condition.** The build wants `zig build` to prove that the example and the
exercise link against the archive and its translated headers, and wants neither
program delivered in `zig-out/bin/`.

**Symptom.** The natural spelling — making the default install step depend on
each program's `Compile.step` — reads like an installation and is not one. No
binary lands in `zig-out/bin/`, so a document that says `zig build` "installs
the example" would be describing a file that does not exist.

**Cause.** `Compile.step` is the compile-and-link step. Installation is
`b.installArtifact` or an `InstallArtifact` step. Depending on the former only
puts that compile under the default graph.

**Fix.** Both programs hang off the default install step's graph as compile
dependencies and are installed by nothing. The receipt is the check: the install
step in `local://foundation-matrix-libunibreak-current-debug.log` lists
`install unibreak`, three `install <file>` steps and one `compile exe
libunibreak-smoke`, and no `install exe` line at all; the earlier
`local://foundation-project-matrix-libunibreak-r1-native-install.log` has the
same shape. `README.zig.md` says "compiles … and installs neither" for the same
reason.

**Bound to.** Any Zig build that wants a compile-time proof without shipping the
binary that produced it.

---

## 20. The consumer step is never stood in for by a host-native build

**Condition.** `consumer/` is a separate package reached by relative path, so
the proof it offers is that a package which did not write this one gets a
working library through `dep.module("libunibreak")` alone.

**Symptom.** Driving a nested `zig build` once per selected target invites a
shortcut for a target that cannot run here.

**Cause.** The shortcut changes what the gate proves. A host-native build, an
install step or an installed prefix standing in for the run turns "this
target's consumer ran" into "something ran", which is the substitution this
workspace forbids everywhere else.

**Fix.** `zig build consumer` drives the separate package in `consumer/` as its
own `zig build run -Dtarget=<triple> -Doptimize=<mode>`, with the harness's
executor flags forwarded, and is never stood in for by a host-native build or an
installed prefix. What a target this host cannot execute gets instead is §39's
subject. Observed for the native target in all four modes: `consumer package
success` (`local://foundation-matrix-libunibreak-unicode-r7.log` and the three
optimized receipts).

**Bound to.** Any consumer gate in this workspace. The executor flags belong to
the outer harness, so a foreign target's verdict stays the harness's to give.

---

## 21. The installed-C program asserted two rules of UAX #14 backwards

**Condition.** The C program in `.github/workflows/verify.yml` that links the
installed archive and checks it against the Unicode rules — the only gate that
exercises the installed bytes rather than a build-tree artifact.

**Symptom.** It exited 1 with two failures, and neither was a defect in the
library:

```
FAIL  [1] LB7 requires a break after the space
FAIL  [0] LB5 requires a break before the newline
2 check(s) failed
```

(2026-10-03, `local://foundation-matrix-libunibreak-installed-c-run-r0.log`.)
Two further lines in the program could not fail at all: an `expect(1)` that
compared a value with itself, and an assertion pinning `unibreak_version` to a
constant.

**Cause.** The oracles were written from memory of the rule numbers rather than
from the rules. LB18 is what *allows* a break after a space, while LB7 governs
what happens *before* one; LB6 is what *forbids* a break before LF, while LB5 is
what makes the break after it mandatory. Each assertion had the right idea and
the wrong side of the position.

**Fix.** After the space the program now asserts `LINEBREAK_ALLOWBREAK` by LB18;
before the newline it asserts `LINEBREAK_NOBREAK` by LB6, with the position
after the newline still asserted as `LINEBREAK_MUSTBREAK`. The self-comparison
and the version pin are gone; the program prints the version instead, because
pinning one is the provenance gate's job and not a C program's. The empty-input
check was narrowed to the **line** function, the one native function that
genuinely returns without writing — the grapheme one does not, and calling it at
`len == 0` is the hazard in entry 18.

**Observed after the fix.** Every check `ok`, then `the installed C surface
compiled, linked and ran`, exit 0
(`local://foundation-matrix-libunibreak-installed-c-run-r1.log`); the compile
step printed nothing and exited 0
(`local://foundation-matrix-libunibreak-installed-c-compile-r1.log`). All five
installed headers were compiled, and the program asserts real values for line
positions 8, 16 and 32, for the per-code-point count, for the pair query, and
for word and grapheme breaking.

**Observed again against the current source.** The current Debug run installed
into `…/libunibreak/install-current` (exit 0,
`local://foundation-matrix-libunibreak-current-debug.log`), and the installed-C
program was then compiled with `-I …/install-current/include` against
`…/install-current/lib/libunibreak.a` and run: compile exit 0 with empty output,
run exit 0 with every check `ok` (`…-installed-c-current-compile.log` and
`…-installed-c-current-run.log`, 2026-10-03). It therefore exercises the bytes
that run installed rather than a build-tree artifact.

**Bound to.** Any gate that encodes rules as literals. A hand-written oracle is
the part most likely to be wrong and the part a failing gate is most likely to
blame on the library, so check the oracle against the specification text before
changing anything underneath it.

---

## 22. A documented example would have been refused at run time

**Condition.** The typed-API example in `README.zig.md` — the first thing a
reader copies.

**Symptom.** It declared `var out: [10]libunibreak.LineOpcode = undefined;` and
then called `Line.perCodeUnit(text, null, &out)` on `"Hello, 世界"`, which is
**thirteen** UTF-8 code units. That call is `error.OutputTooSmall`. The example
published with this package refused its own input, and its comment claimed six
code points where there are nine.

**Cause.** The buffer was sized from an estimate rather than from `text.len`,
and nothing compiled or ran it: it is prose, so no gate could catch it. The rule
it was illustrating — one output entry per input code unit — is the rule the
whole typed API rests on, which is why a wrong size there hides so well.

**Fix.** The buffer is `[13]`; the comment states nine code points and thirteen
code units and names the four units that carry `inside_char` — 7, 8, 10 and 11,
each of which precedes a code point's final unit, rather than being the leading
unit of the next one; and the example now checks the published answer before
printing — `no_break` at index 0, which is the break between `'H'` and `'e'`
that LB28 prohibits between two alphabetic characters, `inside_char` at index 7,
and `indeterminate` at index 12.

**Observed.** The example was extracted from this README, built against this
package and run: `6/6 steps succeeded`, exit 0
(`local://foundation-matrix-libunibreak-all-readme-examples-r1.log`, Debug,
native, 2026-10-03). Its own check passed before it printed indices 0–12, with
`inside_char` at 7, 8, 10 and 11 and `indeterminate` at 12. A prose example is
outside the test gate, and running it is what turns "it looks right" into an
observation.

**Bound to.** This README, and the general rule behind it: a prose example is
outside the test gate, so its own arithmetic has to be as carefully checked as
its code. An example that cannot run teaches a reader a broken call.

---

## 23. A fork's README that is still upstream's README says nothing about the fork

**Condition.** Upstream ships a README. The fork keeps upstream's whole tree and
writes a build graph, a facade, tests, a consumer package, CI and five documents
beside it — and its `README.md` is upstream's file, unchanged.

**Symptom.** Everything a reader needs is in files they are not sent to. The
package's own installation section describes autotools this package never runs;
its licence section names a grant that does not cover seven of the nine compiled
translation units; and it says nothing at all about the Zig module, the typed
facade, the runtime route or the Nix packages, which are the parts the fork
exists. Three separate documents had to cite `README.md:25-26` and
`README.md:28-29` for statements about upstream's licence and upstream's Unicode
terms — citations that silently become wrong the moment the file is rewritten.

**Cause.** A README inherited from upstream is a README nobody on the fork side
has reviewed, and it is also the one file whose provenance is ambiguous: read it
later and there is no way to tell whether it is a copy, a rewrite, or a fork's own
document that happens to agree.

**Fix.** Upstream's README is carried byte-identical as `README.upstream.md`
(2 996 bytes, `cc38c7b8…`, verified in
`local://foundation-contract-upstream-readme-proof.json`) and is recorded by that
digest in `UPSTREAM.sha256`. `README.md` is the fork's, in the order this
workspace fixes: native-source deviations, native-build deviations with a dated
history link, the current matrix, consumption. Every citation of an upstream line
number was repointed at `README.upstream.md` — in `NOTICE.md` and `UPSTREAM.md`
here — so the line numbers still mean what they meant. A caller of `build.zig`
still reads `README.md` at `zig-out/README.md`; it now reads the fork's document,
which is the right file to install beside a fork's library.

**Bound to.** The relocation decision, not the wording. A future upstream
release moves `README.md` again in `git`, and the check that keeps this honest is
the digest in `UPSTREAM.sha256`, not this paragraph.

**Status.** `SOURCE-CONFIRMED` for the bytes and the citations.
`PENDING-VERIFICATION` for `sha256sum -c UPSTREAM.sha256` after the
re-pointing.

---

## 24. "This fork's files assert no licence" was a fact about a moment

**Condition.** The owner authorized a per-project licence for fork-authored
additions, matching the project's primary upstream terms where appropriate.

**Symptom.** Three documents said the fork's own files were *unassigned* — not
because that was a decision, but because nobody had chosen a term yet. Left
alone, that sentence becomes an active falsehood: the tree would ship files under
no stated grant next to a file that grants everything.

**Cause.** Recording the absence of a grant looks like recording a licence
position, and it does not decay on its own. The absence was also the reason the
Zlib "altered sources must be plainly marked" condition could be called vacuous:
with nothing added under a grant, there was nothing to mark.

**Fix.** [`FORK-LICENSE.md`](FORK-LICENSE.md) states one grant over every file the
fork writes — **Zlib**, SPDX `Zlib` — records the authorization behind it, lists
what the grant does **not** reach, and names the SPDX identifier newly authored
files carry. `NOTICE.md` keeps the per-file audit, gains the install paths, and
marks the earlier *unassigned* wording as what it was.

The exception is why this is not bookkeeping. Seven of the nine compiled
translation units, or their textual includes, are generated UCD tables with **no
in-file grant at all**, and three fixtures are Unicode's under its terms. A Zlib
label is a true description of the code and a false description of the shipped
archive, which is the same reason `package.nix` declares
`license = "Zlib AND Unicode-3.0"` rather than `Zlib`.

**Bound to.** This authorization. A package whose primary upstream term changes
re-opens the choice; the file says what the choice was made against.

**Status.** `SOURCE-CONFIRMED` — the grant, the identifier and the file lists are
read out of this tree and the authorization is recorded in `AGENTS.md` §8 and the
wave contract. The SPDX headers in newly authored source and build files are
`PENDING-VERIFICATION`: no gate has looked for them.

---

## 25. A Nix package that compiles the C itself is a second build system

**Condition.** The package needs a static and a shared Nix variant, and the C is
already compiled by `build.zig`.

**Symptom.** The tempting derivation is a list of `.c` files, `stdenv.mkDerivation`
and a `make`-shaped install phase. That is a second, quieter statement about
which sources the library is — and this library is exactly where that statement
is dangerous: six of the tables are **textually included** by a translation unit
rather than compiled, so a source list that names them produces duplicate
definitions, and a source list that omits `linebreakdata.c` fails to link. A Nix
file with a `.c` list would also drift from `build.zig` silently, because nothing
in the build would notice.

**Cause.** Nix packaging defaults to owning the build, and the `.paths`
allowlist in `build.zig.zon` already reads like a second allowlist waiting to
happen.

**Fix.** `package.nix` names no C source and passes no C flag. It runs
`zig build install --prefix "$out" -j… -Dcpu=baseline -Doptimize=… -Dlinkage=…`,
so the translation-unit list, `-std=c99`, `UNIBREAK_LAZY_INCB=0`, the five
installed headers and the include closure stay in the one file that owns them.
Its source filter is an **exclusion** of build and tool state by name —
`.zig-cache`, `zig-out`, `.devenv`, `.direnv`, `result*` and friends — not an
allowlist, precisely so it cannot become the second statement of what the package
contains.

One function, one derivation, one `linkage` argument: the variants belong to the
entry points. `flake.nix` exposes `packages.<system>.static`, `.shared` and a
`.default` that preserves this SDK's static policy; `devenv.nix` exposes the same
derivation as lazy `outputs.static` and `outputs.shared`, so entering the shell
does not build the SDK, and `devenv build outputs.static` is the packaging route.

The derivation installs nothing of its own. `build.zig` writes the library, the
headers, the link metadata, both licence texts and the data under `share/`, so
there is no path with two writers and no licence material whose install depends on
the packaging layer. What the derivation keeps is the check: that a
`libunibreak.pc` exists under `$out`, that the five headers and the library the
variant produced are there, and that the licence texts travel. A package whose
output has a library and no `-lunibreak` is a source drop, so that assertion is
the difference between a package and a tarball.

**Bound to.** This build graph. Any SDK whose C is compiled by `zig build` gets
the same rule; an SDK that *is* an autotools project would be the other case, and
that case is not this one.

**Status.** `PENDING-VERIFICATION`. No derivation has been built and no shell has
been entered. `flake.lock` and `devenv.lock` are the driver's: the first is now
in this tree, 593 bytes written 2026-10-04, pinning nixpkgs at
`c7def046b9a883d46974757852106483d741586f`, and the second is not. §29 says what
that does and does not settle. A lock file is a file; reading it is not running
Nix.

---

## 26. `${…}` inside a Nix indented string is Nix, not the shell

**Condition.** An install phase that wants the core count the sandbox provides:
`-j"${NIX_BUILD_CORES:-1}"`.

**Symptom.** Evaluation fails before any build starts. Nix reads `${` inside
`''…''` and tries to evaluate `NIX_BUILD_CORES:-1` as a Nix expression. Every
shell parameter expansion in an indented string is the same trap.

**Cause.** Nix's indented strings interpolate `${…}`, and `''${` is the escape.
Shell and Nix agree on the spelling and mean different things by it.

**Fix.** Write `-j''${NIX_BUILD_CORES:-1}`, so the shell expands it and Nix does
not see it. In `package.nix` the remaining `${…}` inside indented strings are
deliberate Nix interpolations of derivation attributes, and every shell variable —
`$out`, `$TMPDIR`, `$(dirname …)` — is written without braces for the same reason.

**Bound to.** Every Nix file in this workspace, in every phase string. Observed on
another SDK's canonical devenv evaluation and applied here without an evaluation
of this package's own.

---

## 27. `.paths` did not carry the two files the install step reads

**Condition.** The package publishes through `.paths`, and its install step
installs licence records and upstream's sample input beside the library and its
five headers.

**Symptom.** Not a failure here, which is what made it worth writing down. In
this working tree `zig build install` succeeds, because `FORK-LICENSE.md` and
`tools/test.txt` are both on disk and `b.installFile` resolves them against the
build root. The same install step in a package materialised from `.paths` — a
fetched copy, which is what the driver's filtered-package gate obtains — has no
`FORK-LICENSE.md` and no `tools/` to resolve, and fails naming a file the source
tree has always had.

**Cause.** `.paths` was written to answer "what is this package?", and both paths
were added to `build.zig` afterwards, by two different steps, for two different
obligations: `installLicenceRecords` covers what the fork writes, and the
`tools/test.txt` line covers a data file that belongs in the delivered set.
Neither obligation asked what the manifest carries. A build graph that reads a
file and a manifest allowlist are two lists about one package, and nothing in the
tree makes them agree — so the package is installable in the tree and
uninstallable as a package, which is the one state a package must never be in.

**Fix.** `.paths` names `FORK-LICENSE.md` and the whole `tools` directory. The
directory rather than the single file the install reads: `test.txt` is the sample
input for the six programs beside it, upstream's `Makefile.am:12` distributes the
directory as a unit, and a hand-picked entry out of an upstream directory is the
second, quieter claim about what the library is that the `src` entry already
refuses to make. Nothing compiles any of the six, so no step changes: `core_sources`
names nine translation units and globs nothing, which is the same answer §14 gave
for a different reason.

The two alternatives were both worse. Dropping the `installFile` calls would make
the fetched copy install while quietly shipping a package that installs neither
its own grant nor the sample input its examples read — the failure mode §24 and
§25 describe, reached by deleting the obligation instead of carrying the file.
Naming `tools/test.txt` alone would install, and would separate the sample from
the programs that document how it is used in order to save six small upstream
files no gate reads.

Three statements outside the manifest described a delivery that no longer existed:
two records and one comment. All three are corrected, with this section as the
reason.
`UPSTREAM.sha256` named `tools/ (7 files)` as deliberately absent and now records
all seven, its header stating that they travel because the install step reads
`tools/test.txt`; `NOTICE.md:221-224` said the same in prose and now says
`tools/` travels while the six programs are still compiled by nothing. Both were
right about upstream's bytes and wrong about delivery, and both are now right
about both. The third was not a record file: `build.zig:402-408` said nothing
here builds "or installs" the directory and that it stays "out of the filtered
package closure", and both clauses are now corrected in place — the same
allowlist-versus-build-graph defect, one file over, which is why the rule that
follows from this section is that a comment describing a closure is as binding
as the manifest that defines it.

The record's arithmetic moved with them: its header described 59 records as "the
upstream-owned entries of `.paths`", which now has 66 — 45 in `src/`,
`doc/architecture.md`, the 7 in `tools/` and the 13 named root files — and the
record holds 66. The seven were read from the working tree and compared against
`NOTICE.md`'s table; no new pinned-object comparison was run for them, so the
2026-10-03 figure stays a statement about 59 records.

**Bound to.** Any SDK whose install step reads a path its allowlist
does not name fails the same way, in the same place, and only in a materialised
copy — which is why the check that finds this is a fetch and not a build in the
tree, and why a working-tree-only gate cannot be evidence that a package is
installable.

**Status.** `SOURCE-CONFIRMED` for the two `installFile` calls, the two entries
that were missing, and the three statements that were behind the source and are
now corrected in place.
`PENDING-VERIFICATION` for the filtered fetch: no `zig fetch`, no materialised
copy and no `zig build install` was run for this section. The package's contents
changed, so any hash recorded for it before this section is stale and has to be
re-derived.

---

## 28. Six documented commands named an option no build script declares

**Condition.** The delivery contract records two options: `-Dlinkage`, which says
which artifact is delivered and installed, and one that says whether the facade
reaches the library through a link line or through a table an explicit `load`
fills.

**Symptom.** The second was written as `-Druntime-loading` in six places —
[`README.md`](README.md) §2's option table, §3's pending gate row and §4c;
[`README.zig.md`](README.zig.md)'s option table, the paragraph below it and its
pending gate row; and [`CHANGELOG.md`](CHANGELOG.md) entry 28. `build.zig`
declares the option as `runtime` (its `b.option(bool, "runtime", …)` call in
`build`), and `runConsumer` in `build.zig` forwards `-Druntime=…` into
`consumer/`, so a reader who copied any of the six named an option the build
script does not declare.

**Cause.** The flag was written from the prose name of the feature rather than
from the declaration, in the four documents that describe it and nowhere in the
one file that defines it. Prose and options drift apart silently because nothing
in a Markdown file checks a flag against a build script: the spelling is
correct in every sentence about the feature and wrong in every command that uses
it, and the two are never read in the same place.

**Fix.** Every `-D` spelling of the option is now the declared name, `-Druntime`.
The prose that calls the feature *the runtime-loading route* is untouched, because
it describes the delivery and never claims to be a flag — and correcting it would
have edited accurate sentences to match an inaccurate command.

**Bound to.** Any option whose documentation is prose rather than generated. The
check that catches this class is reading the `b.option` call against the
documented commands once, by hand; nothing in this package does it
automatically, and no gate here can be assumed to.

**Status.** `SOURCE-CONFIRMED` against `build.zig`. Nothing was executed; the
corrected commands are the pending rows, and no gate has run them.

---

## 29. Two status sentences were true when written and are not now

**Condition.** These documents record claims about what has and has not been
observed, and three of those claims were written about a tree that has since
moved.

**Symptom.** [`CHANGELOG.md`](CHANGELOG.md) entry 27 says "no lock file has been
written", and `flake.lock` is in this tree: 593 bytes, written 2026-10-04,
pinning nixpkgs at `c7def046b9a883d46974757852106483d741586f`. Entry 28 says
"there is no `runtime/` directory", and `runtime/` holds six files that
`build.zig` imports (`const runtime_graph = @import("runtime/graph.zig");`) and
`.paths` names. Entry 28 also says `build.zig` hard-codes `.linkage = .static`,
and `build.zig`'s `b.option(std.builtin.LinkMode, "linkage", …)` reads the
option and defaults it to `static`. Left alone, each would read as a claim about
the present rather than about the day it was written.

**Cause.** A status sentence written about a moment does not decay on its own. It
decays when something else in the tree moves, and both things that moved here
moved deliberately: the runtime route landed, and the driver wrote the flake
lock. This is the same shape as §17 and §24 — the sentence was accurate, and
accuracy is not self-renewing.

**Fix.** Both originals stay where they were, and each is corrected next to
itself, with the correction dated; [`CHANGELOG.md`](CHANGELOG.md) entry 32 states
all three. What is deliberately *not* corrected is the part that was never
observed: no derivation has been built, no shell has been entered, and no gate
has observed the runtime route. Reading a lock file is not running Nix, and a
six-file directory existing is not a gate result. The corrected sentences say
what the tree contains and stop there.

**Bound to.** Every status sentence in these documents. The rule is the one §24
already states: a claim about a moment needs its date, and a correction keeps the
dated original in place rather than rewriting it into agreement.

**Status.** `SOURCE-CONFIRMED`, read out of `build.zig`, `build.zig.zon`, and the
lock files in this tree — one present, one absent. No Nix evaluation, build or
gate was run, and no receipt for one is claimed.

---

## 30. A README that advertises `nix build` has to carry the files `nix build` reads

**Condition.** The package has a standalone derivation and a flake, and §5 of
[`README.md`](README.md) gives a reader four commands that use them.

**Symptom.** `.paths` named none of `package.nix`, `flake.nix`, `devenv.nix`,
`devenv.yaml` or `.envrc`. Every route §5 advertises therefore worked in a
checkout and not in the package — the same shape as §27, one step earlier in the
chain: a document a dependent receives describes commands whose inputs it does
not have.

**Cause.** The Nix layer landed as working-tree files, and `.paths` is not a
synonym for "the files I wrote"; it is the list of what leaves this directory.
Nothing in the build asked whether the packaging travelled with it. The flake's
own lock made the omission quieter: a flake without a lock still evaluates, so
nothing failed on the day it was missing — and nothing failed on the day the
driver wrote one either, because `.paths` still did not mention it.

**Fix.** All five entry points are named in `.paths`, together with the
`flake.lock` the driver wrote — a flake without its lock pins nothing, so the
lock is the reproducible half of what was advertised. `devenv.lock` is named
nowhere: it does not exist in this tree, an empty file would be a file this
package does not have, and a `.paths` entry that is not there fails the fetch
that reads it.

The two filtering statements are deliberately kept apart. `package.nix` filters
the sources the sandbox sees and may drop lock files from them once the flake
frontend has resolved the locked inputs; `.paths` is what this package
publishes. Neither is a defect in the other, and reading them as one produces
either a package that omits its own entry points or a derivation that pins
nothing.

**Bound to.** Any package whose README tells a reader to run a command against
files in the tree. The check is one line long: every file a documented command
reads is in `.paths`.

**Status.** `SOURCE-CONFIRMED` — the five entry points and `flake.lock` are in
this tree and `devenv.lock` is not. No `nix`, `devenv`, build, fetch or gate was
run for this section, and no Nix result is claimed.

---

## 31. In UTF-32, `0xFFFFFFFF` is both the end of the input and a value a buffer may hold

**Condition.** The typed facade exposes one decoder answer type, `Decode.Step`,
for three encodings, and a caller walks a buffer by calling `Decode.*` until
`end` is true.

**Symptom.** All three built that answer the same way — compare the returned
value with `EOS`. That is sound for two of them and cannot be for the third: a
UTF-32 buffer may hold `0xFFFFFFFF`, upstream returns such a unit verbatim
(`src/unibreakdef.c:172`), and the facade therefore reported `end = true` with a
zeroed code point for an ordinary stored character. A caller that stops on `end`
stops there, and the rest of the buffer is silently unread.

**Cause.** `EOS` is a value (`src/unibreakdef.h:52`), so "nothing left" was read
off a value that UTF-32 does not keep for itself. The only thing that
distinguishes the two answers upstream is the cursor: `EOS` is returned without
advancing, a stored unit is returned after advancing one
(`src/unibreakdef.c:168-172`). The facade collapsed that distinction before it
reached the answer type, so nothing downstream could recover it.

**Fix.** `Decode.utf32` answers on position — `index == units.len` — and a unit
holding `0xFFFFFFFF` comes back as itself with `end` false, like a surrogate or
any other stored value. UTF-8 and UTF-16 keep the value comparison, and now say
why it is sound for them: `utf8_t` is `unsigned char`
(`src/unibreakbase.h:47`) and a UTF-16 answer is at most `U+10FFFF`, so neither
can return the sentinel as a character. The rule is written where it is
enforced — the `Decode` overview, `Step.index`, `Step.end`, `Decode.utf32` and
the two helpers that build the answer — and pinned by a regression over
`{ 0x0061, 0xFFFFFFFF, 0x0062 }` in `tests.zig` that requires the sentinel
verbatim, the unit behind it still reachable, and the real end of the range to
end the walk without moving the index.

**Bound to.** Any wrapper that decides "end of input" from a returned value. The
general rule: where a sentinel is also a legal value, position is the only thing
that tells them apart, and a facade has to carry the distinction the native call
actually makes.

**Status.** `SOURCE-CONFIRMED` for the rule, its documentation and the
regression, all read out of the tree. `OBSERVED` for the defect and for the
probe's after-state, and for nothing wider: before, the probe swallowed a stored
`0xFFFFFFFF` and reported `end` true for it (`bg7275`); after, it retains the
sentinel's code point with `index` 2 and `end` false, completes the walk at 3,
leaves the UTF-8 and UTF-16 controls unchanged, and still gets four
`MalformedUtf32` refusals (`bg762`). Both receipts are from a scratch consumer
outside the package. The regression added in `tests.zig` has not been run, the
package suite has not been run, and nothing here claims otherwise.

---

## 32. A CI comment named a step that was never registered

**Condition.** `.github/workflows/verify.yml` explains what the
`-Druntime=true` job does and does not prove, and part of that explanation was a
statement about where the loader's own tests run.

**Symptom.** The comment said `build.zig` runs them under a `runtime-test` step.
There is no such step: `build.zig` registers six — `smoke`, `test`, `exercise`,
`upstream-test`, `consumer`, `check` — and the loader's cases are inside `test`.
A comment that names a step nobody registered describes a gate that does not
exist, in the one file whose whole job is to say what a runner will do.

**Cause.** The step list grew during this migration, and the comment was written
against an earlier shape and never re-read. It had also begun to carry a bare
line number, which is what made it rot: a comment inserted above it moved the
number without changing anything it claimed.

**Fix.** The comment names the step by its registration text —
`b.step("test", "Run the facade tests and every API operation")` — which no
comment above it can invalidate, and states what a runner actually does with the
loader cases: a CI runner sets no `LIBUNIBREAK_TEST_PROVIDER`, so those cases
report the missing provider rather than passing, and the job's real content is
that the generated dispatch, the facade and the explicit exercise agree on the
translated types.

**Bound to.** This workflow, and the general rule behind it: in a file that
describes gates, name a step by its registration rather than by its line,
because the registration is the thing that cannot move.

**Status.** `SOURCE-CONFIRMED` for the six registrations and the corrected
comment. CI is **NOT RUN** and no receipt is claimed; nothing here says a runner
has observed anything.

---

## 33. A citation can name the right file and still point at the wrong lines

**Condition.** `runtime/library.zig` documents what makes a provider generated
from a different Unicode revision answer differently on the rows that changed,
and cites where this tree's revisions are written.

**Symptom.** It cited `src/linebreak.h:34` and `src/graphemebreak.h:39`. The
first was one line short of the banner; the second pointed at the grapheme
header's file-header comment, eight lines below where that banner is. The claim
was right and its evidence was not.

**Cause.** The citations were written once and never re-read, and they are the
kind of claim nothing checks: a comment in a header-shaped Zig file that no gate
compiles and no formatter reads. The same wrong pair sat in `zig/root.zig`, in
another role's file, and was corrected there first — which is how this one was
found at all.

**Fix.** Both now name the banner: `src/linebreak.h:33-34` and
`src/graphemebreak.h:31-32`, verified by reading both headers before editing.
Comment-only; no logic moved, nothing is compiled differently, and the claim the
comment supports is unchanged.

**Bound to.** Every `file:line` in a comment. The check is mechanical and cheap —
read the cited line — and this pass turned up four stale citations across three
files, none of which any gate could have caught.

**Status.** `SOURCE-CONFIRMED`, read out of `src/linebreak.h` and
`src/graphemebreak.h`. No build, test, gate or formatter was run.

---

## 34. A task body that trusts its working directory runs in a directory it does not own

**Condition.** The canonical devenv is entered the way the acceptance driver
enters it — `devenv --from path:<this SDK> …` from a scratch *project*
directory — and the SDK's own gates are namespaced tasks.

**Symptom.** Two of the nine gates failed on 2026-10-04 while the same file
parsed and every task name loaded. `sdk:integrity` printed `sha256sum:
UPSTREAM.sha256: No such file or directory`, and `sdk:consumer` printed
`info: initialize build.zig template file with 'zig init'` followed by `error: no
build.zig file found, in the current directory or any parent directories`
(acceptance run `nix-acceptance-20261004T175328Z`, evidence
`nix-acceptance-evidence/20261004T175328Z/libunibreak-devenv-consumer.log:22` and
`…-libunibreak-devenv-integrity.log:20`). Neither error is about this SDK's
build or its digests; both are about the directory the command was standing in.

**Cause.** devenv materialises a task as a generated program that inherits the
**caller's** working directory, and `--from path:<SDK>` hands that program the
project directory devenv created beside the SDK — one holding no `build.zig`, no
`UPSTREAM.sha256` and no `consumer/`. `$DEVENV_ROOT` names that same project, so
the obvious repair — `cd "$DEVENV_ROOT"` — is the defect restated. A per-task
`cwd` option would not reach the generated program either; only the body can
move itself.

**Fix.** One binding, used as the first line of every exec body:
`sdkRoot = builtins.toString ./.`, rendered through `lib.escapeShellArg`.
`builtins.toString` rather than an interpolated `${./.}`: the interpolated form
asks Nix for a **store copy of this whole tree**, which is read-only and is not
the working tree `sha256sum -c` describes. `escapeShellArg` is this workspace's
quoting convention (`htscodecs/package.nix` uses it), so a checkout path holding
a space is still one argument. The `cd` carries `|| exit 1`, because a body that
continued past a failed `cd` would check whatever directory it was left in.

The half of the repair that is not a directory matters as much. `zig build
install`'s default prefix is `zig-out` beside the build root, which here is the
checkout on the volume the driver digests before and after a run, so the two
bodies that install — `sdk:build` and the aggregate `sdk:gate` — now pass
`--prefix` themselves: `$LIBUNIBREAK_INSTALL_PREFIX` if the caller exported one,
else `$ZIG_LOCAL_CACHE_DIR/libunibreak-install`, else `$XDG_CACHE_HOME/…`, else
`$TMPDIR/…`, and an exit that names the missing variable when none of the four is
set. The other five tasks install nothing — `build.zig` hangs the example's and
the exercise's compile steps under the install step (its two
`b.getInstallStep().dependOn` calls), never the reverse — so they name no prefix,
and `test`, `smoke`, `check`, `upstream-test` and `consumer` keep their existing
commands and defaults.
`"$@"` reaches `zig build` on every body that invokes it, so a caller's
`-Doptimize=`, `-j8` or `--summary all` still wins over anything this file names.

Nothing about the proof changed. `sdk:consumer` still runs `zig build consumer`,
which runs the separate `consumer/` package as its own `zig build run`, and
`runConsumer` in `build.zig` forwards the selected target, the selected CPU, the
optimize mode, the linkage and the runtime route to it. It is reached through
this build graph rather than by `cd consumer` precisely so those selections stay
in the proof.
`sdk:integrity` still runs `sha256sum -c UPSTREAM.sha256` over all 66 records —
the 59 pinned upstream blobs and the seven `tools/` files — and narrowing it to
the paths that happen to exist would be a weaker gate wearing the same name.

**Bound to.** Any SDK whose canonical devenv is entered from a scratch project:
the shell's `cwd` is the caller's, not the module's. The prefix half is bound to
a checkout on a shared volume, where an install that lands in the working tree
is a delivery artefact in the tree the driver compares.

**Status.** `SOURCE-CONFIRMED` and `PENDING-VERIFICATION`. The two failure
receipts above are observed; the repair is read out of `devenv.nix` and has not
been run. Every gate in [`README.zig.md`](README.zig.md)'s pending table, and
`nix build .#static` / `.#shared`, still belongs to the driver.

---

## 35. A record of what a package installs under-reports by exactly the length of a loop

**Condition.** A licence record states what a recipient of an installed output
receives. In this SDK the recipient's files are produced by `build.zig`'s install
step, and that step puts its licence records in one directory from two places:
three `b.installFile` calls naming a destination each, and one call into a
helper that loops over a list.

**Symptom.** `NOTICE.md`'s installed-material table named three records under
`share/licenses/libunibreak/` — `NOTICE.md`, `FORK-LICENSE.md` and
`UPSTREAM.md`. `build.zig` also calls its `installLicenceRecords`, whose loop
writes `LICENCE`, `LICENCE-UNICODE.txt`, `AUTHORS`, `README.upstream.md`,
`FORK-NOTES.md` and `UPSTREAM.sha256` into that same directory from its
`licence_records` list. An installed output carried nine records; the table
described three, which is a directory no recipient receives. `build.zig`'s own
module comment (its installed-material list) named all nine, so the audit and
the build graph disagreed with each other inside one package.

Two smaller gaps sat in the same table. `libunibreak.pc` was placed "under
`$out`", where `build.zig`'s `addPkgConfig` writes `lib/pkgconfig/libunibreak.pc`
(its `addInstallFileWithDir` call) — the derivation goes looking for it with
`find` (`package.nix:94`) rather than assuming a directory, which is what made
the imprecision survivable. `$out/include/*.h` named no header, and "or the
shared library" named no file, although the header list is upstream's own
(`src/Makefile.am:1-6`) and the platform names are fixed by `build.zig`'s own
installed-material comment.

The same under-inclusion stood in `FORK-LICENSE.md`'s own "Where licence material
is installed" table, which listed the same three records and carried the same
"`libunibreak.pc` under `$out`": one fact, recorded twice, short by the same six
both times. A third statement was short by one rather than six —
`NOTICE.md`'s exclusion list named three files in this tree that are not this
fork's, and `AUTHORS` is a fourth, pinned as an upstream blob at
`UPSTREAM.sha256:64` and drawn on by the four copyright lines near the top of
that audit.

**Cause.** Counting install calls is not counting installed records. A helper
that loops over a list is one call and *N* records, so an audit written from the
call sites alone under-reports by exactly the loop's length — six here — while
reading correctly at every line and looking complete. Nothing failed: the build
installs all nine, the build graph's own comment already says so, and
`package.nix`'s install check (`package.nix:120-124`) passes on the five paths
it names. An incomplete audit is not a build failure. It is a record that
under-describes a correct build, which is worse for the person it exists to
serve, because they will trust it.

**Fix.** State the directory's contents rather than the call that fills it: nine
records, each with the line that puts it there, plus the note that three of them
also install at the prefix root from the same `b.installFile` call — so the
licence directory is the complete set, not merely the only place to look. Byte
counts and digests were added for the four records whose bytes do not move, and
withheld for the five this fork writes. That asymmetry is deliberate: `LICENCE`,
`LICENCE-UNICODE.txt`, `AUTHORS` and `README.upstream.md` are unchanged bytes
that `UPSTREAM.sha256` already names — three as pinned upstream blobs,
`LICENCE-UNICODE.txt` in that file's header comment — so a size beside them is
redundant checking; this fork's own five documents are edited by the very work
that documents them, and a size written inside `NOTICE.md` — a file that installs
itself — would be true of the moment it was written and of no later one.

`FORK-LICENSE.md`'s table was completed the same way, and `NOTICE.md`'s exclusion
list now names `AUTHORS` as the fourth file the fork's grant does not reach.
Neither edit added an assertion: the first completed a list that already claimed
to be the install layout, the second completed a list that already claimed to
enumerate what is not the fork's. No grant text, licence text or upstream byte
moved.

**Bound to.** Any package whose licence or provenance record states what is
installed, in any SDK. The shape is common: one helper, one list, *N* records,
and a document that reads the call sites. The test is whether the record can be
produced by reading the call sites alone; when it cannot, it is a description of
calls wearing the title of a description of contents.

**Status.** `SOURCE-CONFIRMED` and `PENDING-VERIFICATION`. Every path, line
number and digest above was read out of `build.zig`, `package.nix`,
`UPSTREAM.sha256`, `src/Makefile.am` and the four files they name, in this
working tree; the four digests were computed with `sha256sum` over those files
and agree with what `UPSTREAM.sha256` records for them — three among that file's
66 checkable records, and `LICENCE-UNICODE.txt`'s in the header comment (`:40`),
since it is not an upstream file. That is a reading of four files, not the
package's integrity gate: no build, install, formatter or Nix step was run to
produce this entry, so nothing here is a gate result.
`sha256sum -c UPSTREAM.sha256` over all 66 records, `zig build install --prefix`
and `package.nix` all still belong to the driver.

---

## 36. A canonical build with no flags named is a command whose meaning is the machine's

**Condition.** The canonical entry points for this SDK are the eight tasks in
`devenv.nix`. Each body ends in a `zig build` invocation, and everything a build
runner cannot be told from outside — how many jobs, what summary, where the
cache — falls back to a default. Two of those defaults are inside this checkout.

**Symptom.** Twelve of those invocations named none of the three flags this
workspace's recipe names: one in each of `sdk:build`, `sdk:test`, `sdk:smoke`,
`sdk:upstream-test`, `sdk:consumer` and `sdk:check`, and all six in the aggregate
`sdk:gate` (`devenv.nix:175`, `:184`, `:192`, `:200`, `:213`, `:221`, `:246-251`).
No `--cache-dir`, no `-j`, no `--summary`. Nothing about them failed, which is
what made this survivable: each build succeeded, ran the same steps and produced
the same artifacts, and a gate read only for its exit status cannot tell an
eight-way build from a one-way one, or a cached step from a cold one.

The cache was the sharper half, because it is the one with a default *inside the
tree*. `zig build`'s local cache default is `.zig-cache` beside the build root,
and the build root here is this checkout — the directory the driver digests
before and after every run. Meanwhile `choosePrefix` could resolve to
`$TMPDIR/libunibreak-install` while no cache variable was exported anywhere, so
the one thing this file had already thought about — where a delivery tree lands
— was resolved against a cache that nothing had named.

**Cause.** `"$@"` forwarding was written as the whole argument story, and it is
the half that has to be kept: a caller naming `-Doptimize=ReleaseSafe`,
`-Dlinkage=` or `--summary all` must reach the build runner. But a forwarding
tail says nothing about the flags in front of it, so a body with no fixed flag
has an argument list whose job count is the host's core count. Two related
mistakes sit next to it. One is assuming a default is harmless because it is a
default — `.zig-cache` is a default, and it is a write into the working tree.
The other is assuming the shell hook is where environment defaults belong:
`devenv tasks run` materialises a task as a generated program and never runs
`enterShell`, so a fill that lived there would leave every task calling
`sdk:gate` building in `.zig-cache` under a caller that exported nothing.
Note what is *not* the cause: this file never named `NIX_BUILD_CORES`. The
portable-looking `-j"${NIX_BUILD_CORES:-8}"` is a default, not a count — it is 8
only while that variable is unset — so a "fixed" flag that reads a variable is
this same defect wearing a default.

**Fix.** Each of the twelve writes `--cache-dir`, `-j8` and `--summary all`
before `"$@"`; `devenv.nix`'s `cacheDir` holds the one cache path they share,
this SDK's own directory under the caller's local cache. Placement matters as
much as the flags: they go in front, never after, so the forwarding tail stays
last and a caller's own `--cache-dir`, `-j` or step still reaches the runner in
the position that lets it. The literal `8` matters for the same reason the
literal cache path does.

The preamble each body runs first (`devenv.nix`'s `chooseCaches`) is the other
half: a `ZIG_LOCAL_CACHE_DIR` or `ZIG_GLOBAL_CACHE_DIR` the caller exported is
used exactly as it is and never overwritten, only a missing one is filled — from
`$XDG_CACHE_HOME`, then `$TMPDIR`, both locations the caller exported — and with
none of the three available the body names what is missing and exits before any
compiler runs. The global cache falls back last to the local cache root, which
is known by then, so a caller who exported only the local one still gets an
external global cache without this file inventing a location.

Running the fill before the prefix lookup also repaired a documented behaviour
that was quietly conditional: `devenv.nix`'s `choosePrefix` still
resolves `LIBUNIBREAK_INSTALL_PREFIX`, then `ZIG_LOCAL_CACHE_DIR`, then
`$XDG_CACHE_HOME`, then `$TMPDIR`, and still refuses when none is set — but by
the time it runs, `ZIG_LOCAL_CACHE_DIR` is always set, so its second branch is
the one every installing body takes and a delivery tree always sits beside the
cache that build used.

Nothing else moved. Only the two installing bodies pass `--prefix`, and they
still may: `build.zig` hangs the example's and the exercise's compile steps
under the install step and never the reverse (its two
`b.getInstallStep().dependOn` calls), and the consumer's `run` step is
independent of its own install step (`consumer/build.zig`'s `installArtifact` and
`run` steps). Every body still changes into this SDK's own directory first, the
step names and linkage defaults are untouched, and
`sdk:integrity` still checks all 66 records.

**Bound to.** Any canonical shell entry point whose command line is partly
caller-supplied. Three separate obligations meet in one body: forwarding
`"$@"` proves a caller's flags arrive; the fixed flags before it make the
command mean the same thing on every host; and the preamble makes every path
that command writes to one the caller named. A body that meets two of the three
looks finished.

**Status.** `SOURCE-CONFIRMED` and `PENDING-VERIFICATION`. The lines and the
flag placement were read out of `devenv.nix`, `build.zig` and
`consumer/build.zig` in this working tree. No devenv, Nix, build, test or
formatter was run to produce this entry, so no claim here is a gate result:
`sdk:gate`, the six individual tasks and the packaged outputs remain the
driver's to run and to record.

---

## 37. The nested consumer build was told where to write, and the documents said it was not

**Condition.** `zig build consumer` is not a run. It is a `Step.Run` that starts a
second `zig build` in `consumer/`, and that second build resolves three paths the
first one was already told about: where it puts its own cache, where it finds the
packages it shares, and where an install lands. This package's §34 and §36 already
insisted that nothing may fall back to a default inside a working tree — the
devenv bodies fill `ZIG_LOCAL_CACHE_DIR` and pass `--prefix` for exactly that
reason. `runConsumer` had the same obligation and was the one place it was not
met.

**Symptom.** Three separate gaps, all of them invisible on a passing run.

* **The install prefix was not carried at all.** `runConsumer` forwarded the
  target, the CPU, the optimize mode, the linkage, the runtime route, the
  executor flags, both caches, `-j8`, `--summary all` and the caller's arguments —
  and no prefix. So `zig build consumer --prefix <scratch>/libunibreak/install`
  installed the consumer under the nested build's own default, which is
  `<its build root>/zig-out`, and the caller's chosen prefix received nothing.
  The step does not install, so this was never a claim about the library's own
  install layout; it was the consumer's delivery going somewhere other than where
  the caller named.
* **Every `build.zig` line citation in these documents was stale.** §28, §29, §34,
  §35 and §36 quoted line numbers for the `runtime` option, the `linkage` option,
  the example and exercise install hooks, the licence-record helper,
  `addPkgConfig` and `runConsumer` itself. Every one had moved, twice — once when
  the runtime route and the pkg-config metadata landed, and again with the prefix
  relay below. `README.md` §5 and `README.zig.md`'s `tools/` row carried the same
  stale pairs. A citation that names the right file and points at the wrong lines
  is still wrong, and nothing here checks one.
* **The two consuming documents described four forwarded arguments.**
  `README.md` §5 and `README.zig.md` said the nested build receives the selected
  target, optimize mode, linkage and runtime route. `runConsumer` forwards those
  four plus the CPU, the executor flags, both caches, `-j8`, `--summary all` and
  the caller's arguments, so a reader planning a `consumer` run from either
  document had no statement of the cache or the width the run would use.

**Cause.** A helper that grew one forwarding argument at a time has no statement
of what the whole command line is supposed to contain, so each addition looks
complete on its own and nothing checks the set. The `--prefix` gap is the sharp
end of the same shape `devenv.nix` already had (§36): a caller-supplied decision
that a body silently replaces with a default. The stale citations are §33's
defect at a larger scale — a `file:line` written once and never re-read, in the
one class of claim nothing in this workspace checks automatically.

**Fix.** `runConsumer` now emits `--prefix` when, and only when,
`b.install_prefix` differs from `b.build_root.join("zig-out")`, which is the
nested build's own default. A relative prefix is made absolute against
`b.graph.cache.cwd` first, because the nested build's working directory is
`consumer/` and a relative path handed to it would resolve somewhere else. It
sits after `--global-cache-dir` and before the `--` handover, so it cannot be
mistaken for a program argument. There was no prior `--prefix` in the file, so
nothing is duplicated and no existing argument moved. A dependency's install
prefix is chosen by the build system and by neither caller, so this relay is the
whole of what a nested build can be told about it.

The documentation half is a symbol reference rather than a number. `runConsumer`,
`installLicenceRecords`, `licence_records`, `addPkgConfig` and the two
`b.getInstallStep().dependOn` calls are named where they are meant, in
`README.md` §5, `README.zig.md`'s `consumer` step row and its consumer section,
and in §28, §29, §34, §35 and §36 here. `README.zig.md`'s consumer section and
`README.md` §5 now state what the nested build actually receives — selections,
executor flags, both caches, `-j8`, `--summary all`, the outer prefix, and the
caller's arguments on both hops — instead of "the selected target, optimize
mode, linkage and runtime route". Nothing else moved: no step name, no default,
no option and no upstream byte changed, and the two caches keep the subdirectory
asymmetry they always had.

**Bound to.** Any build graph that shells out to a nested `zig build`. Three
obligations meet in one command line, and missing any one of them is invisible on
a passing run: the nested build's caches must be named, its width and summary
must be fixed, and its install prefix must be the outer one. A prefix relay
needs the comparison against the nested default and an absolutising step, or it
relays a path that means something else. This section is also bound to this
workspace's rule that citations name symbols: a line number in a document that
describes a build graph under active change is a claim with no checker.

**Status.** `SOURCE-CONFIRMED`. Every flag, field name and comparison above was
read out of `build.zig` and `consumer/build.zig` in this working tree after the
relay landed. Nothing was executed here: no build, test, compiler, Nix, devenv,
formatter or linter ran for this section. The nested consumer build is covered
by the bounded observation below; the rest of the gate rows in
[`README.md`](README.md) §3 and [`README.zig.md`](README.zig.md) are unchanged in
status and the driver owns them.

**Bounded observation, 2026-10-04.** Nested delivery-proof run
`20261004T220323250122Z-515d06adcbbf` recorded **9/9 PASS** over
`zig build consumer` and the `consumer/` package, and that run bears directly on
three of the claims above. All four delivery routes ran — static and dynamic,
each linked and each runtime-loaded — each with the selections omitted and each
with `target`, backend, `linkage`, `runtime`, both caches and the prefix named
explicitly. The nested prefix relay's actual command line and the installed
inventory agree, so the relay reaches the nested build. The loaded routes
reached their provider through `--provider` on argv with every provider
environment variable absent, so the program reads that argument and nothing else
and there is no second handoff to be ambiguous with. The same run without a
provider exited 1 with the refusal, so an absent provider is refused rather than
resolved another way.

That is nine cases of the nested consumer build and nothing wider. It does not
move the `zig build test smoke consumer upstream-test` row, the six baseline
targets, the 53-platform matrix, the filtered-fetch consumer, the packaged Nix
outputs or the devenv tasks, and it says nothing about any cache-fallback guard.
Every remaining row in those two tables stays `PENDING-VERIFICATION`.

---

## 38. Two provider observations of different widths are not two confirmations of one thing

**Condition.** `-Druntime=true` resolves nineteen names, validates three
behaviours and then calls through the table. `runtime/library.zig:106-137` says
that resolving symbols and translating a header is not proof of provider
compatibility, and `:85-89` names the Unicode revision as a build-time fact of the
provider's own tree that no load-time call can observe.

**Symptom.** The external-acceptance probe (`20261004T232439Z`) reports `pass` for
an external image, and the loaded-final run (`20261004T233121760876Z-12541`)
reports 8 of 8 cells failing three conformance cases. Both are true. The first
asked whether two images answer a handful of named rules and refuse five refusals,
on one target, one linkage and one mode. The second asked whether an image
survives eight configurations and the whole suite, and it did not. The space
between the two results is exactly the three fixtures.

**Fix.** Run the same cells against this tree's own image as well
(`20261004T232823091897Z-23133`: 8 of 8, 20/20, exit 0), so the comparison has a
control, and state the boundary instead of resolving it. Same source, same
fixtures, same loader, and the same install inventory digest in both runs; what
differs is the image's Unicode revision, which no load-time call here can observe.
Nothing is re-run, no fixture is relaxed, and no loader, ABI or source change is
made, because no observed cause would justify one.

**Bound to.** Any claim about a provider this SDK did not build. The narrow probe is
evidence for the routes and rules it exercised, on the one configuration it used;
it is not evidence for the other seven. The loader controls this SDK *does* have —
the nameless-request refusal and the unopenable-provider retry, `tests.zig:130` and
`:141` — ran in both runs and passed, and the missing-symbol case is absent by
design rather than skipped, since `runtime/graph.zig:83-112` requires all nineteen
names and `provider_optional`/`provider_excluded` are empty.

---

## 39. The consumer sub-command is a question, and "is this host native" cannot answer it

**Condition.** `zig build consumer` starts a second `zig build` in `consumer/`, and
that build has two honest sub-commands: `run` and `install`.

**Symptom.** `runConsumer` asked for `run` whatever the target was. On a target
this host cannot execute, the nested `Run` step fails and takes the whole
`consumer` step with it; on a target reachable only through an executor the build
runner was never told to use, nothing fails and the answer is wrong the other way.

**Cause.** The question being answered was "did the binary run here", and the
sub-command is really "what can this host execute". `Target.Query.isNative()` is
the wrong instrument for it: it needs `cpu_arch`, `os_tag` and `abi` all null, so
`-Dtarget=x86_64-linux-gnu` was never native on an x86_64 Linux host, and it says
nothing about QEMU, Wasmtime or Wine.

**Fix.** Ask `std.zig.system.getExternalExecutor` about the resolved target — the
predicate `std.Build.Step.Run` itself asks about the artifact it is about to
spawn — carrying each `allow_*` from this build's own executor switches, so the
chooser and the nested run read the same facts and cannot disagree. `run` for
`.native`, `.rosetta`, `.wine`, `.wasmtime` and `.darling`; `install` for
`.bad_dl`, `.bad_os_or_cpu`, and a `.qemu` answer for a cross GNU-libc target that
was given no `--libc-runtimes` directory, because `Run` fails that case rather
than skipping it. Nothing else about the nested command line moved.

**Bound to.** Any build step that chooses between running a nested program and
building it. An install is compile evidence and nothing more, so a chosen
`install` must never be reported as a consumer exchange and a foreign cell stays
`INSTALL_ONLY`. The chooser reads switches rather than probing `PATH`, so it is
silent about whether the named program exists; that is the harness's fact, not
this graph's.

**Status.** `SOURCE-CONFIRMED`, and unexercised at the foreign end. Every field,
comparison and line cited above was read out of the pinned compiler's `lib/std`
and out of `build.zig` and `consumer/build.zig` in this working tree. Nothing was
executed here — no build, test, compiler, Nix, devenv, formatter or linter — and
no foreign `consumer` cell has been observed since the change. For a same-OS,
same-CPU target the predicate answers `run`, which is the sub-command the step
already asked for; the driver owns every row that would show otherwise.

---

## 40. A green exit code over twenty tests is not twenty tests, and two of them cannot run on the linked route

**Condition.** `tests.zig` is a twenty-case suite, and two of those cases —
`tests.zig:131` and `tests.zig:142`, the nameless-request refusal and the
unopenable-provider retry that §38 names — open with
`if (!libunibreak.runtime_loaded) return error.SkipZigTest;`.
`-Druntime=true` is the only thing that makes `runtime_loaded` true.

**Symptom.** The native wave `20261004T233628757747Z-69351` recorded eight cells,
each with exit 0, and each with `status: "skipped-tests"` rather than `pass`,
each printing `Build Summary: 31/31 steps succeeded; 18/20 tests passed
(2 skipped)` and naming its own two skip sites. Read by exit code that is eight
passes; read by the denominator it is twenty tests. Both readings are wrong: it
is eighteen, and the two missing cases are not slow, not filtered and not
failing — they are code a linked cell never reaches.

**Cause.** The suite's size is a property of the route, not a property of the
package, and a build summary reports whichever size it got. The driver already
answers this: a cell whose suite lost cases is `skipped-tests`, never `pass`. The
gap is on the writing side, where the memorable figure in a green line is the
exit code.

**Fix.** Record the native route as **eight cells, all partial, 18 of 20**, name
`tests.zig:131` and `:142` and the guard that skips them, and say that 18 is the
ceiling on that route rather than a shortfall. Do not describe the wave as eight
passes and do not "fix" the two skips — `tests.zig` is right to skip a loader
case when nothing was loaded, and the loaded wave is where those two run:
`20261004T232823091897Z-23133`, 8 of 8 at `32/32 steps; 20/20 tests`.
[`CHANGELOG.md`](CHANGELOG.md) §45's twenty and this wave's eighteen are the same
suite on two routes, not two regressions.

**Bound to.** The rows that quote either wave. It reaches further than it looks:
the 53-target cohort `20261004T221720228710Z-45046` recorded `raw_run_tests: 18`
on each of its 20 runtime cells, so "20 runtime PASS" there means twenty cells
eighteen tests each and never twenty times twenty. The same rule retires the
baseline row `baseline-libunibreak-check` of epoch `20261005T014547Z-797a73f2`,
which is a compile-only whole-graph `check` carrying `runtime_pass_claimed:
false` under its exit 0 — a green row that never ran a program is not a short
test run, it is no test run.

**Status.** `OBSERVED`, on receipts rather than on a reading. `20261004T233628757747Z-69351`
(eight cells, all `skipped-tests`), `20261004T232823091897Z-23133` (8/8, 20/20),
`20261004T233121760876Z-12541` (0/8, 17/20),
`20261004T221720228710Z-45046` / `libunibreak-53-target-8.json` (20 runtime PASS,
33 `build_only`, 0 fail) and `20261005T014547Z-797a73f2` / `baseline-libunibreak-check`.
Nothing was built, tested, compiled or linted while writing this section; the
counts are quoted, not reproduced. The authoritative rows are
[`README.md`](README.md) §3 and [`README.zig.md`](README.zig.md)'s Verification
status, and §38 still owns the provider boundary that this section does not
repeat.



