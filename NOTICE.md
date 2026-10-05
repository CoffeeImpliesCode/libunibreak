# NOTICE

This is the per-file licence and attribution record for this fork. It exists
because the libunibreak tree is **not one licence**: the Zlib grant in
`LICENCE` covers upstream's code, ten files inside that code are Unicode
material under different terms, one file in `tools/` carries its own and
different broad grant, and five more in `tools/` carry no notice at all. A
single-tree label would hide every one of those.

Everything below was read out of the files at the pinned commit
`28a2756b864c343f438cd22537d49d394d4666a5` (tag `libunibreak_8_0`) on
2026-10-03. The audit is complete: every one of the tree's **67** blobs was
examined for a copyright, licence, warranty, redistribution or trademark
notice, and the file-by-file result is the table below. Nothing here is
inferred from a distribution's packaging metadata.

## Upstream work

libunibreak is the work of Wu Yongwei and contributors. Upstream's own
`LICENCE` carries four **undated** copyright lines, verbatim:

```
Copyright (C) Wu Yongwei <wuyongwei at gmail dot com>
Copyright (C) Tom Hacohen <tom at stosb dot com>
Copyright (C) Petr Filipsky <philodej at gmail dot com>
Copyright (C) Andreas RM-CM-6ver <roever at users dot sf dot net>
```

(That last spelling is upstream's own transliteration of *Andreas Röver*; the
name appears spelled out in `AUTHORS` and in `.mailmap`.) The same Zlib text,
with per-file year ranges that differ from file to file, heads 20 of the tree's
C files. That variation is upstream's and is left exactly as it is. `AUTHORS`
gives the contributions: Wu Yongwei designed and implemented the original
liblinebreak and is the current maintainer; Tom Hacohen added word boundaries;
Petr Filipsky added incremental line breaking (removed again in 8.0);
Andreas Röver added grapheme boundaries.

`LICENCE` is the zlib/libpng text, 1 045 bytes, byte for byte, not edited,
shortened or restated here. Upstream repository:
`https://github.com/adah1972/libunibreak.git`; this fork builds tag
`libunibreak_8_0`, commit `28a2756b864c343f438cd22537d49d394d4666a5`.
`README.upstream.md:25-26` — upstream's own README, carried here byte-identical —
names the same licence and points at that file.

## The grants, and which applies where

Three terms appear in this tree, and a fourth thing — no term at all — appears
in eight files.

| Term | Applies to | Where it is stated |
|---|---|---|
| **Zlib / libpng** | upstream's C sources and headers, its build system, its documentation, its generators, its test harness, its tools | `LICENCE` (the full text), `README.upstream.md:25-26`, and an in-file header on the 20 C files listed below |
| **Unicode terms** | the 7 generated UCD tables and the 3 conformance fixtures | each fixture's own first lines, carried in full at [`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) |
| **A separate broad grant** | `tools/linebreak_test.c` only | its own text, `tools/linebreak_test.c:9-13` |
| **No notice of any kind** | 5 `tools/` programs, `tools/test.txt`, and 13 further files upstream carries under the tree-level grant | nothing in the files; they are named here so an auditor is not left looking for a header that was never written |

### The complete per-file inventory

All 67 blobs at the pin. "Zlib header" means the file itself carries the
Zlib/libpng text with its own copyright line(s).

**20 files with the Zlib header in the file:**

