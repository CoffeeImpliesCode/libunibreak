# README.zig.md — the `libunibreak` Zig package

A Zig 0.16.0 package that compiles **upstream's own C library** from `src/` in
this repository and publishes a Zig facade over its five public headers. Nothing
of the Unicode line, word or grapheme breaking algorithm is reimplemented, no
table is regenerated, no upstream source is patched, and nothing is downloaded at
build time.

| | |
|---|---|
| Upstream | [`adah1972/libunibreak`](UPSTREAM.md), tag `libunibreak_8_0`, commit `28a2756b864c343f438cd22537d49d394d4666a5` |
| Version of the C library built here | 8.0 (`src/unibreakbase.h`'s `UNIBREAK_VERSION 0x0800`) |
| Unicode revision of the data | 17.0.0 — UAX #14 Revision 55, UAX #29 Revision 47 |
| Module | `libunibreak` |
| Artifact | `unibreak`, which Zig writes as `libunibreak.a` |
| Package | `.libunibreak`, fingerprint `0xb4b2629221124f29` |
| Requires | Zig 0.16.0, a C99 compiler and libc. Nothing else. |
| Licence | zlib over upstream's code; the Unicode terms over the generated tables and fixtures; zlib over the files this fork writes. See [`NOTICE.md`](NOTICE.md) for the per-file audit of upstream's tree and [`FORK-LICENSE.md`](FORK-LICENSE.md) for the grant on this fork's own files |
| README | this file is the Zig interface documentation. [`README.md`](README.md) is the package README — deviations, delivery, status and consumption — and upstream's own README is [`README.upstream.md`](README.upstream.md), byte-identical to the pinned commit's blob |

The driver has run the native gates on this host: a build and install of the
source as it stands, together with the facade tests, the API exercise, the
example, the consumer package and **upstream's own conformance harness**
(`Build Summary: 23/23 steps succeeded; 15/15 tests passed`); the same tests,
example and consumer in `ReleaseSafe`, `ReleaseFast` and `ReleaseSmall`
(`13/13 steps succeeded; 15/15 tests passed` in each); the six-target
compile-only check (`43/43 steps succeeded`); an installed-C program compiled
against the installed headers and run against the installed archive; the
53-platform `cross-test` matrix; `sha256sum -c UPSTREAM.sha256`; this file's own
typed-API example, run as a program; and `zig fmt` over the nine fork-authored
Zig/ZON files. The filtered-fetch consumer and package integrity gate are
recorded **outside this package**, in
`local://foundation-matrix-final-package-proof.json`, and nothing here claims a
result for them; neither has CI or any linter run. Every row, with the receipt
that carries it, is
[Verification status](#verification-status); nothing is asserted here that no run
printed.

## Building it

```
zig build
```

installs:

* `zig-out/lib/libunibreak.a` — the static archive, upstream's own file name,
  built from the nine translation units of `src/Makefile.am`'s
  `libunibreak_la_SOURCES`;
* the five public headers under `zig-out/include/`, which are exactly
  upstream's `include_HEADERS`: `unibreakbase.h`, `unibreakdef.h`,
  `linebreak.h`, `graphemebreak.h`, `wordbreak.h`;
* `zig-out/LICENCE`, `zig-out/LICENCE-UNICODE.txt` and `zig-out/README.md` — a
  private repository removes no licence obligation, so the terms travel with
  what they cover.

It also compiles two programs — the example (`smoke.zig`) and the API exercise
(`zig/api_exercise.zig`) — and installs **neither**. The default install step
depends on each program's `Compile.step`, which is a compile dependency and not
an installation: there is no `installArtifact` and no `install exe` step for
either, and neither appears under `zig-out/bin/`. That is deliberate. Both are
proofs, not deliverables: the example is the cheapest thing that shows the
facade, the translated headers and the archive agree on types, symbols and
link-time dependencies, and the exercise is a standalone program that calls every
public facade method and every translated entry point once.

The other steps:

| Step | What it does |
|---|---|
| `zig build test` | runs the facade tests for the selected target, **and then the API exercise** — the test step depends on the exercise, so one command covers both |
| `zig build smoke` | runs the deterministic example |
| `zig build exercise` | runs `zig/api_exercise.zig`, a standalone program that calls every public facade method and every translated entry point once |
| `zig build upstream-test` | builds and runs **upstream's own unmodified `src/tests.c`** three times against the three Unicode fixtures, with `src/` as its working directory |
| `zig build consumer` | runs `zig build run -Dtarget=<triple> -Dcpu=<model+features> -Doptimize=<mode> -Dlinkage=<mode> -Druntime=<bool>` inside the separate `consumer/` package, with the selected executor flags, `-j8`, `--summary all`, both caches, the install prefix when the caller moved it, and `--` plus the caller's own arguments. The sub-command is `runConsumer`'s choice, not a fixed one: `run` when this host can execute the selected target — natively, or through an executor the build runner was told to use — and `install` when it cannot. An install is compile evidence and nothing more, never a consumer exchange |
| `zig build check` | compiles the C core, the facade, the exercise, the tests, the example and upstream's own harness for the six-target matrix, **running nothing**. Every facade body is instantiated, not merely declared |
| `cross-test` | the same `test` step, for the published 53-platform table. `cross-test.profile.sh` is settings only: no hooks, no matrix, no host paths. What a target without an executor means is the harness's word, not this package's |

`-Dtarget=<triple>` selects one target for `test`, `smoke`, `exercise`,
`upstream-test` and `consumer`; `check` with no `-Dtarget` is all six, and
`check -Dtarget=<triple>` is just that triple.

### Delivery modes

Two options change **how the library arrives**, not the interface: the types, the
methods and the conformance behaviour are the same either way.

| Option | Default | What it does |
|---|---|---|
| `-Dlinkage=static\|dynamic` | `static` | which artifact this build installs and links: `libunibreak.a`, or the shared object. `static` means a static *library artifact*; nothing in this package promises a wholly static executable |
| `-Druntime=true` | off | the facade stops linking the source library. The caller calls `load(.{ .path = … })` or `load(.{ .system = … })` once, and ordinary module calls follow. There is no fallback from an explicit path to a system name, no automatic retry, and an ordinary panic before the table is published — in `ReleaseFast` and `ReleaseSmall` too |

Under `-Druntime=true` the root also exports `load` and its source and
error types, and the native artifact is still built and installed: the option
changes how the symbols are reached, not whether the library exists.

Two symbol categories matter to a loaded image and are not interchangeable.
`unibreak_version` is `extern const int` — **data**, reached by address in the
loaded image and never called through the table. `ub_bsearch` is a C99 `inline`
definition closed by an `extern inline` external definition at
`src/unibreakdef.c:175`, which is what makes it an ordinary exported function
symbol at all; it is declared only in the internal header
`src/unibreakdef.h`, so it is not part of the public route, and dropping that one
line would make it a link error rather than a missing inline. [`README.md`](README.md)
§4d has the full table.

**`PENDING-VERIFICATION`.** Both options are this migration's delivery contract,
not a description of a build that has been observed; the pending gates are listed
under [Verification status](#verification-status) and in [`CHANGELOG.md`](CHANGELOG.md)
entry 28.

## Using it

**`dep.module("libunibreak")` is the whole dependency surface.** A consumer that
uses the module needs no `dep.artifact` at all: the archive and the translated
headers arrive with the module, and a second `linkLibrary` would put the same
archive on the link line twice.

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

A C caller, or a consumer that wants the archive itself, uses the artifact:

```zig
exe_mod.linkLibrary(dep.artifact("unibreak"));
```

which is the same archive a C program links as `-lunibreak`. The names differ
on purpose: `libunibreak` is the name a dependent writes in its dependency map
and the name of the one registered module, `unibreak` is the library's own name,
and Zig supplies the `lib` prefix and the platform suffix. That is upstream's
ABI identity, not an alias: `src/Makefile.gcc` and `libunibreak.pc.in` both name
the result `libunibreak`.

There is **no system-library mode**. This wave's contract keeps the source pin
and the bounded contracts identical in every mode, so there is no `-Dfsys=`
option, no `b.systemIntegrationOption`, and no claim about any system-installed
libunibreak. The rule that a system mode must translate the headers it links is
recorded as **NOT APPLICABLE** rather than satisfied: a distribution's
libunibreak is not this manifest's pinned 8.0 with this manifest's headers, and
translating these headers against it is exactly the header/ABI mismatch the
contract forbids (`WISDOM.md` W14).

## The two routes into the library

### The raw C route

`pub const c` re-exports the translated headers unchanged, as the `addTranslateC`
module named `c`. It is the **complete** upstream C API — every function declared
in any of the five public headers — with upstream's own signatures, upstream's
own struct layouts, upstream's own macros, and no hand-written re-declaration of
any of it anywhere in this package. `zig/translate.h` includes the five headers
and adds no declaration; a second, maintained copy of an ABI that the shipped
headers already state exactly could drift silently, so there is none.

Reach for it when you want something this facade does not cover, or when you are
portable C. The documentation for those declarations is **the headers
themselves**, shipped in `src/` and installed into `zig-out/include/`:

| Header | What it declares |
|---|---|
| `unibreakbase.h` | the UTF typedefs, `UNIBREAK_VERSION`, `extern const int unibreak_version` |
| `unibreakdef.h` | `EOS`, `get_next_char_t`, `ub_get_next_char_utf8/16/32`, `ub_bsearch`, `ARRAY_LEN` |
| `linebreak.h` | `set_linebreaks_utf8/16/32`, the two `*_per_code_point` forms, `is_line_breakable`, the five `LINEBREAK_*` opcodes, `init_linebreak` |
| `wordbreak.h` | `set_wordbreaks_utf8/16/32`, the three `WORDBREAK_*` opcodes, `init_wordbreak` |
| `graphemebreak.h` | `set_graphemebreaks_utf8/16/32`, the three `GRAPHEMEBREAK_*` opcodes, `init_graphemebreak` |

Two things to know before you call into it:

* **It validates nothing.** No decoder in `src/unibreakdef.c` checks its input.
  A lead byte outside `0xC2..0xF4` comes back as a one-byte "character";
  continuation bytes are masked with `0x3F` without being checked for;
  overlong forms and encoded surrogates are accepted; a truncated sequence
  yields `EOS` without advancing; an unpaired surrogate in UTF-16 is returned as
  the surrogate value itself; and UTF-32 returns any value at all. The only
  checks in the core are `assert(*ip <= len)` in the three decoders and
  `assert(0)` at `src/wordbreak.c:453`'s unreachable default, and `assert`
  vanishes under `NDEBUG`. **Validate before you call.**
* **`init_linebreak`, `init_wordbreak` and `init_graphemebreak` are empty
  bodies** kept for binary compatibility (`src/linebreak.c`, `src/wordbreak.c:63-65`,
  `src/graphemebreak.c:77-79`). They are not required initialisation and there
  is no state to initialise. They are available on the raw route because they
  are upstream's API; they are **omitted from the typed API** because there is
  nothing there to call.

### What a C caller actually gets

`zig build` installs the archive and the five public headers, and a C program
compiled with `zig cc` against that prefix links and runs. The installed-C gate
is the only one that exercises the **installed** bytes rather than a build-tree
artifact: it includes all five headers, links `-lunibreak`, and asserts real
answers from `set_linebreaks_utf32`, from the per-code-point form, from
`is_line_breakable`, from `set_wordbreaks_utf32` and from
`set_graphemebreaks_utf32`.

Its oracles are Unicode's rules, not this library's own output, and two of them
were wrong when the gate was first written:

* **LB7 forbids a break before a space; LB18 _allows_ one after it.** The first
  version asserted `LINEBREAK_MUSTBREAK` after the space, which is not what any
  rule of UAX #14 says there.
* **LB6 forbids a break _before_ a newline; the position _after_ it is
  `LINEBREAK_MUSTBREAK`.** The first version asserted `MUSTBREAK` before the
  newline, which is the position rule LB6 explicitly prohibits breaking at.
* The final position of text that does not end in an explicit break is
  `LINEBREAK_INDETERMINATE`, not `MUSTBREAK`.
* WB11 and WB12 keep `"1,1"` inside one word; GB9 forbids a break before a
  combining mark; GB1 puts the final position at the end of the last cluster.
* The empty-input check calls the **line** function only, because that is the
  native function which genuinely returns without writing. The grapheme
  function is deliberately not called with `len == 0`; see
  [What the output means](#what-the-output-means).

Two assertions that proved nothing were removed with them: a `expect(1)` that
compared a value with itself, and a check that pinned `unibreak_version` to a
constant. The version is now printed instead. Corrected, the program compiled
and ran to exit 0 against the installed prefix —
`local://foundation-matrix-libunibreak-installed-c-run-r1.log` first, and
`local://foundation-matrix-libunibreak-installed-c-current-run.log` for the
current source, whose receipt prints every check as `ok` and ends
`the installed C surface compiled, linked and ran`.

### The typed API

`zig/root.zig`. Allocation-free, no globals, no initialiser, and every promise it
makes is checked before the native call rather than after it.

```zig
const std = @import("std");
const libunibreak = @import("libunibreak");

pub fn main() !void {
    // "Hello, 世界" — nine code points, thirteen UTF-8 code units.
    const text = "Hello, \xe4\xb8\x96\xe7\x95\x8c";

    // Per code unit: the buffer is exactly one entry per input code unit, so
    // thirteen entries. Ten would be refused as OutputTooSmall.
    var out: [13]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit(text, null, &out);

    // Each entry sits at the *final* code unit of a code point. out[0] is the
    // break after 'H'; units 7, 8, 10 and 11 precede the final units of the
    // two three-byte code points and carry `inside_char`; out[12] is the final
    // position.
    //
    // Published answer, not a round trip: rule LB28 prohibits a break between
    // two alphabetic characters, and text that does not end in an explicit break
    // ends in `indeterminate` (`src/linebreak.c:1512-1515`).
    if (out[0] != .no_break or out[7] != .inside_char or out[12] != .indeterminate) {
        return error.UnexpectedLineBreaks;
    }

    for (out, 0..) |opcode, i| {
        std.debug.print("{d}: {s}\n", .{ i, @tagName(opcode) });
    }
}
```

Every method, by family:

| Family | Methods |
|---|---|
| `version()` | `pub fn version() c_int` — `UNIBREAK_VERSION` as the **linked archive** reports it, not a constant restated here |
| `Line` | `perCodeUnit(text: []const u8, lang: ?Language, out: []LineOpcode) Error!void`, `perCodeUnit16(units: []const u16, lang, out)`, `perCodeUnit32(units: []const u32, lang, out)`, `perCodePoint(text, lang, out) Error!usize`, `perCodePoint16(units, lang, out) Error!usize`, `breakBetween(first: CodePoint, second: CodePoint, lang) Error!LineOpcode` |
| `Word` | `perCodeUnit(text: []const u8, out: []WordOpcode) Error!void`, `perCodeUnit16`, `perCodeUnit32` |
| `Grapheme` | `perCodeUnit(text: []const u8, out: []GraphemeOpcode) Error!void`, `perCodeUnit16`, `perCodeUnit32` |

Plus the types `CodePoint` (`u32`), `Language` (`[:0]const u8`), the three
opcode enums, and `Error`.

**The element types are upstream's typedefs, not substitutes for them.**
`src/unibreakbase.h:45-50` defines `utf8_t`, `utf16_t` and `utf32_t` as
`unsigned char`, `unsigned short` and `unsigned int`, behind an
`UNIBREAK_UTF_TYPES_DEFINED` guard so that an embedding application which already
has those names keeps its own. Zig's `u8`, `u16` and `u32` are exactly those
widths, so `[]const u8`, `[]const u16` and `[]const u32` reach the native
functions as pointers with no cast and no reinterpretation, and the translated
module publishes the same three typedefs under upstream's names. The guard cuts
both ways: a C caller who defines its own `utf32_t` before including these
headers must make it an `unsigned int`-width type, because upstream neither
redefines nor checks it. And `utf16_t` is read as the machine's own byte order
(`ch = s[(*ip)++]` at `src/unibreakdef.c:132`), so the UTF-16 methods take
native-endianness code units, not big-endian ones.

There is deliberately **no `lang` parameter on `Word` and `Grapheme`.** Upstream
takes one on every entry point and ignores it: `src/wordbreak.c:169-170` is
literally a `/* TODO: Language-specific specialization. */ (void)lang;` and all
three grapheme entry points do `(void)lang`. A typed option that does nothing is
worse than no option, so the typed surface does not present one. The raw route
still exposes the parameter, because dropping it there would change upstream's
signature.

## What the output means

**Units.** Every native `set_*breaks_*` writes **one `char` per input code
unit**, so the output buffer is exactly `len` entries for the UTF-8, UTF-16 and
UTF-32 forms alike.

**Where a code point's opcode lands.** The break opcode of a code point is
written at the index of that code point's **final** code unit. Every code unit
*before* that final one — a lead byte and its continuation bytes — is
`inside_char`: that is the canonical spelling in this package's three enums, for
upstream's `LINEBREAK_INSIDEACHAR`, `WORDBREAK_INSIDEACHAR` and
`GRAPHEMEBREAK_INSIDEACHAR`. No opcode belongs to the *leading* unit of a code
point, and none is written for the unit *after* a code point either: the opcode
indexed at a code point's final unit is the break **between that code point and
the next one**. Read out of the three implementations, it is the same rule in
all of them: `src/linebreak.c:1459-1470` advances `posLast` to `posCur - 1` and
fills everything before it with `LINEBREAK_INSIDEACHAR`, `src/wordbreak.c:117-127`
does the same in `set_brks_to`, and `src/graphemebreak.c:162,212` initialises the
whole buffer to `GRAPHEMEBREAK_INSIDEACHAR` and then writes each rule's answer
at `posNext - 1`.

UTF-32 has exactly one code unit per code point, so there the two coincide and
`inside_char` never appears — not for a well-formed input and not for a
malformed one.

The last entry is the final position, after the last code point. The output
contains no position before the first code point; `Line.breakBetween` queries an
isolated pair instead.

**Typed empty-input calls leave the whole output unchanged**, and there is no
"position 0 of an empty string" to invent. `Line` and `Word` get that from
upstream: `set_linebreaks` returns before touching `brks`
(`src/linebreak.c:1450-1453`), and `set_wordbreaks` memsets zero bytes and then
ranges twice over an empty span (`src/wordbreak.c:173,177,463`).
**`Grapheme` does not** — see below.

**The final position is not always the same answer.** It is `must_break` when
the text ends in an explicit break and `indeterminate` otherwise
(`src/linebreak.c:1512-1515`). `LineOpcode.indeterminate` is a real fifth value
with **no counterpart in the Unicode test files**, which is why upstream's own
harness folds it into `must_break` before comparing against the oracle
(`src/tests.c:266-273`). That fold belongs to the comparison and nowhere else:
this package's enum keeps the two apart, and its own direct behavioural tests
check the difference.

**Empty input on the raw grapheme route is a real out-of-bounds write, not a
no-op.** `set_graphemebreaks` has no empty-length guard. It reads the first
character, gets `EOS` back with `posNext` still `0`, computes
`size_t brksPos = posNext - 1` (`src/graphemebreak.c:212`) — which wraps to
`SIZE_MAX` — and then writes `brks[brksPos]` (`src/graphemebreak.c:221`). In
pointer terms that is one byte **before** the caller's buffer. This was not a
theoretical reading: with the typed wrapper calling through, a
`Grapheme.perCodeUnit("", out)` aborted with

```
thread 41214 panic: addition of unsigned offset to 0x7ffc681153e5 overflowed to 0x7ffc681153e4
src/graphemebreak.c:221:27: 0x11ef354 in set_graphemebreaks (…/libunibreak/src/graphemebreak.c)
```

and the process exited on signal 6 (`local://foundation-matrix-empty-grapheme-before.log`;
Debug, native, 2026-10-03). The guard was then added to `Grapheme.perCodeUnit`,
`perCodeUnit16` and `perCodeUnit32`, which now return immediately for empty input
and leave the caller's bytes untouched; the same probe printed
`empty grapheme guard: before=inside_char output=no_break after=inside_char`
and exited 0 (`local://foundation-matrix-empty-grapheme-after.log`, same mode and
day). **Upstream's bytes are unchanged**: `src/graphemebreak.c` still carries no
guard and `UPSTREAM.sha256` still pins its digest, and the defect is recorded
here rather than patched. The consequence for a C caller is therefore stated
plainly and left with the caller: **on the raw route,
`set_graphemebreaks_utf8`, `set_graphemebreaks_utf16` and
`set_graphemebreaks_utf32` must not be called with `len == 0`.** The typed route
is the one that makes that call safe.

**The per-code-point forms.** `Line.perCodePoint` and `Line.perCodePoint16` are
native `set_linebreaks_utf8_per_code_point` and `set_linebreaks_utf16_per_code_point`
— the only two per-code-point entry points upstream has, because in UTF-32 the
two units are the same thing. They return the number of entries written, which
for well-formed input is the code point count. **Upstream never computes that
count for you**: it writes as many entries as there are code points and expects
the caller to have sized the buffer. Upstream's own harness sidesteps this by
over-allocating to the line length (`src/tests.c:186-196`). These wrappers solve
it properly — see below.

## Language tailoring, and `-strict`

`lang` is an ISO 639-1 code with an optional `-strict` suffix, and it affects
**line breaking only**. There are exactly three effects:

1. **Per-language class overrides** — six tables in `src/linebreakdef.c`, almost
   all of them reclassifying quotation marks. `zh` maps U+2018, U+2019, U+201C
   and U+201D to OP and CL.
2. **CJK resolution** — for `zh`, `ja` and `ko`, the class `AI` resolves to `ID`
   instead of `AL`.
3. **`-strict`** — `CJ` resolves to `NS` instead of `ID`. This is the UAX #14
   Conditional Japanese Starter tailoring, and it is the one place the typed
   language option changes an answer. Upstream's own harness passes `"-strict"`
   for its line tests and `""` for word and grapheme tests, and this package's
   conformance replay does the same.

**Matching is by prefix, not equality.** `is_lang_cjk` does
`strncmp(lang, "zh"/"ja"/"ko", 2)` and `get_lb_prop_lang` walks
`lb_prop_lang_map` with `strncmp(lang, entry->lang, entry->namelen)` over six
2-byte prefixes — `en`, `de`, `es`, `fr`, `ru`, `zh`. So `"zh-CN"` matches `zh`,
and so would `"zhx"`. That is upstream's behaviour and the typed API passes the
string through unchanged rather than pretending to be stricter. `null` and `""`
both mean no tailoring, and both are handled.

`Language` is `[:0]const u8` because upstream reads that argument with `strlen`,
`strncmp` and `memcmp`; a slice without a terminator is not a valid argument.
The slice is borrowed for the duration of the call and nothing is retained.

## Buffers, validation, and what a refusal leaves behind

**Caller buffers, always.** This library never allocates. Every method takes the
output buffer you provide and writes into it; there is no `allocator` argument
anywhere in the typed API and none in the C either (`doc/architecture.md` §1
states it, and the compiled core calls `memset`, `memcpy`, `strlen`, `strncmp`
and `memcmp` and nothing else).

**The validation scan, and what it costs.** The typed methods do two passes over
the input, and it is worth being exact about why:

* The **per-code-unit** methods (`perCodeUnit`, `perCodeUnit16`,
  `perCodeUnit32`) scan the input once to reject malformed encoding, then call
  the native function, which scans it again to decode and classify. **Two
  passes, and the first one is the price of the promise.**
* The **per-code-point** methods count the code points *in the same validation
  scan* — no second encoding walk — then check the capacity against that count
  and only then call the native function. So the validation pass is paid once and
  is not thrown away: it produces the very number the capacity check needs. That
  is the whole reason these two methods differ in shape, and it is what lets
  them offer a correct bound on a buffer whose size upstream never tells you.

If you already know your input is well-formed and you do not want the first pass,
the raw C route does exactly one scan. That is the trade, stated plainly: the
typed API buys a guarantee, and the guarantee costs a validation pass.

**The refusals.** `Error` is the complete set, and every one of them is a
condition this package checks itself:

| Error | Condition |
|---|---|
| `OutputTooSmall` | fewer entries than the per-code-unit method writes, or fewer than the code point count for a per-code-point one |
| `InputOutputOverlap` | the output buffer shares storage with the input text |
| `MalformedUtf8` | a continuation byte or an overlong two-byte lead in first position, a lead outside `0xC2..0xF4`, a missing continuation byte, a sequence cut short by end of input, an overlong form, an encoded surrogate, or a value above `U+10FFFF` |
| `MalformedUtf16` | an unpaired high surrogate, an unpaired low surrogate, or a high surrogate in the last position |
| `MalformedUtf32` | a surrogate code point, or a value above `U+10FFFF` |

`InputOutputOverlap` compares **byte ranges**: an output buffer that merely
touches the input — the output starting exactly where the input ends — does not
overlap and is accepted.

**Every refusal happens before any output byte is written, so there is no
partial result and no residue.** In every failure case the caller's buffer still
holds exactly the caller's own bytes; nothing is zeroed, nothing is half-filled,
and nothing needs to be discarded. That is a deliberate ordering — overlap,
capacity and encoding are all checked before the native call is made — not an
accident of the implementation.

**There is no error channel in the native library.** Every upstream function
returns `void`, a count, or a break opcode; nothing returns `NULL`, sets
`errno` or can fail. So `Error` describes **only** these Zig-side refusals, and
no entry in it describes a native failure.

## The conformance fixtures are the package's own oracle

`tests.zig` replays **every data row** of all three checked-in Unicode
conformance files, with no sampling and no skips:

| Fixture | Rows replayed | What each row is checked against |
|---|---|---|
| `src/LineBreakTest.txt` | **19 338** | all three encodings per code unit, per-unit markers, and both per-code-point forms; language `"-strict"` |
| `src/WordBreakTest.txt` | **1 944** | all three encodings per code unit |
| `src/GraphemeBreakTest.txt` | **766** | all three encodings per code unit |

Those row counts are asserted in the tests against the counts each file states in
its own footer (`# Lines: 19338`, `# Lines: 1944`, `# Lines: 766`), which is
what makes "the whole file" a checkable claim rather than an intention.

**The oracle is independent and the oracle is self-contained.** The expected
answers are Unicode's own, printed beside each row in the fixture — not a round
trip through this library's own code, which would prove only that the code agrees
with itself. And nothing is fetched to run them: `tests.zig` `@embedFile`s the
three fixtures from `src/`, at build time, from this repository. There is no
network dependency, no `testdata/` directory, and no duplicate copy of any
fixture anywhere in the package.

Upstream's own `src/tests.c` is compiled unmodified as `zig build upstream-test`
and run from `src/`, so upstream's view of these files is preserved rather than
replaced. Its three behaviours that a faithful replay has to keep — the
`"-strict"` language for line tests, the `ALLOWBREAK`/`INDETERMINATE` fold at
the oracle comparison only, and the per-code-unit indexing that leaves the
marker before the first code point out of the output — are described in
[`UPSTREAM.md`](UPSTREAM.md#the-conformance-fixtures).

**Both replays have now been observed on this host, in one run.** Upstream's own
unmodified `src/tests.c` ran three times — the `line`, `word` and `grapheme`
steps — and printed, for the three fixtures in `src/`:

```
LineBreakTest.txt: Passed 19338 out of 19338 (100%)
WordBreakTest.txt: Passed 1944 out of 1944 (100%)
GraphemeBreakTest.txt: Passed 766 out of 766 (100%)
```

(`local://foundation-matrix-libunibreak-current-debug.log`; Debug, native,
2026-10-03, exit 0 — the whole `zig build install test smoke consumer
upstream-test` command, whose summary is `23/23 steps succeeded; 15/15 tests
passed`. The same three figures were printed earlier by
`local://foundation-matrix-libunibreak-unicode-r5.log`, a command that as a
whole exited 1 because `zig/api_exercise.zig` did not compile at that moment; its
`upstream-test` step succeeded then too, and the exercise was fixed before the
next run.) The Zig replay is three of the fifteen facade tests, and those fifteen
passed in all four optimize modes.

## Unicode 17 here, Unicode 18 there — do not mix them up

This library is **Unicode 17.0.0**, UAX #14 Revision 55 and UAX #29 Revision 47.
The `utf8proc` package in the same workspace is **Unicode 18.0.0**. The two
therefore do not agree on grapheme clusters for text using characters or
properties that changed between 17.0 and 18.0, and comparing their answers to
each other is comparing two different standards. Nothing here claims that the two
packages produce identical results, and any test that assumed they would be
asserting a falsehood about one of them. The revision each package implements is
a property of that package and is recorded in its own provenance.

## Verification status

**Every row below is either a receipt, an explicit NOT RUN, or a gate this
package deliberately does not claim.** The driver ran the gates it ran on this
host on 2026-10-03; each observation names its receipt, its optimize mode and
its exit code, and no row claims a result no run printed.
The first table is the 2026-10-03 wave; the second carries what the driver has
run since, and every row in it names the epoch its receipt came from.
No linter was run on this package. The formatter was:
`zig fmt` over the nine fork-authored Zig/ZON files exited 0, and the receipt
names all nine files as the set it wrote
(`local://foundation-matrix-libunibreak-fork-zig-format.log`). That is an exit
code and a file list; it is not by itself a gate.

| Gate | Command | Status |
|---|---|---|
| Build, install, tests, exercise, example, consumer and upstream's harness — Debug, current source | `zig build install test smoke consumer upstream-test -j2 --prefix …/libunibreak/install-current --summary all` | **OBSERVED**, exit 0. `local://foundation-matrix-libunibreak-current-debug.log`. `Build Summary: 23/23 steps succeeded; 15/15 tests passed`. Installed `lib/libunibreak.a`, `include/` with the five public headers, `LICENCE`, `LICENCE-UNICODE.txt` and `README.md`; the example and the exercise are compiled, not installed |
| Tests, example and consumer — ReleaseSafe | `zig build test smoke consumer -Doptimize=ReleaseSafe --prefix …/install-ReleaseSafe --summary all` | **OBSERVED**, exit 0. `local://foundation-matrix-libunibreak-releasesafe-native.log`. `13/13 steps succeeded; 15/15 tests passed` |
| The same — ReleaseFast | `… -Doptimize=ReleaseFast --prefix …/install-ReleaseFast` | **OBSERVED**, exit 0. `local://foundation-matrix-libunibreak-releasefast-native.log`. `13/13 steps succeeded; 15/15 tests passed` |
| The same — ReleaseSmall | `… -Doptimize=ReleaseSmall --prefix …/install-ReleaseSmall` | **OBSERVED**, exit 0. `local://foundation-matrix-libunibreak-releasesmall-native.log`. `13/13 steps succeeded; 15/15 tests passed` |
| Upstream's own harness | `zig build upstream-test` | **OBSERVED** in the current Debug run, exit 0 for the command: three `src/tests.c` runs — `line`, `word`, `grapheme` — each printing its fixture at 100 % (`local://foundation-matrix-libunibreak-current-debug.log`). Not re-run in the three optimized modes |
| Six-target compile-only check | `zig build check -j2 --summary all` | **OBSERVED**, exit 0. `local://foundation-matrix-libunibreak-six-baseline.log`. `Build Summary: 43/43 steps succeeded`, compiling the archive, the facade, the exercise, the tests, the example and upstream's harness for `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`, `x86_64-windows-gnu`, `riscv64-linux-gnu` and `wasm32-wasi`, and running nothing |
| Installed C surface | `zig cc -std=c99 -I …/install-current/include …/libunibreak-installed-c-current.c …/install-current/lib/libunibreak.a`, then run the program | **OBSERVED**, compile exit 0 with empty output (`local://foundation-matrix-libunibreak-installed-c-current-compile.log`) and run exit 0 (`local://foundation-matrix-libunibreak-installed-c-current-run.log`), 2026-10-03. All five installed headers compiled; every check printed `ok` — LB7 before the space, LB18 after it, LB6 before the newline and mandatory after it, an indeterminate final position, UTF-16 and UTF-8 agreeing with UTF-32, the per-code-point count, the pair query, WB11/WB12, GB9/GB1, and an empty input leaving the buffer untouched — and ended `the installed C surface compiled, linked and ran` |
| Integrity of the pinned blobs | `sha256sum -c UPSTREAM.sha256` | **OBSERVED**, exit 0. `local://foundation-matrix-libunibreak-provenance-checksums.log`: 59 lines, every one `OK` |
| Upstream bytes against this working tree | comparison of the pinned blobs with the tree | **OBSERVED**. `local://foundation-matrix-source-integrity.json`: 67 files compared, one difference — `.gitignore`, which this fork appends to and which is deliberately outside `UPSTREAM.sha256` |
| The typed-API example in this file | `zig build run` over this README's example | **OBSERVED**, exit 0. `local://foundation-matrix-libunibreak-all-readme-examples-r1.log`: `6/6 steps succeeded`, and the example's own check passed before it printed indices 0–12 — `inside_char` at 7, 8, 10 and 11, `indeterminate` at 12 |
| Formatter | `zig fmt` over the nine fork-authored Zig/ZON files | **OBSERVED**, exit 0, the receipt names all nine files it wrote (`local://foundation-matrix-libunibreak-fork-zig-format.log`). Not a green gate by itself |
| Full cross-test matrix | `cross-test`, 53 platforms | **PARTIAL**, exit 0, `status: partial`. 53 of 53 targets built; **20 ran** the `test` step and each recorded 15 tests; **33 had no runtime** and are `build_only`, reason `runtime_unavailable`; **0 failed**. Summary: `local://foundation-matrix-libunibreak-cross-full-summary.json` |
| Filtered fetch, materialised consumer, package integrity | recorded outside this package | **Not claimed here.** The driver records this gate separately, in `local://foundation-matrix-final-package-proof.json`; only an observed receipt there establishes a pass, and none had been produced when this file was written |
| CI | `.github/workflows/verify.yml` | **NOT RUN** |

### Pending for this migration — `PENDING-VERIFICATION`

**Every row of the table above is historical.** Those receipts were taken on
2026-10-03, against the tree as it stood before this migration's shared and
runtime-loading delivery, its pkg-config metadata and its Nix/devenv packaging.
None of them is evidence for this migration, and each row below says in its own
Status cell whether it has run since.

| Gate | Command | Status |
|---|---|---|
| Static native output | `zig build install -Dlinkage=static`, in Debug, ReleaseSafe, ReleaseFast and ReleaseSmall | **PENDING-VERIFICATION** |
| Shared native output | `zig build install -Dlinkage=dynamic` in the same four modes, then read the exported symbols rather than trusting the file name | **PENDING-VERIFICATION** |
| The existing behavioural and fixture gates, on the migrated tree | `zig build test smoke consumer upstream-test`, Debug and ReleaseSafe | **PENDING-VERIFICATION** |
| Typed and raw consumers | `zig build check` | **PENDING-VERIFICATION** |
| The runtime-loaded route: startup, failure, retry, idempotence, provider change, atomic publication, and an ordinary panic before publication in `ReleaseFast` and `ReleaseSmall` | the `-Druntime=true` builds and the consumer checks | **PENDING-VERIFICATION** |
| Installed C consumer, including the new link metadata | `zig cc` against the installed prefix, and `pkg-config --cflags --libs libunibreak` against the Nix output | **PENDING-VERIFICATION** |
| Fetched, filtered Zig consumer | driver-owned; `local://foundation-matrix-final-package-proof.json` | **PENDING-VERIFICATION** |
| `devenv shell` and its tasks | canonical shell on the caller's scratch; `devenv tasks run sdk:gate` | **PENDING-VERIFICATION** |
| Packaged static and shared outputs | `devenv build outputs.static` / `outputs.shared`, or `nix build .#static` / `.#shared`; `nix-store --query --references` on each output | **PENDING-VERIFICATION** |
| Integrity after the README relocation and the `tools/` addition | `sha256sum -c UPSTREAM.sha256` | **PENDING-VERIFICATION** — the record now names `README.upstream.md` and holds 66 records; the 59 `OK` lines above were observed against the previous path and the previous record |
| The six baseline targets and the 53-platform matrix, on the current graph | `zig build check` for the six; `cross-test` for the fifty-three | **OBSERVED** on the current graph, twice, and neither is a runtime pass on its own. Cohort `20261004T221720228710Z-45046`, receipt `libunibreak-53-target-8.json`: **53 targets, 20 runtime PASS, 33 `build_only`, 0 failed**, driver exit 0, `source_unchanged: true`, `jobs_honoured: true`, and `raw_run_tests: 18` on each of the 20 that ran. Baseline `20261005T014547Z-797a73f2`, row `baseline-libunibreak-check`: compile-only whole-graph `check` over the six declared targets, `Build Summary: 43/43 steps succeeded`, exit 0, `failed: false`, `runtime_pass_claimed: false` — under every exit code that row derives no runtime result |
| This tree's own source linked into all eight configurations — the native route | `zig build test smoke install`, `{static, dynamic}` × `{Debug, ReleaseSafe, ReleaseFast, ReleaseSmall}`, no `-Druntime` | **OBSERVED**, partial, run `20261004T233628757747Z-69351`: **8 cells, every one `status: skipped-tests`**, exit 0, each `Build Summary: 31/31 steps succeeded; 18/20 tests passed (2 skipped)`. The two skips are `tests.zig:131` and `tests.zig:142`, both guarded `if (!libunibreak.runtime_loaded) return error.SkipZigTest;`. Those two cases exist only on the loaded route, so a linked cell cannot reach them and 18 is the ceiling there. This is not eight passes, and the two missing tests are not slow, filtered or failing |
| Own and external providers loaded into all eight configurations | `zig build test smoke install -Druntime=true`, two linkages × four optimize modes | **OBSERVED**, both. Own: **8/8** cells `status: pass`, exit 0, each `Build Summary: 32/32 steps succeeded; 20/20 tests passed`, `smoke success`, `test success`, `tests_skipped` 0, provider this tree's own `libunibreak.so.8.0.0` (run `20261004T232823091897Z-23133`) — 20 of 20 is real here, because the loaded route is the only one on which the two loader tests run. External `/lib64/libunibreak.so.5.0.1`: **0/8** cells, exit 1, each `Build Summary: 30/32 steps succeeded (1 failed); 17/20 tests passed (3 failed)` (run `20261004T233121760876Z-12541`) — `LineBreakTest.txt:35` position 0 got `no_break`, `WordBreakTest.txt:1059` position 0 got `allow_break`, `GraphemeBreakTest.txt:771` position 1 got `no_break`. **That 17/20 is three failing fixture rows against an external provider, not a defect in this SDK and not a partial success.** What was observed about that provider is its image path, its sha256, its file name and soname carrying `5.0.1` and `5`, and its `unibreak_version` word `0x0501`; this package is pinned to `0x0800` — Unicode 17.0, UAX #14 r55 and UAX #29 r47 — and the route probe prints that it makes no comparison. **The cause of the three failures is not established**: a soname is an ABI tag rather than a release number, and no external Unicode or UCD version was queried. No row here claims full compatibility with any external provider, claims that a table-version difference is what failed, or predicts what a provider matching this package's own pin would do: that run was not made. The boundary, the loader's own export arithmetic, and the narrower earlier probe are in [`CHANGELOG.md`](CHANGELOG.md) §45 |

The delivery contract those gates exercise — `-Dlinkage`, the link metadata, the
runtime route and the two symbol categories this library exports — is in
[`README.md`](README.md) §2 and §4d; the Nix and devenv entry points are in §5.

### One bounded observation — nested consumer delivery

One thing this table has since covered has been observed, in a run of its own,
and it is recorded here rather than by moving a row.

Nested delivery-proof run `20261004T220323250122Z-515d06adcbbf` recorded
**9/9 PASS** over `zig build consumer` and the `consumer/` package, covering all
four delivery routes a caller can ask for: static and dynamic delivery, each
linked and each runtime-loaded. Every route was exercised twice, once with the
selections omitted and once with `target`, backend, `linkage`, `runtime`, both
caches and the prefix named explicitly.

Three things in that run bear on what `runConsumer` and `consumer/build.zig`
were written to do, so they are named here rather than summarised away:

* The nested prefix relay's actual command line and the installed inventory
  agree, so the outer `--prefix` reaches the nested build.
* On the loaded routes the provider arrived through `--provider` on argv with
  every provider environment variable absent, so the program reads that argument
  and nothing else — there is no second handoff to be ambiguous with.
* The same run without a provider exited 1 and printed the refusal, so an absent
  provider is refused rather than resolved another way.

**What it does not cover.** Nine cases of the nested consumer build. It is not
evidence for the six baseline targets, the 53-platform matrix, the filtered
fetch, the packaged Nix outputs or the devenv tasks, and it does not move the
row for `zig build test smoke consumer upstream-test`, which also runs three
other steps in two optimize modes. Every other row of that table stays
`PENDING-VERIFICATION` unless it carries a receipt of its own.

Three wider route observations have since been made — eight linked cells, all
partial at 18 of 20; eight cells against this tree's own image, all passing at
20 of 20; eight cells against the external image `/lib64/libunibreak.so.5.0.1`, all
failing at 17 of 20 —
and the two loaded waves are in [`CHANGELOG.md`](CHANGELOG.md) §45 with the
boundary between them. None moves any other row, and the external provider's own
Unicode revisions are recorded nowhere, so none is claimed.

**What those receipts cover.** Every row of the observed table at the top of
this section was taken against the source as it stood on 2026-10-03, before this
migration's changes. The `Debug` row — the run that installs the archive, runs
the fifteen facade tests, the exercise, the example, the consumer package and
upstream's harness — produced the `…/install-current` prefix that the
installed-C receipts compiled against, so those two rows describe the same
bytes. The formatter ran last over those nine files; its exit code and file list
are recorded in its own row in that table, and nothing else in it is derived
from the formatter.

**The cross-test row is not a universal-runtime claim.** Thirty-three of the
fifty-three published platforms compiled and were never executed; a compiled
foreign test binary is `build_only`, not a pass, and this package does not count
one as one. Nothing here claims the library runs everywhere it compiles.

The six `check` targets are `x86_64-linux-gnu`, `aarch64-linux-gnu`,
`aarch64-macos-none`, `x86_64-windows-gnu`, `riscv64-linux-gnu` and
`wasm32-wasi`. None is dropped and none is `continue-on-error`.

Nothing in this file claims a result no run printed, and
`.github/workflows/verify.yml` runs the same gates on a runner without asserting
anything about them in advance.

## The example and the consumer

`smoke.zig` is the program behind `zig build smoke`. It takes one published row
per algorithm — `GraphemeBreakTest.txt` line 757 (four clusters, with the
regional-indicator pair that GB12 and GB13 hold together), `WordBreakTest.txt`
line 1729 (`÷ 0031 × 002C × 0030 ÷` — "1,0" is one word, by WB11 and WB12) and
`LineBreakTest.txt` line 28 (`× 2757 × 0020 ÷ 2757 ÷` — the two marks are on
different lines, by LB7) — and asserts each against Unicode's own published
answer, written out as a literal keyed by its fixture line rather than read
back from the fixture. It also runs the line case twice, once with `"-strict"`
and once without. Nothing below its first two printed lines depends on timing,
on a locale or on an environment variable: those lines are this package's own
assertions against literals keyed by fixture line, and a change in one is a
change in behaviour.

The first two lines are not configuration-independent and are not claimed to be.
In a linked build the version line reads the linked library and the second line
names the linked route, and both are then identical on every host, because
nothing is read from the environment. Under `-Druntime=true` the version line is
whatever the provider named by `--provider` or `LIBUNIBREAK_TEST_PROVIDER`
reported, the second line names the runtime-loaded route, and a run told neither
fails before printing anything. So the part of the output a reader may diff
across hosts and configurations is everything after those two lines.

Observed on this host in all four optimize modes: the run prints
`every published expectation for these rows was reproduced` and the build step
`smoke success` — for instance `local://foundation-matrix-libunibreak-current-debug.log`
(Debug, current source), `…-releasesafe-native.log`, `…-releasesmall-native.log`
and `…-releasefast-native.log`, and earlier
`local://foundation-matrix-libunibreak-unicode-r7.log`.

`consumer/` is a separate package (`.libunibreak_consumer`, fingerprint
`0x1e87b0d3decd683e`) that depends on this one **by relative path** and reaches
it through `dep.module("libunibreak")` only — no `dep.artifact`, because a second
link would prove nothing. It exercises the three families over all three
encodings and then the four refusals, asserting that a refused call leaves the
caller's buffer holding the caller's own bytes. It exists to prove the published
module resolves from a package that did not write it; resolving that through a
network fetch would make the proof depend on a published state of the world
instead of on this tree.

It has run on this host in all four optimize modes — `consumer package success`
in `local://foundation-matrix-libunibreak-current-debug.log` (Debug, current
source) and the three optimized receipts, and earlier
`local://foundation-matrix-libunibreak-unicode-r7.log` — printing the library
version, one worked case per family over UTF-8, UTF-16 and UTF-32, and the four
refusals with the buffer counts that stayed untouched. `zig build consumer` is
always `zig build run` for the selected `-Dtarget` and `-Doptimize` inside
`consumer/`; it never falls back to building for the host, to an installed
prefix, or to an install step when a target cannot run, because a substituted
build would prove something else.

`runConsumer` in `build.zig` builds that nested command line, and what it hands
over is the whole of what the run then reports:

* **Selections.** `-Dtarget` from the triple and `-Dcpu` from the CPU query
  beside it, because a triple cannot carry a model or a feature set. Then
  `-Doptimize`, `-Dlinkage` and `-Druntime`. The executor flags travel too —
  `-fdarling`, `-fqemu`, `-frosetta`, `-fwasmtime`, `-fwine` and
  `--libc-runtimes` — and each one only when this build selected it, so a native
  run names none of them.
* **Both caches.** `--cache-dir` with a `/consumer` subdirectory, because the
  local cache holds this graph's manifest directory and is locked for the life of
  the process holding it. `--global-cache-dir` verbatim and with no subdirectory,
  because the global cache holds content-addressed package directories that are
  meant to be shared between builds. `cache_root` is on `Build` and
  `global_cache_root` is on `Graph`, so `b.global_cache_root` does not exist.
* **Width and summary.** `-j8` and `--summary all`, so the nested build cannot
  derive its own width from the host's core count and a passing consumer prints
  its steps rather than nothing.
* **The outer prefix.** `--prefix` only when the caller moved
  `b.install_prefix` off this build root's default `zig-out`, and a relative
  prefix is made absolute against `b.graph.cache.cwd` first, because the nested
  build's own working directory is `consumer/`. A dependency's install prefix is
  chosen by the build system and by neither caller, so `--prefix` is what
  carries the outer decision and there was never a second answer to give.
* **The caller's arguments, on both hops.** `runConsumer` appends `--` and
  `b.args` to the nested `zig build run`, and `consumer/build.zig` appends its own
  `b.args` to the program's `run_exe`, because a `Step.Run` does not forward
  them itself. `zig build consumer -- --provider <path>` therefore reaches the
  program.

## What is in this package

| Path | What it is |
|---|---|
| `src/` | upstream's C library, byte-identical: nine translation units, five public and seven internal headers, seven generated UCD tables, upstream's own `tests.c` and `test_skips.h`, the generators, and the three conformance fixtures |
| `doc/architecture.md` | upstream's design documentation, including two claims that are stale against the 8.0 source — recorded, not edited |
| `zig/root.zig` | the typed facade |
| `zig/api_exercise.zig` | every public facade method and every translated entry point, instantiated once |
| `zig/translate.h` | the one header `addTranslateC` translates |
| `tests.zig`, `smoke.zig` | the test root and the example |
| `runtime/` | the route `-Druntime=true` builds into the module: `graph.zig` substitutes the generated dispatch for `translate.createModule()`, `loader.zig` is the loader core, `library.zig` this SDK's descriptor of the namespaced bindings, `generate.zig` the host program that writes the dispatch from the real translation output, and `sync.c` the C synchronization helper compiled into the dispatch with `-DRT_SYNC_PREFIX=libunibreak_rt` |
| `consumer/` | a separate package that consumes this one |
| `build.zig`, `build.zig.zon`, `cross-test.profile.sh` | the build, the manifest and the harness settings |
| `LICENCE`, `LICENCE-UNICODE.txt`, `NOTICE.md`, `FORK-LICENSE.md`, `UPSTREAM.md`, `UPSTREAM.sha256` | the licence and provenance records |
| `README.md`, `README.upstream.md` | the package README (this fork's) and upstream's README, carried byte-identical |
| `package.nix`, `flake.nix`, `flake.lock`, `devenv.nix`, `devenv.yaml`, `.envrc` | the standalone Nix derivation, the flake that pins it, the lock that records the flake's inputs, and the canonical development shell |
| `tools/` | upstream's six example programs and its own `tools/test.txt` — carried, byte-identical and compiled by nothing here. The install step reads `tools/test.txt` (`b.installFile("tools/test.txt", …)` in `build.zig`) and puts it at `share/libunibreak/test.txt`, which is the whole reason the directory is in `.paths`; `tools/linebreak_test.c`'s reach for `<iconv.h>` is still why no step builds it. [`FORK-NOTES.md`](FORK-NOTES.md) §27 |

**This table is the working tree, and `.paths` is the package.** Every path above
is named in `build.zig.zon`'s `.paths` except `.gitignore`, which is upstream's
43 lines with this fork's Zig block appended and so is not the file upstream
shipped. One file that is neither above nor named is `devenv.lock`: it does not
exist in this tree, a `.paths` entry that is not there fails the fetch that reads
it, and no empty file stands in for it. The Nix and devenv entry points are
listed one by one for that same reason — they travel, so a dependent who fetches
this package reaches the same `nix build` and `devenv` routes this file
advertises. Everything the install step reads is inside `.paths` as well:
`FORK-LICENSE.md` and `tools/test.txt` were the two that were not, and a fetched
copy without either would have failed `zig build install` on a file this tree has
always had ([`CHANGELOG.md`](CHANGELOG.md) entries 31 and 33).

## Provenance and licence

* [`UPSTREAM.md`](UPSTREAM.md) — the pin, the archive receipt, exactly what is
  compiled and in what order, the include closure, the fixture audit, the two
  stale upstream documentation claims, and why this library was selected.
* [`UPSTREAM.sha256`](UPSTREAM.sha256) — 66 per-file digests: 59 derived from the
  pinned commit's blobs on 2026-10-03, plus the seven `tools/` files added
  2026-10-04, each read again from the working tree and in agreement, with no
  new pinned-object comparison run for them. Check with
  `sha256sum -c UPSTREAM.sha256`, which was run on this host at exit 0 with 59
  `OK` lines against the earlier 59-record file
  (`local://foundation-matrix-libunibreak-provenance-checksums.log`) and has not
  been re-run since.
* [`NOTICE.md`](NOTICE.md) — the per-file licence audit of all 67 upstream
  blobs, including the ten Unicode files that the Zlib grant does not reach,
  `tools/linebreak_test.c`'s separate broad grant, the five `tools/` programs
  with no notice at all, and the inventory of the files this fork writes.
* [`FORK-LICENSE.md`](FORK-LICENSE.md) — the grant over the files this fork writes
  (Zlib, SPDX `Zlib`), the owner's authorization behind it, what it does **not**
  reach, the SPDX identifier newly authored files carry, and where the licence
  material is installed. The earlier statement that this fork's files asserted no
  licence described the state before that authorization and is superseded by it.
* [`FORK-NOTES.md`](FORK-NOTES.md) — the problems met and what was decided.
* [`CHANGELOG.md`](CHANGELOG.md) — numbered fork-only divergences.
