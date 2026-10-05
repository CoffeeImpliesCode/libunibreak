# UPSTREAM.md — what this fork is a fork of

## Upstream

| | |
|---|---|
| Project | libunibreak, an implementation of the Unicode line breaking (UAX #14), word breaking and grapheme cluster breaking (UAX #29) algorithms in C |
| Canonical repository | `https://github.com/adah1972/libunibreak.git` |
| Pinned ref | tag `libunibreak_8_0` — a **lightweight** tag, no tag object |
| Pinned commit | `28a2756b864c343f438cd22537d49d394d4666a5` |
| Version of the C library built here | `8.0` |
| Library licence | zlib/libpng, in `LICENCE` (note the British spelling) |
| Generated-data and fixture terms | the Unicode terms named by the files themselves — see [Unicode data terms](#unicode-data-terms) |
| Copyright | Wu Yongwei, Tom Hacohen, Petr Filipsky, Andreas Röver (four undated lines in `LICENCE`; per-file years vary) |
| Unicode revision of the data | 17.0.0 — UAX #14 Revision 55, UAX #29 Revision 47 |

Where each of those comes from, read out of the carried tree:

* The version is `configure.ac:2`, `AC_INIT([libunibreak],[8.0],[wuyongwei@gmail.com])`,
  and `src/unibreakbase.h:42`, `#define UNIBREAK_VERSION 0x0800`, which is what the
  library exports as `extern const int unibreak_version` (`src/unibreakbase.c`).
  `libunibreak.pc.in:9` fills its `Version:` field from the same `@VERSION@`.
  That is the version of the C library, not a version of the Zig wrapper, and it
  is what `build.zig.zon` carries in `.version`.
* The licence is `LICENCE`, 1 045 bytes: the zlib/libpng text with **four
  undated** copyright lines — Wu Yongwei, Tom Hacohen, Petr Filipsky and
  Andreas RM-CM-6ver (the last is upstream's own `Röver` in `.mailmap`
  transliteration). `README.upstream.md:25-26` — upstream's own README, carried
  here byte-identical — names the same licence and points at that file. This
  fork does not restate the grant and does not paraphrase it; the text ships
  verbatim.
* `README.upstream.md:28-29` states in prose that "part of the code is derived
  from the Unicode Public Data, and the Unicode Terms of Use may apply". That
  prose names no file. The machine-readable assignment used here is per-file and
  comes from the files themselves: the three fixtures carry the Unicode notice
  in their own first lines, the seven generated tables carry only a generation
  banner, and three headers carry a pointer. See
  [Unicode data terms](#unicode-data-terms).
* The Unicode revision is claimed in the headers themselves:
  `src/linebreak.h:33-34` ("Revision 55, for Unicode 17.0.0"),
  `src/wordbreak.h:34-35` and `src/graphemebreak.h:31-32` ("Revision 47, for
  Unicode 17.0.0"). `src/NEWS:1-14` agrees for 8.0, and every generated table
  names a `-17.0.0.txt` input in its own first lines.
* `AUTHORS` names Wu Yongwei as "Current maintainer of libunibreak" and lists the
  others by contribution.

**Tag signature: not verified.** No signing key was consulted and no signature
check was run. The screen report records that the GitHub API reported
`verification.verified: false, reason: unsigned` for this commit; that is a
property of the API's answer, not an observation made from this clone.

## Archive receipt

The workspace delivery record `local://foundation-project-matrix-source-pins.json`
records a measured SHA-256 of the deterministic `git archive` tar stream of the
**whole tree** at that commit. For this library it reads, verbatim:

```
f9b8ff046faf06a0ca5dd61aeddb430b456aaf4959ef4e91beb48481b5df7408  -
```

The trailing `-` is `sha256sum`'s name for standard input: the digest is of the
archive stream as it was piped past the hasher, not of any file in this
repository. The driver measured it when the pin was recorded; this role did not
compute it.

**Two different digests, and they describe different things.** The screen report
read `sha256:9c4fad6e517338a098373acc9f35579ae2c325e6446666fb9ac2666ba15ceba4`
from the GitHub releases API for the asset `libunibreak-8.0.tar.gz`. That is the
digest of a **release asset**, an archive the project uploaded, not of a git
checkout. Neither digest is interchangeable with the other and neither is
interchangeable with [`UPSTREAM.sha256`](UPSTREAM.sha256), which is per-file.

To reproduce the archive receipt:

```
git -C <clone> archive --format=tar 28a2756b864c343f438cd22537d49d394d4666a5 | sha256sum
```

The output must read `f9b8ff046faf06a0ca5dd61aeddb430b456aaf4959ef4e91beb48481b5df7408  -`.
That command has **not** been run in this workspace; the value above is the
driver's.

## Import mechanism

A full clone of the canonical repository, so upstream's Git history is present.
The remote is named `upstream` and the working branch is `main`; there is no
`origin` in this clone. This fork adds no patch series on top of that history:
the Zig package is a set of new files in new regions, and the one upstream file
that is edited at all is `.gitignore`, which gains an appended block of Zig
ignore entries (see [`NOTICE.md`](NOTICE.md)).

The pinned commit is `28a2756b…` and the tag `libunibreak_8_0` points at it; the
checkout is at that commit with no tracked-file modification. The pinned tree
holds **67 blobs**: the 66 this package ships, and `.gitignore`.
here and nothing in this fork's records depends on it.)

## What this fork is

A Zig package that compiles upstream's own C library from `src/` in this
repository and publishes a Zig facade over the five public headers translated by
`addTranslateC`. Nothing of the breaking algorithm is reimplemented, re-derived
or reconfigured: no table is regenerated, no upstream source is patched, and
nothing is downloaded at build time. `NOTICE.md` lists every file this fork adds
or edits.

### What is compiled, and with which switches

Nine translation units, from `src/Makefile.am:11-20`
(`libunibreak_la_SOURCES`) — that list is authoritative:

| Translation unit | Lines | What it contributes |
|---|---|---|
| `src/unibreakbase.c` | 40 | the UTF typedefs and `unibreak_version` |
| `src/unibreakdef.c` | 176 | `EOS`, `ub_get_next_char_utf8/16/32`, `ub_bsearch` |
| `src/linebreak.c` | 1 667 | UAX #14 line breaking; textually includes `linebreakauxdata.c` |
| `src/linebreakdata.c` | 8 988 | the generated Line_Break tables — **its own translation unit** |
| `src/linebreakdef.c` | 128 | the six per-language tailoring tables |
| `src/eastasianwidthdef.c` | 44 | East_Asian_Width lookup; textually includes `eastasianwidthdata.c` |
| `src/emojidef.c` | 47 | Extended_Pictographic lookup; textually includes `emojidata.c` |
| `src/graphemebreak.c` | 375 | UAX #29 grapheme breaking; textually includes two data files |
| `src/wordbreak.c` | 525 | UAX #29 word breaking; textually includes `wordbreakdata.c` |

The list is deliberately written out rather than globbed: a glob would let a unit
be added to or dropped from the archive without a decision, and this tree is
exactly the kind where that mistake is invisible until a link fails.

**The one thing that is easiest to get wrong here.** There are seven generated
data files. Six are `static` and textually `#include`d into a core unit; one is a
real, separate translation unit:

| Generated file | Included by | Its own TU? | How the file says so |
|---|---|---|---|
| `linebreakdata.c` | — | **yes** | defines **non-**`static` `lb_prop_supplementary` (`src/linebreakdata.c:9`), `lb_prop_supplementary_len` (`:791`) and `lb_prop_bmp` (`:795`), all three declared `extern` at `src/linebreakdef.h:233-235` and referenced from `src/linebreak.c:613` |
| `linebreakauxdata.c` | `src/linebreak.c:59` | no | `static const struct LineBreakAuxRange lb_prop_pi_qu[]` (`:12`) and three more |
| `wordbreakdata.c` | `src/wordbreak.c:56` | no | `static const … wb_prop_default[]` (`:8`) |
| `graphemebreakdata.c` | `src/graphemebreak.c:51` | no | `static const … gb_prop_default[]` (`:8`) |
| `indicconjunctbreakdata.c` | `src/graphemebreak.c:52` | no | `static const … incb_prop[]` (`:8`) |
| `eastasianwidthdata.c` | `src/eastasianwidthdef.c:25` | no | `static const … eaw_prop[]` (`:10`) |
| `emojidata.c` | `src/emojidef.c:33` | no | `static const … ep_prop[]` (`:8`) |

`src/Makefile.gcc:108-110` lists the same nine files in `CFILES`; the six
textually included ones are correctly absent from it, and `linebreakdata.c` is
correctly present. (The screen report says that `CFILES` lists only eight and
omits the included ones; at this pin it lists nine and agrees with
`src/Makefile.am`. The stale document at this pin is `doc/architecture.md` — see
[Two stale claims](#two-stale-claims-in-upstreams-own-documentation).)

**Include closure**, computed by following every quoted `#include` transitively
from each of the nine units, all of which resolve inside `src/`:

```
unibreakbase.c     → unibreakbase.h
unibreakdef.c      → unibreakdef.h → unibreakbase.h
linebreak.c        → eastasianwidthdef.h, linebreak.h, linebreakdef.h,
                     linebreakauxdata.c, unibreakdef.h, unibreakbase.h
linebreakdata.c    → linebreakdef.h, unibreakdef.h, unibreakbase.h
linebreakdef.c     → linebreak.h, linebreakdef.h, unibreakdef.h, unibreakbase.h
eastasianwidthdef.c→ eastasianwidthdef.h, eastasianwidthdata.c,
                     unibreakdef.h, unibreakbase.h
emojidef.c         → emojidef.h, emojidata.c, unibreakdef.h, unibreakbase.h
graphemebreak.c    → graphemebreak.h, graphemebreakdata.c,
                     indicconjunctbreakdata.c, indicconjunctbreakdef.h,
                     emojidef.h, unibreakdef.h, unibreakbase.h, graphemebreakdef.h
wordbreak.c        → unibreakdef.h, wordbreak.h, wordbreakdata.c, emojidef.h,
                     wordbreakdef.h, unibreakbase.h
```

Every one of the seventeen local names is reachable from more than one place or
is included by bare name from inside a data file, so `src/` goes on the include
path for **every** translation unit rather than per file. The seven internal
headers — `linebreakdef.h`, `eastasianwidthdef.h`, `emojidef.h`,
`indicconjunctbreakdef.h`, `graphemebreakdef.h`, `wordbreakdef.h`, and
`test_skips.h` — are **not** installed; upstream's `include_HEADERS`
(`src/Makefile.am:1-6`) names exactly five files, and `src/NEWS:8` records that
8.0 stopped installing `linebreakdef.h` and `eastasianwidthdef.h`.

The five installed public headers, in upstream's own order, are `unibreakbase.h`,
`unibreakdef.h`, `linebreak.h`, `graphemebreak.h`, `wordbreak.h`.

**Switches.**

* `-std=c99` is explicit and load-bearing, not decoration.
  `src/unibreakdef.h` declares `ub_bsearch` as a plain `inline` and
  `src/unibreakdef.c` closes with `extern inline … ub_bsearch(…)`. Under C89
  inline rules that combination never emits the symbol and the failure appears
  as a missing symbol at link time, not as a dialect error. No `-std` flag
  appears anywhere in upstream's own build files; upstream relies on the compiler
  default, and this fork does not.
* `UNIBREAK_LAZY_INCB` is left at upstream's default of `0`
  (`src/graphemebreak.c:57-63` carries the comment explaining why: since Unicode
  16.0, `InCB=Consonant` is assigned to characters whose `GCB` is `Other`, so the
  lookup can no longer be skipped). Setting it to 1 would change behaviour; this
  fork does not flip it.
* `NDEBUG` is **not** set by this build. Upstream's `src/Makefile.gcc:92` sets it
  for its release configuration, and Zig's `ReleaseFast` and `ReleaseSmall`
  define it for the C they compile, while `Debug` and `ReleaseSafe` do not. The
  only `assert`s in the core are `assert(*ip <= len)` in the three decoders and
  `assert(0)` at `src/wordbreak.c:453`'s unreachable default, so the reachable
  code differs between the two families of mode. Both families have since been
  observed to compile and to pass: the C core built and the fifteen facade tests
  ran in `Debug` and `ReleaseSafe`, where `NDEBUG` is not defined for C, and in
  `ReleaseSmall` and `ReleaseFast`, where it is — see
  [Verification status](README.zig.md#verification-status) for the receipts.

**No build-time fetch, and no upstream build system.** All seven generated
tables are checked in. Regeneration is upstream's `make <target>` plus `wget`
against `unicode.org` (`src/Makefile.am:62-116`) and nothing in this build runs
it. `configure.ac`, `Makefile.am`, `bootstrap`, `autogen.sh`, `purge`,
`libunibreak.pc.in`, `Doxyfile`, `src/Makefile.gcc` and `src/Makefile.msvc` ship
as upstream's own files and are read by nothing here: no autotools, Make, CMake,
`configure` or `nmake` is invoked.

**No system mode.** This wave's contract keeps the source pin and the bounded
contracts identical in every mode, so there is no `-Dfsys=` option, no
`b.systemIntegrationOption`, and no claim about any system-installed libunibreak.
The rule that a system mode must translate the headers it links is recorded as
**NOT APPLICABLE** here rather than satisfied: a distro's libunibreak is not this
manifest's pinned 8.0 with this manifest's headers, and translating these headers
against it is exactly the header/ABI mismatch the contract forbids. The Zig
facade and the whole build reach the library through the translated headers and
the archive compiled in this repository, and nothing else.

### The Unicode data, and what is done with it

No table is generated at build time. Every generated table names its UCD input,
and the input's own recorded date, in its first lines:

| Generated file | UCD input(s) and the date the file records |
|---|---|
| `src/linebreakdata.c` | `LineBreak-17.0.0.txt`, 2025-07-29 |
| `src/linebreakauxdata.c` | `DerivedGeneralCategory-17.0.0.txt` 2025-07-24, `LineBreak-17.0.0.txt` 2025-07-29, `emoji-data.txt` 2025-07-25 |
| `src/wordbreakdata.c` | `WordBreakProperty-17.0.0.txt`, 2025-06-30 |
| `src/graphemebreakdata.c` | `GraphemeBreakProperty-17.0.0.txt`, 2025-06-30 |
| `src/eastasianwidthdata.c` | `EastAsianWidth-17.0.0.txt` 2025-07-24, `LineBreak-17.0.0.txt` 2025-07-29 |
| `src/indicconjunctbreakdata.c` | `DerivedCoreProperties-17.0.0.txt`, 2025-07-30 |
| `src/emojidata.c` | `emoji-data.txt`, 2025-07-25 |

`emoji-data.txt` is the one input whose name carries no revision suffix, so
`emojidata.c`'s 17.0.0 provenance is **inferred** from the six inputs beside it
and from the checked-in tables generated in the same run — not read out of its
own bytes. Every other input names 17.0.0 in its own first line.

The seven generators — `generate_linebreakdata.py`,
`generate_linebreak_aux.py`, `generate_word_break.py`,
`generate_grapheme_break.py`, `generate_east_asian_width.py`,
`generate_indic_conjunct_break.py`, `generate_extended_pictographic.py` — plus
the shared helper `unicode_data_property.py`, the two `sed` scripts
(`extract_data.sed`, `expand_single.sed`) and the `linebreakdata1.tmpl` header
template all ship in `src/`. They are **provenance, not build steps**: the tables
are checked in, so no fetch and no generator run is needed, and this build
executes none of them. They are kept so that the checked-in tables can be traced
to the data they came from and regenerated deliberately, and so that a re-sync
has something to diff against.

Two fast-path thresholds are baked into the C and would need re-checking if a
table were ever regenerated: `is_east_asian` early-outs below `U+1100` and
`is_potential_emoji` below `U+1F000`; both comments say so in place.

### One upstream defect this fork guards around and does not patch

`set_graphemebreaks` (`src/graphemebreak.c:147`) has no empty-length guard. It
reads the first character, gets `EOS` back with `posNext` still `0`, computes
`size_t brksPos = posNext - 1` at `:212` — which wraps to `SIZE_MAX` — and writes
`brks[brksPos]` at `:221`, the rule GB1 case. With `len == 0` that is one byte
**before** the caller's buffer. `set_linebreaks` (`src/linebreak.c:1450-1453`)
and `set_wordbreaks` (`src/wordbreak.c:173,177,463`) both return without writing
anything for an empty input, so the defect is specific to the grapheme pass.

It was confirmed here rather than reasoned about: with the typed wrapper calling
through, a `Grapheme.perCodeUnit("", out)` aborted with `thread 41214 panic:
addition of unsigned offset to 0x7ffc681153e5 overflowed to 0x7ffc681153e4` at
`src/graphemebreak.c:221` and exited on signal 6
(`local://foundation-matrix-empty-grapheme-before.log`, Debug, native,
2026-10-03). After the guard was added to the three typed grapheme methods the
same probe printed `empty grapheme guard: before=inside_char output=no_break
after=inside_char` and exited 0
(`local://foundation-matrix-empty-grapheme-after.log`).

**No upstream byte was changed.** `src/graphemebreak.c` at this pin still has no
guard, its digest in `UPSTREAM.sha256` is the pinned one, and the difference is
carried by the Zig wrapper — which is why it belongs in this file as well as in
the facade's documentation. A C caller of the raw route inherits the defect and
must not call `set_graphemebreaks_utf8`, `set_graphemebreaks_utf16` or
`set_graphemebreaks_utf32` with `len == 0`.

### The conformance fixtures

Three checked-in Unicode conformance files are used **in place**, in `src/`.
There is no `testdata/` directory and no duplicate copy anywhere:

| Fixture | Bytes | Own first line | Own date line | Data rows | Code points | `÷` | `×` |
|---|---|---|---|---|---|---|---|
| `src/LineBreakTest.txt` | 3 166 819 | `# LineBreakTest-17.0.0.txt` | `# Date: 2025-07-24, 13:28:32 GMT` | **19 338** | 60 487 | 31 977 | 47 848 |
| `src/WordBreakTest.txt` | 322 136 | `# WordBreakTest-17.0.0.txt` | `# Date: 2025-03-24, 14:46:35 GMT` | **1 944** | 6 543 | 6 588 | 1 899 |
| `src/GraphemeBreakTest.txt` | 126 570 | `# GraphemeBreakTest-17.0.0.txt` | `# Date: 2025-03-24, 14:45:55 GMT` | **766** | 1 990 | 2 157 | 599 |

A **data row** is a line that is neither a `#` comment nor blank. Each file has
exactly 30 comment lines and zero blank lines, so the count is
`total lines − 30`, and every one of the three files states its own row count in
its footer — `# Lines: 19338`, `# Lines: 1944`, `# Lines: 766` — which agrees
with the measurement above in all three cases. Those row counts are properties of
the fixtures, not of the library: a UCD bump moves them, and a conformance test
that asserts them is asserting that it read the whole file.

**Fixture syntax**, audited over every row of all three files. The data segment
is everything before the first `#`; only these characters occur in it, and
nothing else does: space, TAB, `÷` (U+00F7), `×` (U+00D7), and uppercase hex
digits `0-9` `A-F`. No lowercase hex digit occurs anywhere in any data segment.
No `x`, `X` or any other break marker is used as a marker — the letters `x` and
`X` appear in these files only inside the `#` comments, as in `ALettermExtPict` or
`<reserved-1FFFD>`. Every data row contains exactly one TAB, separating the data
from its comment, so splitting on `#` first is safe. Markers strictly alternate
around the code points: `m0 c0 m1 c1 … m(n-1) c(n-1) m(n)`, whitespace-separated,
with `n ≥ 2` in every row — which is why `markers == code points + 1` holds in
all three files. The legend, verbatim, identical in all three apart from the
property name:

```
# Format:
# <string> (# <comment>)?
#  <string> contains hex Unicode code points, with
#	÷ wherever there is a break opportunity, and
#	× wherever there is not.
```

These files are exactly the independent oracle this workspace asks for: they are
Unicode's own expected answers, not a round trip through the same code.

`src/test_skips.h` is 171 bytes and all three arrays — `testSkipsWord`,
`testSkipsGrapheme`, `testSkipsLine` — contain only their terminating `0`. **The
skip list is empty**, consistent with `src/NEWS:14` ("Make all Unicode conformance
tests pass without skipping any one"). That sentence is upstream's claim about
upstream's own runs; what this workspace adds is its own observation of the
unmodified harness, below.

`src/tests.c` is upstream's own C harness, kept byte-identical and compiled
unmodified as this package's `upstream-test` step. Three of its behaviours are
load-bearing for anything that replays these fixtures, and this fork preserves
them rather than reinventing them:

* `src/tests.c:250` passes `lang = "-strict"` for line breaking, and `""` for
  word and grapheme breaking (`:254`, `:258`).
* `src/tests.c:266-273` folds **both** `LINEBREAK_ALLOWBREAK` and
  `LINEBREAK_INDETERMINATE` to `LINEBREAK_MUSTBREAK` before comparing, because
  "The Unicode test data doesn't differentiate between these states". The
  distinction is real and is a fifth line opcode; it is collapsed **only** at
  this comparison, and this fork's own direct behavioural tests keep it.
* `src/tests.c:131,139,147` opens the three fixtures by **bare name** and
  `src/Makefile.am:129-131` satisfies that with symlinks. This build instead
  runs the harness with `src/` as its working directory, so there is no copy, no
  symlink and no fixture rewriting.

**Observed here.** `zig build upstream-test` built `src/tests.c` unmodified and
ran it three times with `src/` as its working directory, and it printed, in this
workspace, on 2026-10-03 in Debug:

```
LineBreakTest.txt: Passed 19338 out of 19338 (100%)
WordBreakTest.txt: Passed 1944 out of 1944 (100%)
GraphemeBreakTest.txt: Passed 766 out of 766 (100%)
```

(`local://foundation-matrix-libunibreak-unicode-r5.log`. The command as a whole
exited 1 in that run because `zig/api_exercise.zig` did not compile at the time;
the `upstream-test` step itself succeeded, and the exercise was corrected before
the next run. The three fixture counts above are the row counts in the table
earlier in this section, reproduced by the oracle itself.)

### Unicode data terms

The seven generated tables and the three fixtures are Unicode, Inc. material,
not libunibreak source, and `LICENCE`'s Zlib grant is upstream's grant over
upstream's code. Three different notices appear across these ten files, and none
of them is the Zlib text:

1. **The three fixtures carry the Unicode notice in their own first lines.**
   `src/LineBreakTest.txt:3-5`, `src/WordBreakTest.txt:3-5` and
   `src/GraphemeBreakTest.txt:3-5` are identical, verbatim:

   ```
   # © 2025 Unicode®, Inc.
   # Unicode and the Unicode Logo are registered trademarks of Unicode, Inc. in the U.S. and other countries.
   # For terms of use and license, see https://www.unicode.org/terms_of_use.html
   ```

   The whole notice has been audited, not sampled: each file's complete comment
   block is 30 lines — the name and date, the three notice lines, the UCD and
   `Format:` legend, and a closing `#` / `# Lines: N` / `#` / `# EOF` footer —
   and every `#` line in all three files was read. There is no further
   copyright, trademark or terms text anywhere in them. In particular this
   closes the screen report's open item about `WordBreakTest.txt`'s notice
   beyond line 8: its notice is the same three lines, in the same place, and
   nothing follows it but the legend and the footer.

2. **The seven generated tables carry no grant at all.** Each opens with only a
   generation banner — `/* The content of this file is generated from:` followed
   by the UCD filenames and dates — and then its data. A `grep` for copyright,
   licence, warranty, redistribution and trademark text across the whole tree
   returns **no** match in any of the seven. They are Unicode-derived by
   provenance, not by an in-file grant, and a per-file audit has to say so
   rather than leave an auditor looking for a header upstream never wrote.

3. **Nine source files and the tree's own documentation point at the terms
   without restating them.** `src/linebreak.c:38`, `src/linebreak.h:37`,
   `src/linebreakdef.h:38`, `src/wordbreak.c:38`, `src/wordbreak.h:38`,
   `src/wordbreakdef.h:38`, `src/graphemebreak.c:36`, `src/graphemebreak.h:35`
   and `src/graphemebreakdef.h:35` each carry "The Unicode Terms of Use are
   available at `<URL:http://www.unicode.org/copyright.html>`", on the line
   following. `README.upstream.md:28-29` says the same in prose. None of this
   is a grant.

**The carried terms text.** `https://www.unicode.org/terms_of_use.html` — the URL
the fixtures name — redirects to `https://www.unicode.org/copyright.html`, whose
§2(c) states that "All Unicode Data Files and Unicode Software are subject to
the terms and conditions of the free and open-source **Unicode License v3**".
That is the licence governing the seven tables and the three fixtures, so that
is what this fork carries: [`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) is the
**verbatim byte stream** of `https://www.unicode.org/license.txt`, 1 995 bytes,
SHA-256 `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96`,
fetched 2026-10-03. Not one word of it is authored here, nothing is paraphrased,
and it is installed beside the archive because those tables are inside the thing
a consumer receives.

This fork does not restate those terms, does not paraphrase them and does not
relicense them. The files travel unmodified and keep the notice the Unicode
Consortium put in them, and the terms that govern them are the ones those lines
name. The Zlib text in `LICENCE` does not reach these ten files, and nothing in
this repository claims that it does.

## What is upstream's and is shipped unmodified

Everything named in `build.zig.zon` `.paths` that this fork did not write:

| Path | What it is |
|---|---|
| `src/` | the whole C library: the nine translation units, the five public and seven internal headers, the seven generated UCD tables, upstream's own `tests.c` harness with its empty `test_skips.h`, the seven generators and their shared helper, the two `sed` scripts and the template, and the three Unicode conformance fixtures, all byte-identical |
| `doc/architecture.md` | upstream's design documentation, including its data pipeline and the two stale claims recorded below |
| `LICENCE` | the zlib/libpng grant, verbatim, British spelling |
| `README.upstream.md`, `NEWS`, `AUTHORS` | upstream's own statements of what the library is, what changed and who wrote it. `README.upstream.md` is upstream's README, carried byte-identical (SHA-256 `cc38c7b8…`); **this fork's own `README.md` is a different file and is not in `.paths` as upstream's bytes** — it is the fork's, described in [`FORK-LICENSE.md`](FORK-LICENSE.md) |
| `Makefile.am`, `configure.ac`, `autogen.sh`, `bootstrap`, `purge`, `libunibreak.pc.in`, `Doxyfile` | upstream's autotools build system and its packaging template; kept for provenance, invoked by nothing here |
| `src/Makefile.am`, `src/Makefile.gcc`, `src/Makefile.msvc` | upstream's three build-system files inside `src/`; `src/Makefile.am` is also the authoritative translation-unit list |
| `.clang-format` | upstream's formatting convention. This fork must not reformat upstream code, and this is the file that says how upstream formats |
| `.mailmap` | upstream's contributor-identity map |

`.gitignore` is upstream's file too, and it is in the upstream tree, but it is
**not** in `.paths` and **not** in `UPSTREAM.sha256`: upstream's 43 lines are
kept verbatim and this fork appends a 26-line Zig block, so the working-tree file
is not byte-identical. See [`NOTICE.md`](NOTICE.md).

`.paths` names one more upstream file in this migration, for the same reason it
named `README.md` before: `README.upstream.md` travels with the package, so a
fetched copy carries upstream's own statement of the licence and of the Unicode
terms rather than only this fork's summary of them.

## What is carried but not compiled

`tools/` travels in `.paths` and nothing in it is compiled. `build.zig`'s install
step reads `tools/test.txt` and ships it as `share/libunibreak/test.txt`, so a
fetched copy that lacked the directory could not install a file this tree has
always had. The six example programs stay unbuilt for upstream's own reason:
`tools/linebreak_test.c` reaches outside the standard headers for `<iconv.h>`, so
it is not a portable example of anything. The seven files and their digests are in
[`UPSTREAM.sha256`](UPSTREAM.sha256) and [`NOTICE.md`](NOTICE.md). They are not
deleted, and nothing in this package modifies them.

## Integrity

`UPSTREAM.sha256` holds **66** records: the SHA-256 of every upstream file this
package ships, one `<hex>  <path>` line each, in `sha256sum` format. Check it
with:

```
sha256sum -c UPSTREAM.sha256
```

The path set is exactly the upstream-owned entries of `build.zig.zon` `.paths`:
`src/` (45 files), `doc/architecture.md` (1), `tools/` (7) and 13 root files.
Because the record names only files `.paths` ships, the same command works in a
cloned repository *and* in an unpacked package fetched by a dependent. The
`#`-prefixed header of the file explains, per path, why the one remaining upstream
blob — `.gitignore` — is absent, and records how the seven `tools/` digests were
obtained.

**How the digests were produced, and what they are a digest of.** Each blob of
the pinned commit `28a2756b864c343f438cd22537d49d394d4666a5` was read out of the
clone's object store and hashed as a raw byte read (CPython 3.13.14
`hashlib.sha256`) on 2026-10-03; the result was compared against the record as
written: **59 compared, 0 disagreements**. So this file is a claim about
**upstream's bytes**, not about this working tree — every line came from the
pinned object rather than from a file on disk that this fork could have edited.
That distinction is not pedantic: upstream's `.gitignore` blob
(`bbad54185e3da91dacb7854b544440426c2ff2cf71062995cdcdfd5ea56fae07`, 549 bytes,
43 lines) and this fork's appended working-tree `.gitignore` are different files,
and only the first is quoted in the record.
The seven `tools/` records were added later, when `.paths` began carrying that
directory. Their digests come from the same pinned-blob extraction, and were read
again from the working-tree files on 2026-10-04 — all seven agree. No second
pinned-object comparison was run for them, so the **59 compared** figure above is
the 2026-10-03 observation about 59 records and is not restated as 66.

**What the record establishes.** The bytes a build compiles, the data it installs
and the fixtures its tests read are the bytes this record pins, and any later edit
to one of those 66 files fails the check loudly.

**What it does not establish.** It is not a signature and not a Git object id. It
is not the archive receipt above, which is a digest of a tar stream, and not the
release-asset digest the screen report read from the API, which is a digest of an
uploaded `.tar.gz`. Three different digests describe three different things and
none of them substitutes for another.

**Status: observed.** `sha256sum -c UPSTREAM.sha256` ran in this workspace on
2026-10-03 and exited 0 with 59 `OK` lines and no failure
(`local://foundation-matrix-libunibreak-provenance-checksums.log`), so the
record describes the working tree as well as upstream's blobs. The comparison
described above is a second, independent observation — 59 pinned blobs hashed,
59 records compared, 0 disagreements — and it is a check of the record against
upstream rather than of a working tree against the record. A third, wider
comparison took all 67 pinned blobs against this working tree and found exactly
one difference, `.gitignore`, the file this fork appends to and this record
deliberately omits (`local://foundation-matrix-source-integrity.json`). The same
`sha256sum -c` command is the first step of the `native` job in
[`.github/workflows/verify.yml`](.github/workflows/verify.yml).

## Why this library, stated honestly

**The selection is made on the ledger's missing-capability / source-build rule,
not on a claimed global dependency-breadth pass.** What was established:

* **The gap is real.** The matrix has bidirectional text (SheenBidi, UAX #9) and
  no line breaking, no word breaking and no grapheme clustering. Those three are
  the answers to "where does this line end, where does this word end, where does
  this user-perceived character end", and nothing the workspace shipped answers
  any of them.
* **Overlap is one third of one module, against a library the workspace does not
  ship.** `JuliaStrings/utf8proc` exposes `utf8proc_grapheme_break_stateful` and
  `utf8proc_grapheme_break`, both UAX #29 grapheme breaking, and no line or word
  breaking at all. SheenBidi is UAX #9 only and computes no break opportunities.
  libunibreak performs no Unicode normalization of any kind, so it is not a
  second copy of anything else in the tree either.
* **The algorithm is not trivial and the failure mode is silent.** 8.0 added the
  AK/AP/AS/VF/VI/HH classes and rules LB12a, LB15a–d, LB19a, LB20a, LB21a, LB21b,
  LB23a, LB28a and LB30b; four of those rules cannot be decided without the next
  character and are implemented with a tentative-break-and-revert fixup, and LB25
  is a numeric-expression state machine with its own separate fixup. A naive
  implementation compiles, runs, returns plausible offsets and is wrong, with no
  crash and no error.

**Global R2 dependency breadth: NOT ESTABLISHED.** The screen report records that
libunibreak ships in Debian from bullseye forward, that Gentoo, Fedora rawhide
and others package it, and that the release-asset download counts are 11 437 /
44 529 / 268 348 for 8.0 / 7.0 / 6.1. What it did **not** establish is a
large-fraction-of-serious-stacks dependency count or a named application that
depends on it: the research corpus never names the library, and Debian assigns
the package to the Qt/KDE team rather than to a consumer. **Packaging breadth is
not proof of dependency breadth**, and this fork does not upgrade one into the
other. The disposition rests on the missing-capability limb.

**Maintenance cost is stated, not minimised.** `AUTHORS` names one current core
maintainer and the GitHub owner is a personal account. That is a real
concentration and it argues for keeping a live upstream merge path — which is
open here: the tag sits on `master`, and there is no CLA, `CONTRIBUTING` or DCO
file at this pin. Three distributions were already packaging 8.0 within the same
month of its release.

## Two stale claims in upstream's own documentation

`doc/architecture.md` is shipped unmodified, and two of its statements are
contradicted by the 8.0 source. Both are recorded here and **neither is fixed in
upstream's file**: upstream documentation is not this fork's to edit, and a
correct local edit would be a second, silent divergence.

1. **`doc/architecture.md:88`** lists "A `bool` fallback for MSVC older than
   VS2013" among the contents of `unibreakdef.h`. There is no such fallback:
   `src/unibreakdef.h:38` includes `<stdbool.h>` unconditionally, and a search of
   `linebreak.c`, `wordbreak.c`, `graphemebreak.c`, `unibreakdef.h`,
   `unibreakbase.h`, `linebreakdef.h`, `wordbreakdef.h`, `graphemebreakdef.h`,
   `indicconjunctbreakdef.h`, `eastasianwidthdef.h`, `emojidef.h` and the
   included data files finds no `_MSC_VER` and no `bool` fallback anywhere in the
   tree. This is a documentation defect, not a portability limitation of the
   library: any VS2013-or-newer compiler has `<stdbool.h>`.
2. **`doc/architecture.md:92-94`** says each generated `*data.c` "defines
   `static const` arrays and is `#include`d directly into the module's `.c` file
   (it is not compiled separately)", and its table row at `:98` therefore lists
   `linebreakdata.c` as "Included by `linebreak.c`". Both halves are false at this
   pin: `src/Makefile.am:15` lists `linebreakdata.c` in
   `libunibreak_la_SOURCES`, `src/linebreak.c:59` includes
   `linebreakauxdata.c` and not `linebreakdata.c`, and `linebreakdata.c` defines
   non-`static` symbols declared `extern` at `src/linebreakdef.h:233-235`. The
   other six rows of that table are correct.

A third item is a correction rather than a defect: the screen report records that
`src/graphemebreak.c` reaches `unibreakdef.h` only transitively. At this pin it
includes it directly at `src/graphemebreak.c:55`. The build puts `src/` on the
include path for every unit regardless, so nothing depends on the difference.

## Synchronising with a new upstream release

1. `git fetch upstream`, check out the new tag, and read
   `src/unibreakbase.h`'s `UNIBREAK_VERSION`; that value, not the tag spelling,
   is the version.
2. Re-derive the translation-unit list from `src/Makefile.am`. Do not take it from
   `src/Makefile.gcc`, and do not take it from `doc/architecture.md`, whose
   `linebreakdata.c` row is wrong — see the section above.
3. Replace the upstream files in place. Do not hand-patch upstream source to make
   a build problem go around.
4. Re-read `LICENCE`, the notice in each of the three fixtures, the banner of each
   of the seven generated tables, and the head of all six `tools/` programs. A
   new release can move a file between the generated and hand-written sets.
5. Recompute `UPSTREAM.sha256` over the same path set **from the new pin's
   blobs**, not from the working tree, and update the count in its header and in
   this file. If a file moves out of `.paths`, say why in the header.
6. Re-measure the three fixture row counts and the generated tables' UCD inputs
   and dates, and update the table above and the constants in `tests.zig`. Those
   are properties of the fixtures, so a UCD bump moves them.
7. Bump `.version` in `build.zig.zon`, update the pin in this file and in
   `README.zig.md`, and add one numbered `CHANGELOG.md` entry.
8. Re-read the empty-length path of `set_graphemebreaks`
   (`src/graphemebreak.c:147,212,221`). If a later release adds a `len == 0`
   guard, the typed wrapper's early return becomes redundant — re-check it
   against the new source rather than deleting it on the assumption that
   upstream fixed it. See
   [One upstream defect this fork guards around and does not patch](#one-upstream-defect-this-fork-guards-around-and-does-not-patch).

## Verification status

The gate table lives in
[`README.zig.md`](README.zig.md#verification-status) and is not repeated here.
In short: the native build and install of the current source, the facade tests,
the API exercise, the example, the consumer package and upstream's own
unmodified `src/tests.c` have all been observed on this host in `Debug` —
`23/23 steps succeeded; 15/15 tests passed`, with upstream's harness passing all
three fixtures whole — and the tests, example and consumer in `ReleaseSafe`,
`ReleaseFast` and `ReleaseSmall`, `13/13 steps succeeded; 15/15 tests passed` in
each; the six-target compile-only `check` has been observed at `43/43 steps
succeeded`; `sha256sum -c UPSTREAM.sha256` has been observed at exit 0 with 59
`OK` lines, as has the comparison of all 67 pinned blobs against this working
tree; an installed-C program has compiled against all five installed headers and
run against that archive; and the 53-platform `cross-test` run is `partial` —
53 of 53 targets built, 20 ran the test step with 15 tests each, 33 are
`build_only` for want of a runtime, 0 failed. The filtered-fetch consumer and the
package integrity gate are recorded outside this package, in
`local://foundation-matrix-final-package-proof.json`, where only an observed
receipt establishes a pass. CI has never executed: this package is local and
unpublished.

**Those receipts are historical, and this migration has added nothing to them.**
They were taken on 2026-10-03 against the tree as it stood before the shared and
runtime-loading delivery, the pkg-config metadata and the Nix/devenv packaging
landed. Every gate this wave requires is `PENDING-VERIFICATION`, listed one by
one in [`README.md`](README.md) §3. In particular: the README relocation means
`UPSTREAM.sha256` now records `README.upstream.md` instead of `README.md`, with
the **same digest** and the **same bytes**; until the driver re-runs
`sha256sum -c UPSTREAM.sha256`, that re-pointing is a claim this file makes and
has not verified.

Every receipt above is reported against the tree it was taken against. What they
do not establish is the other half of the matrix boundary: 33 of the 53 published
platforms were compiled and never executed.

This document's own assertions are `SOURCE-CONFIRMED` — read out of the pinned
source — or, for the archive receipt, driver-measured. The empty-input defect
recorded above is stronger than that: it was reproduced at run time and then
again after the guard, with receipts named.

## See also

* [`NOTICE.md`](NOTICE.md) — attribution, the licence split, the per-file audit
  including the three exceptions upstream ships, and every file this fork adds or
  edits.
* [`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) — the verbatim primary text of the
  Unicode terms that govern the seven generated tables and the three fixtures.
* [`README.zig.md`](README.zig.md) — how to build, import and call the package,
  the raw C route versus the typed surface, and the authoritative gate matrix.
* [`FORK-NOTES.md`](FORK-NOTES.md) — the problems met while doing this, and what
  was decided.
* [`CHANGELOG.md`](CHANGELOG.md) — numbered fork-only divergences.
* [`UPSTREAM.sha256`](UPSTREAM.sha256) — the integrity record itself.