| File | Copyright line(s) as the file states them |
|---|---|
| `src/unibreakbase.c` | `Copyright (C) 2015-2018 Wu Yongwei` (`:7`) |
| `src/unibreakbase.h` | `Copyright (C) 2015-2026 Wu Yongwei` (`:7`) |
| `src/unibreakdef.c` | `Copyright (C) 2015-2026 Wu Yongwei` (`:7`) |
| `src/unibreakdef.h` | `Copyright (C) 2015-2026 Wu Yongwei` (`:7`) |
| `src/linebreak.c` | `Copyright (C) 2008-2026 Wu Yongwei`, `Copyright (C) 2013 Petr Filipsky` (`:7-8`) |
| `src/linebreak.h` | `Copyright (C) 2008-2026 Wu Yongwei` (`:7`) |
| `src/linebreakdef.c` | `Copyright (C) 2008-2026 Wu Yongwei` (`:7`) |
| `src/linebreakdef.h` | `Copyright (C) 2008-2026 Wu Yongwei`, `Copyright (C) 2013 Petr Filipsky` (`:7-8`) |
| `src/eastasianwidthdef.c` | `Copyright (C) 2024 Wu Yongwei` (`:4`) |
| `src/eastasianwidthdef.h` | `Copyright (C) 2024 Wu Yongwei` (`:4`) |
| `src/emojidef.c` | `Copyright (C) 2018 Andreas Röver` (`:4`) |
| `src/emojidef.h` | `Copyright (C) 2018 Andreas Röver` (`:4`) |
| `src/graphemebreak.c` | `Copyright (C) 2016-2019 Andreas Röver`, `Copyright (C) 2024-2026 Wu Yongwei` (`:5-6`) |
| `src/graphemebreak.h` | `Copyright (C) 2016-2026 Andreas Röver` (`:5`) |
| `src/graphemebreakdef.h` | `Copyright (C) 2016-2026 Andreas Röver` (`:5`) |
| `src/indicconjunctbreakdef.h` | `Copyright (C) 2024 Wu Yongwei` (`:4`) |
| `src/wordbreak.c` | `Copyright (C) 2013-2019 Tom Hacohen`, `Copyright (C) 2018-2026 Wu Yongwei` (`:7-8`) |
| `src/wordbreak.h` | `Copyright (C) 2013-2019 Tom Hacohen`, `Copyright (C) 2018-2026 Wu Yongwei` (`:7-8`) |
**10 files that are Unicode, Inc. material — see the section below for the
full treatment:**

`src/linebreakdata.c`, `src/linebreakauxdata.c`, `src/wordbreakdata.c`,
`src/graphemebreakdata.c`, `src/indicconjunctbreakdata.c`,
`src/eastasianwidthdata.c`, `src/emojidata.c`,
`src/LineBreakTest.txt`, `src/WordBreakTest.txt`,
`src/GraphemeBreakTest.txt`.

**1 file with its own separate grant:** `tools/linebreak_test.c`.

**35 files with no in-file notice of any kind.** Every one of these is upstream
material covered by the tree-level `LICENCE` grant, except the six `tools/`
files, which are called out separately below. Together with the 20 Zlib-header
files, the 10 Unicode files, the 1 separately granted file and `LICENCE`
itself, they account for all 67 blobs at the pin:
Paths below are the paths at the pin. One of them is upstream's README, which
this fork carries as `README.upstream.md`; the fork's own `README.md` is a
different file with different contents and is not part of this audit of
upstream's 67 blobs.

```
src/test_skips.h
src/Makefile.am    src/Makefile.gcc    src/Makefile.msvc
src/generate_linebreakdata.py        src/generate_linebreak_aux.py
src/generate_word_break.py           src/generate_grapheme_break.py
src/generate_east_asian_width.py     src/generate_indic_conjunct_break.py
src/generate_extended_pictographic.py
src/unicode_data_property.py
src/extract_data.sed                 src/expand_single.sed
src/linebreakdata1.tmpl
Makefile.am        configure.ac       autogen.sh
bootstrap          purge              libunibreak.pc.in
Doxyfile           .clang-format      .mailmap
.gitignore
README.upstream.md  NEWS               AUTHORS
doc/architecture.md
tools/test.txt
tools/wordbreak_test.c            tools/graphemebreak_test.c
tools/linebreak_bench.c           tools/wordbreak_bench.c
tools/graphemebreak_bench.c
```

## The Unicode material: seven generated tables and three fixtures

These ten files are Unicode, Inc. data under the Unicode terms, not
libunibreak source, and `LICENCE`'s Zlib grant does not reach them. They are
distributed here **unmodified**, inside the archive this package builds and
inside `src/`, and each one keeps whatever notice Unicode put in it.

**The three fixtures carry the notice in their own first lines.**
`src/LineBreakTest.txt:3-5`, `src/WordBreakTest.txt:3-5` and
`src/GraphemeBreakTest.txt:3-5` are identical, verbatim:

```
# © 2025 Unicode®, Inc.
# Unicode and the Unicode Logo are registered trademarks of Unicode, Inc. in the U.S. and other countries.
# For terms of use and license, see https://www.unicode.org/terms_of_use.html
```

The audit of `WordBreakTest.txt`'s notice is **complete, not sampled**. Its
entire comment block is 30 lines and was read end to end: `:1` the file name,
`:2` the date, `:3-5` the three notice lines above, `:6-25` the UCD and
`Format:` legend, and `:26-30` the closing footer (`#`, `# Lines: 1944`, `#`,
`# EOF`). Every `#`-prefixed line in all three fixtures was checked and there is
no further copyright, trademark or terms text anywhere in any of them. The two
files' footers also state their own row counts, which is how the fixture counts
in [`UPSTREAM.md`](UPSTREAM.md) are independently corroborated.

**The seven generated tables carry no grant at all — this is the load-bearing
exception.** Each opens with only a generation banner, for example
`src/linebreakdata.c:1-4`:

```
/* The content of this file is generated from:
# LineBreak-17.0.0.txt
# Date: 2025-07-29, 13:52:18 GMT
*/
```

and then its table. A search of the tree for copyright, licence, warranty,
redistribution and trademark text returns **no match in any of the seven**.
They are Unicode-derived by provenance, not by an in-file grant: seven of the
nine compiled translation units or their includes consist substantially of this
material, so an auditor working file by file has to be told these are the
exception rather than left looking for a header upstream never wrote. The UCD
input and its recorded date for each of the seven are tabulated in
[`UPSTREAM.md`](UPSTREAM.md).

**Nine source files and the tree's README point at the terms without restating
them.** `src/linebreak.c:38`, `src/linebreak.h:37`, `src/linebreakdef.h:38`,
`src/wordbreak.c:38`, `src/wordbreak.h:38`, `src/wordbreakdef.h:38`,
`src/graphemebreak.c:36`, `src/graphemebreak.h:35` and `src/graphemebreakdef.h:35`
each carry "The Unicode Terms of Use are available at
`<URL:http://www.unicode.org/copyright.html>`", on the line following.
`README.upstream.md:28-29` says the same in prose. None of these is a grant and
none is treated as one.

### The carried terms text

The URL the fixtures name, `https://www.unicode.org/terms_of_use.html`,
redirects to `https://www.unicode.org/copyright.html`. §2(c) of that document
states:

> All Unicode Data Files and Unicode Software are subject to the terms and
> conditions of the free and open-source Unicode License v3, unless otherwise
> indicated by specific restriction, permission, or license identified at the
> point of release or in such software, data file, or other documentation.

That is the licence governing the seven tables and the three fixtures, so that
is the text this fork carries:
[`LICENCE-UNICODE.txt`](LICENCE-UNICODE.txt) is the **verbatim byte stream** of
`https://www.unicode.org/license.txt` — 1 995 bytes, SHA-256
`e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96`, fetched
2026-10-03. It is the file as served, including its `UNICODE LICENSE V3`
heading and its `Copyright © 1991-2026 Unicode, Inc.` line. Not one word of it
is authored here.

This fork:

* does not restate, paraphrase or summarise those terms, and does not copy the
  licence text into this repository from memory;
* does not relicense them, does not modify them and does not strip the notices
  they carry;
* ships the ten files unmodified, so a recipient has the terms in the same file
  the data is in, and installs the terms text beside the archive, because those
  tables are inside the thing a consumer receives.

The screen report cites Debian's `debian/copyright` for 8.0-1 as a
machine-readable third-party confirmation that the same ten paths are assigned
to `© 2025 Unicode®, Inc.` / `unicode-data`. That file was **not** read for this
record and nothing here rests on it: the assignment above is established from
the files themselves, which is the stronger source and the one that survives a
packaging change.

## The tools, which are three different situations

`tools/` is carried whole in `build.zig.zon` `.paths`, because one file out of it
is installed as data: `build.zig` reads `tools/test.txt` and installs it as
`share/libunibreak/test.txt`. The six example programs are still not compiled —
`tools/linebreak_test.c` reaches outside the standard headers for `<iconv.h>` — but
they travel with the package rather than being dropped from it, because a fetched
copy that lacked the file the install step reads could not install at all.

* **`tools/linebreak_test.c` carries a different, broader grant in its own
  text**, at `:9-13`, verbatim:

  ```
  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  You may
  freely use it without any restrictions, including copying the
  whole or part of it to use in other programs.
  ```

  That is neither the Zlib text nor the Unicode terms, and it is the only
  file in the tree that says so. It is recorded as upstream's own grant for
  that file; this fork asserts nothing about it beyond quoting it.

* **Five tools programs carry no notice whatsoever:**
  `tools/wordbreak_test.c`, `tools/graphemebreak_test.c`,
  `tools/linebreak_bench.c`, `tools/wordbreak_bench.c` and
  `tools/graphemebreak_bench.c`. Their heads are build and usage comments
  only — a compilation line, a note about alignment, a one-line description —
  and name no copyright and no licence anywhere in the file.

* **`tools/test.txt`** is upstream's own sample text for the line-break demo
  and carries no notice either.

Digests for all seven `tools/` files, taken from the pinned commit's blobs so
they describe upstream's bytes and not this checkout:

| File | Bytes | SHA-256 |
|---|---|---|
| `tools/graphemebreak_bench.c` | 2 062 | `7ddf550181b258a478da36064a763edf80595c369ef6fc7b7e9c450cf34ae077` |
| `tools/graphemebreak_test.c` | 795 | `f6709dcde84af1ee7ef2a80d5db2062e85254a8dc5ccc052ffad8cfd3833829b` |
| `tools/linebreak_bench.c` | 2 160 | `a06caf88883ba7a6201112abe555a6a3f91130e81e13f247b97181391acf67fb` |
| `tools/linebreak_test.c` | 6 171 | `aacbff17e3790e96b1882a0436ab8cb1f46e9551a88405a67d25ec8082dae8e3` |
| `tools/test.txt` | 1 419 | `c49fdcc5643c54cf6a7dc4729a713d91a27b73a4dd9d7b9875a1be295847057e` |
| `tools/wordbreak_bench.c` | 2 045 | `e63f8649a3446f9f1e4a4370cb1586647962967232d332a9e7be04163169aea1` |
| `tools/wordbreak_test.c` | 736 | `04069045c87394b070f07f4e200f16b20c9a06ef8e2f6745ca917db7c4841165` |

They are in [`UPSTREAM.sha256`](UPSTREAM.sha256) because they are in `.paths`, and
the seven digests there are the ones in the table above. The digests were taken
from the pinned commit's blobs rather than from this checkout, and were read again
from the working-tree files while this table was updated: all seven agree, so
these are upstream's bytes and this fork's bytes at the same time.

## The Zlib obligations, and how this fork discharges them

`LICENCE` grants use, alteration and redistribution "subject to the following
restrictions", three of which are obligations on a redistributor:

1. **The origin of this software must not be misrepresented.** Discharged: this
   file, `UPSTREAM.md` and `README.zig.md` name the upstream project, the
   canonical repository, the tag, the commit and the individual authors.
2. **Altered source versions must be plainly marked as such.** **Discharged, and
   still vacuous for upstream's own files.** No upstream C source, header,
   generated table, fixture, harness, licence text or documentation file is
   altered in this fork. `UPSTREAM.sha256` records 59 upstream files by digest,
   and every one of those digests was derived from the pinned commit's blobs and
   re-compared against the record with 0 disagreements, so an alteration would be
   visible in that record. The one upstream file this fork touches at all is
   `.gitignore`, and it is named here and in `UPSTREAM.md` with both digests —
   upstream's blob
   `bbad54185e3da91dacb7854b544440426c2ff2cf71062995cdcdfd5ea56fae07` and the
   appended working-tree file `47aad4f8a9e1c00c97572e818d75075cf82bca8a56dcc2dd0038ac6edd4533cd`.
   This fork does add files, and they are marked as **additions**, which is what
   that condition is about: each is itemised in
   [`FORK-LICENSE.md`](FORK-LICENSE.md), described in the numbered entries of
   [`CHANGELOG.md`](CHANGELOG.md), and newly authored source and build files
   carry an `SPDX-License-Identifier` line of their own. Most carry `Zlib`; the
   two `runtime/` files named in the inventory above carry `MIT`, which is
   recorded there rather than smoothed over. No gate has checked the coverage
   of those headers, which is a pending row in [`README.md`](README.md) §3 and
   not a claim.
3. **This notice may not be removed or altered from any source distribution.**
   Discharged: `LICENCE` ships verbatim, is not in any exclusion list, and is
   installed by `zig build` and, with this file beside it, by `package.nix`.

There is no binary-licensing clause in the Zlib text, so there is nothing
further to discharge. A private repository removes none of this: the licence
text, the copyright notices, the ten Unicode files with their own notices, the
carried Unicode terms and this file travel with the source and with any archive
built from it.

## This fork's own files, and the one grant over them

**Every file this fork adds is covered by a single grant: Zlib (SPDX
`Zlib`).** [`FORK-LICENSE.md`](FORK-LICENSE.md) is that record in full — the
owner's authorization for a per-project licence matching upstream's primary
term, why that term and not another, the complete file list, what the grant does
**not** reach, and the identifier newly authored files are to carry.

Earlier revisions of this section recorded these files as asserting **no**
licence, with status *unassigned*. That described the state before the
authorization, not a grant: no upstream grant ever reached a file this fork
wrote, and none is claimed for them under upstream's name.

This fork's own files:

| File | What it is |
|---|---|
| `build.zig` | Zig 0.16 build graph: the nine translation units, C99, `UNIBREAK_LAZY_INCB=0`, the installed archive and headers, and the `test`, `smoke`, `exercise`, `upstream-test`, `consumer` and `check` steps |
| `build.zig.zon` | package manifest, `.name = .libunibreak`, `.fingerprint = 0xb4b2629221124f29`, no dependencies, and the `.paths` allowlist |
| `cross-test.profile.sh` | settings-only harness configuration sourced by `cross-test`; no hooks, no matrix, no host paths |
| `runtime/generate.zig`, `runtime/graph.zig`, `runtime/library.zig`, `runtime/loader.zig`, `runtime/sync.c`, `runtime/sync.h` | the runtime-loading route `build.zig` substitutes for `translate.createModule()` under `-Druntime=true`, carried whole in `.paths`. Four of the six carry `SPDX-License-Identifier: Zlib` in their own first line; `runtime/graph.zig` and `runtime/library.zig` carry `MIT`. See [`FORK-LICENSE.md`](FORK-LICENSE.md) §"Identifier for newly authored files" |
| `zig/translate.h` | the single header `addTranslateC` translates: the five public headers, in upstream's `include_HEADERS` order, with no macro and no re-declaration |
| `zig/root.zig` | the Zig facade: the opcode enums, the error taxonomy, and the `Line`, `Word` and `Grapheme` method families, plus `pub const c` for the whole raw translated surface |
| `zig/api_exercise.zig` | explicit instantiation of every public facade method and every translated entry point, for the six-target compile gate |
| `tests.zig` | the behavioural and fixture-conformance tests |
| `smoke.zig` | the deterministic example behind `zig build smoke` |
| `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig` | a separate package that depends on this one by relative path and runs it |
| `.github/workflows/verify.yml` | this fork's own verification workflow: integrity, native, the six-target check and the consumer. It publishes nothing and uploads nothing |
| `package.nix` | the standalone Nix derivation: one source-only expression whose `linkage` argument selects the static or shared variant, built by `build.zig` and never by Nix's own C rules |
| `flake.nix` | pinned-nixpkgs entry points: `packages.<system>.default` (static), `.static`, `.shared`, and a tools-only dev shell |
| `devenv.nix`, `devenv.yaml`, `.envrc` | the canonical development shell — tools only, no SDK package — its pinned nixpkgs input, and direnv's entry point |
| `flake.lock` | generated by evaluating `flake.nix` — the pinned nixpkgs revision and its narHashes. It ships because `.paths` names it; it is not written by hand and asserts no licence of its own |
| `README.md` | this fork's README: current native-source deviations, current native-build deviations with their dated history, the current build/run/test matrix, and consumption. Upstream's own README is `README.upstream.md` |
| `UPSTREAM.md`, `UPSTREAM.sha256`, `NOTICE.md`, `README.zig.md`, `FORK-NOTES.md`, `CHANGELOG.md`, `FORK-LICENSE.md` | provenance, integrity record, fork documentation and this grant |

One file travels with the package and is none of the above: `devenv.lock` does
not exist. No devenv shell has been entered, so there is no lock to ship, and
writing one by hand would be a fabrication rather than a record.

Four files in this tree are **not** this fork's, and the grant above does not
reach any of them:

| File | What it is |
|---|---|
| `LICENCE` | upstream's Zlib grant, byte-identical to the pinned blob, covered by upstream's own terms |
| `LICENCE-UNICODE.txt` | the verbatim byte stream of `https://www.unicode.org/license.txt` as served on 2026-10-03 (1 995 bytes, `e7a93b00…`), carried unchanged because seven of the compiled translation units, or their textual includes, are Unicode data. It is Unicode's text, not a grant by this fork |
| `README.upstream.md` | upstream's README, byte-identical to the pinned blob `cc38c7b8…`, recorded by that digest in `UPSTREAM.sha256`. This fork's own README is `README.md`; the two are different files and neither is a rewrite of the other |
| `AUTHORS` | upstream's authorship file — a list of contributions, carrying no licence notice of its own — byte-identical to the pinned blob `34e46e31…`, recorded by that digest in `UPSTREAM.sha256`. It is the file the four copyright lines above are drawn from |

### Where this material is installed

An installed output carries the terms of what it contains. `build.zig` installs
all of it, through `zig build install --prefix "$out"`; `package.nix` adds
nothing, so no path has two writers. Every row below is one call in `build.zig`'s
`build` (`b.installArtifact`, `b.installFile`, `b.addInstallFileWithDir`), and
each named file is installed from the repository path beside it here, so an
installed record is the same bytes as the file in this tree.

| Path | Contents |
|---|---|
| `$out/lib/libunibreak.a`, or the shared library, and `$out/include/{unibreakbase.h,unibreakdef.h,linebreak.h,graphemebreak.h,wordbreak.h}` | the compiled library in whichever `-Dlinkage` selected, and the whole of upstream's `include_HEADERS` (`src/Makefile.am:1-6`); the six internal headers are not installed because upstream does not install them either (`build.zig`'s `installHeader` calls in `addCoreLibrary`, and the module comment's `Installed closure` section that says the same). A shared install is `libunibreak.so.8.0.0` with `libunibreak.so.8` and `libunibreak.so` beside it on ELF, `libunibreak.8.0.0.dylib` with `libunibreak.8.dylib` and `libunibreak.dylib` on Darwin, and `unibreak.dll` under `bin/` with `unibreak.lib` under `lib/` on Windows (the same module-comment section, on `std/Build/Step/InstallArtifact.zig:61-67`) |
| `$out/lib/pkgconfig/libunibreak.pc` | the link metadata, generated by `addPkgConfig` from upstream's `libunibreak.pc.in` field for field, with `prefix` as `${pcfiledir}/../..` |
| `$out/LICENCE`, `$out/LICENCE-UNICODE.txt`, `$out/README.upstream.md` | upstream's grant, the Unicode terms, and upstream's README, at the prefix root under the names this repository preserves them under (the three `b.installFile` calls in `build` that name no directory) |
| `$out/share/licenses/libunibreak/{LICENCE,LICENCE-UNICODE.txt,AUTHORS,README.upstream.md,FORK-NOTES.md,UPSTREAM.sha256}` | the six the install step reaches through `installLicenceRecords`, which walks the `licence_records` list into the same directory |
| `$out/share/licenses/libunibreak/{NOTICE.md,FORK-LICENSE.md,UPSTREAM.md}` | this audit, the grant over this fork's own files, and the pin, installed by name by the three `b.installFile` calls beside them in `build` |
| `$out/share/lib/unibreak/{LineBreakTest.txt,WordBreakTest.txt,GraphemeBreakTest.txt,test.txt}` | the data a recipient needs to re-run upstream's own conformance harness, under the terms already installed beside it (the four `b.installFile` calls that follow them in `build`) |

**That directory receives nine records, not three.** Three are named directly
in the install step and six more reach it through `installLicenceRecords`, whose
`for (licence_records)` loop installs each under
`share/licenses/libunibreak/`. An earlier revision of this table listed only
the three direct calls and so described a directory a recipient does not
receive. `build.zig`'s own module comment, under `Published routes`, names the
same nine and is independent of either list.

Three of the nine are upstream's pinned blobs, one is the carried Unicode text,
and five are this fork's own records under the single grant above:

| Installed record | Bytes | SHA-256 | What the bytes are |
|---|---|---|---|
| `LICENCE` | 1 045 | `0c57e2ec…` | upstream's Zlib grant, byte-identical to the pinned blob (`UPSTREAM.sha256:66`) |
| `LICENCE-UNICODE.txt` | 1 995 | `e7a93b00…` | the verbatim byte stream of `https://www.unicode.org/license.txt`. Not an upstream file, so its digest is written in `UPSTREAM.sha256`'s header comment and is not among that file's 66 checkable records (`UPSTREAM.sha256:37-40`) |
| `AUTHORS` | 697 | `34e46e31…` | upstream's authorship file, one of the 13 pinned root files (`UPSTREAM.sha256:13,64`) |
| `README.upstream.md` | 2 996 | `cc38c7b8…` | upstream's README, byte-identical to the pinned blob (`UPSTREAM.sha256:69`) |
| `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md`, `FORK-NOTES.md`, `UPSTREAM.sha256` | — | — | this fork's audit, grant, provenance and integrity records. These are this fork's own bytes, so no upstream blob names them |

All four digests above were recomputed from the working-tree files beside this
one and agree with what `UPSTREAM.sha256` records for them: three are among its
66 machine-checkable records (`:64`, `:66`, `:69`) and `LICENCE-UNICODE.txt`'s
is the one in the header comment (`:40`). Byte counts are given only for the
four whose bytes are fixed upstream; the other five are this fork's own
documents and their sizes move as they are edited, so a count recorded here
would be a count of a moment rather than of the record.

Three of the nine also install at the prefix root, so the licence directory is
the complete set rather than the only place to look: `LICENCE`,
`LICENCE-UNICODE.txt` and `README.upstream.md` each reach two paths from one
`b.installFile` call, and the other six reach one each.

`package.nix`'s install check asserts five of these paths by name —
`$out/LICENCE`, `$out/LICENCE-UNICODE.txt`, `$out/README.upstream.md`,
`$out/share/licenses/libunibreak/NOTICE.md` and
`$out/share/licenses/libunibreak/FORK-LICENSE.md` (`package.nix:120-124`). The
table above is the whole statement; that check is a sample of it.

## Cryptographic suitability

Not applicable, and stated so rather than left open: this is a text-segmentation
library. It computes line break opportunities, word boundaries and grapheme
cluster boundaries, and it ships no cipher, hash, key derivation, random number
generator or other security-relevant primitive. The one body of data it is built
around that could be mistaken for one — the seven checked-in UCD tables, several
of them megabyte-scale range tables — is public Unicode character data carried
under the terms above.
