//! libunibreak, the Unicode line, word and grapheme breaking library, packaged
//! for Zig.
//!
//! The three algorithms are not reimplemented here. Every opcode in the output
//! comes out of the unmodified upstream C in `src/`, reached through `c`, the
//! module `b.addTranslateC` produces over `zig/translate.h`. What this module
//! adds is the part a C header cannot express: caller-owned buffers sized in
//! the unit the native function actually writes, checks that happen *before* a
//! call into C rather than inside it, an honest error for each refusal this
//! package establishes itself, and the five line break opcodes kept apart
//! instead of collapsed.
//!
//! ## Routes
//!
//! The supported import is the package module, `dep.module("libunibreak")`.
//! `libunibreak.c` is the supported raw escape hatch: it is this module's
//! translated header, re-exported unchanged, and it is where the five upstream
//! public headers are documented. For a C caller the product is the static
//! archive and `unibreakbase.h`, `unibreakdef.h`, `linebreak.h`,
//! `wordbreak.h` and `graphemebreak.h`.
//!
//! ## What the native library does not do, and what this module therefore owns
//!
//! Upstream validates **nothing**. `ub_get_next_char_utf8`
//! (`src/unibreakdef.c:66-70`) returns a byte outside `0xC2..0xF4` as a
//! one-unit "character" without an error and masks continuation bytes with
//! `0x3F`; `ub_get_next_char_utf16` (`:143-146`) returns an unpaired high
//! surrogate as itself; `ub_get_next_char_utf32` (`:172`) returns any `utf32_t`
//! verbatim. Upstream also allocates nothing, keeps no mutable global state and
//! reports no failure: every public function returns `void`, a count, or an
//! opcode.
//!
//! ## Two configurations: linked and runtime-loaded
//!
//! This module is built in one of two shapes, and `runtime_loaded` says which
//! at comptime.
//!
//! *Linked* is the default. The C library is linked, `c` is the translated
//! header, and every call below is a direct call with no table and no check.
//!
//! *Runtime-loaded* is opt-in (`-Druntime=true`). The library is not linked; `c`
//! is a dispatch generated from that same translation step's output, and the
//! nineteen names the five headers declare — eighteen functions and the
//! `unibreak_version` data object — are resolved through the platform loader
//! when the caller calls
//!
//! ```zig
//! try libunibreak.load(.{ .path = "/usr/lib/libunibreak.so.8" });
//! ```
//!
//! before using anything else. A call into a module that has not loaded stops
//! the program with a message naming the function or the data object, in every
//! optimization mode including `ReleaseFast` and `ReleaseSmall`. That is a
//! programming error rather than a recoverable condition: the table does not
//! exist yet and there is no partial state to fall back on. The load itself
//! reports a missing file, a provider that does not export what the header
//! declares, a request that cannot be honoured because a different provider
//! already won, or a reentrant call, as errors rather than as a different
//! library being loaded instead.
//!
//! The provider is reached, never guessed. `.path` names a file and `.system`
//! names a library for the platform loader; neither falls back to the other,
//! there is no unload and no reset, and the handle and its own copy of the
//! request live to the end of the process. What a provider must be is stated in
//! `runtime/library.zig`.
//!
//! One thing is reached differently in the two configurations and it is worth
//! naming: [version] reads `unibreak_version`. In a linked build that is a
//! direct read of the linked data object. In a runtime-loaded one it is a
//! dereference of the address `load` resolved, held live by the dispatch table,
//! so the value a caller sees is the loaded image's own storage and not a copy
//! of it. Both are the same read of the same object; only the route differs.
//!
//! So the whole error taxonomy below is this package's own. Every method checks
//! its arguments *before* the native call and returns before a single output
//! byte is written, so a rejected call leaves `out` exactly as the caller passed
//! it. The native functions have no error channel and none is invented for them.
//!
//! ## Units
//!
//! Two different units meet in this API and conflating them is the classic
//! mistake, so each method says which one it writes:
//!
//!   * `perCodeUnit` methods write **one opcode per input code unit**. The
//!     buffer must therefore hold at least `text.len` entries — the byte count
//!     for UTF-8, the `u16` count for UTF-16, the `u32` count for UTF-32 — and
//!     earlier units of a multi-unit code point are marked `inside_char`; the
//!     final unit carries the opcode for the following break.
//!   * `perCodePoint` methods write **one opcode per code point**, so the
//!     buffer must hold at least the code point count. Upstream never computes
//!     that count for the caller; upstream's own harness
//!     (`src/tests.c:188-190`) over-allocates to the input length instead. This
//!     module counts and validates in one scan and then checks capacity, so the
//!     bound is the real one.
//!
//! ## Residue
//!
//! A method writes exactly the prefix documented for it and nothing else:
//!
//!   * per code unit: `out[0..text.len]`, or nothing at all when `text` is
//!     empty (`src/linebreak.c:1450-1453` returns before touching `brks`);
//!   * per code point: `out[0..count]` where `count` is the returned value.
//!
//! Entries past that prefix keep whatever the caller had put there, including
//! on a call that returns an error.
//!
//! ## Language tailoring
//!
//! Only line breaking is tailored. `lang` is an ISO 639-1 code with an optional
//! `-strict` suffix, passed as an optional borrowed sentinel slice; `null`
//! hands C a `NULL` and means no tailoring, exactly like `""`.
//!
//! Matching is **prefix, not equality**, read out of the source: `is_lang_cjk`
//! (`src/linebreak.c:456-466`) compares two bytes, and `get_lb_prop_lang`
//! (`:559-573`) walks `lb_prop_lang_map` (`src/linebreakdef.c:120-128`) with
//! `strncmp(lang, entry->lang, entry->namelen)` over six two-byte prefixes —
//! `en`, `de`, `es`, `fr`, `ru`, `zh`. So `"zh-CN"` selects Chinese, and so
//! does `"zhx"`. `-strict` is recognised as a **suffix** of the whole string
//! (`ends_with`, `:436-454`), so it composes with any of those prefixes.
//! Word and grapheme breaking take no language at all: upstream's `lang`
//! parameters are ignored (`src/wordbreak.c:169-170` and the three
//! `(void)lang;` in `src/graphemebreak.c`), and a typed option that did nothing
//! would be a lie about behaviour rather than a thinner wrapper.
//!
//! ## Unicode revision
//!
//! This library is Unicode 17.0.0 — UAX #14 revision 55 and UAX #29 revision 47
//! (`src/linebreak.h:33-34`, `src/graphemebreak.h:31-32`). The `utf8proc`
//! package in this workspace is Unicode 18.0.0. The two therefore do **not**
//! agree on every grapheme: where Unicode 18 changed a rule or a property, this
//! library answers the Unicode 17 question. `UNIBREAK_LAZY_INCB` keeps its
//! upstream default of `0` (`src/graphemebreak.c:57-63`).
//!
//! ## Lifetimes and cost
//!
//! Every method borrows its arguments for the duration of the call and retains
//! nothing: no object survives a call, there is no `deinit`, no handle and no
//! allocator. Nothing here allocates, copies or caches — the text is read in
//! place and the opcodes are written straight into the caller's buffer. A
//! per-code-unit method is a single validating scan plus one native pass; a
//! per-code-point method is a single validating scan that also counts, then one
//! native pass, so it costs one extra linear scan over the input and nothing
//! else.
//!
//! ## Threads
//!
//! The native core has no mutable global state, no thread-local state, no atomics
//! and no I/O, and neither does this module. Every call is independent and every
//! call is reentrant: concurrent calls from any number of threads are safe
//! provided they write to disjoint output buffers.
const std = @import("std");

/// The translated upstream headers, re-exported unchanged.
///
/// This is the raw route: every declaration of `unibreakbase.h`,
/// `unibreakdef.h`, `linebreak.h`, `wordbreak.h` and `graphemebreak.h` is
/// reachable here, together with the three empty compatibility entry points
/// `init_linebreak`, `init_wordbreak` and `init_graphemebreak`
/// (`src/linebreak.c:548-550`, `src/wordbreak.c:63-65`,
/// `src/graphemebreak.c:77-79`). Those three have empty bodies upstream and are
/// deliberately **not** given a typed spelling here: a caller must never have to
/// believe initialisation is required, and a typed no-op would invite exactly
/// that belief.
///
/// The types here are upstream's own: `c.utf8_t`, `c.utf16_t`, `c.utf32_t`,
/// the `char`-typed break buffers and the `int` return of
/// `c.is_line_breakable`. A caller reaching this route owns everything a C
/// header says, including the requirement to size the buffer itself.
///
/// That is eighteen functions and one data object, and it is the *whole* of what
/// this package needs from the native library — not the subset the typed facade
/// happens to call. `ub_get_next_char_utf8`, `ub_get_next_char_utf16` and
/// `ub_get_next_char_utf32` are here for the same reason the `set_*` functions
/// are, and [Decode] below is the typed spelling of those three.
///
/// In a runtime-loading build this module is a generated dispatch instead of the
/// translation step's own output. It publishes the same namespace: every type
/// and constant is re-exported from the translated header rather than restated,
/// so `c.LINEBREAK_MUSTBREAK` is the same nominal value either way and the three
/// opcode enums below need no cast. What differs is how a name reaches the
/// library. In the linked configuration it is a direct call; in the
/// runtime-loaded one it is a call through a table that `load` fills, and a call
/// before that fill stops the program with a message naming the function. The
/// one name that is reached differently rather than called is the data object:
/// the dispatch keeps its **address** and publishes `unibreak_versionAddr()`,
/// because a copy of a data object's bytes is not the object. `runtime_loaded`
/// says which configuration this is, at comptime.
pub const c = @import("c");

/// The loader core, which is where a linked build's two public types come from.
///
/// It is imported only by the linked configuration. In a runtime-loading build
/// the dispatch carries its own copy of the same declarations, and this module is
/// never referenced, so it is never resolved and never compiled. Either way
/// there is exactly one `LoadSource` and one `LoadError` in a build, which is
/// what keeps them one type for a consumer that names them.
const rt = @import("rt");

/// Whether this module was configured to resolve its native symbols at run
/// time.
///
/// False for the ordinary build, where the C library is linked and `c` is the
/// translated header itself. True when the build generated a dispatch that
/// resolves the same symbols through the platform loader, in which case `load`
/// is the call that makes the library usable.
///
/// It is a comptime constant, so a consumer can write two different code paths
/// and have only the one it chose analyzed.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Which native library `load` should open.
///
/// `.path` is an explicit file path and `.system` is an explicit name for the
/// platform loader. There is no path-to-system fallback and no implicit fallback
/// of any kind; a request that cannot be honoured is an error, not a different
/// library.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Every way `load` can decline.
///
/// Declared here, in the module a consumer imports, rather than only inside the
/// loader: the caller names the failure it is handling.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Load the native library this module dispatches to.
///
/// In a runtime-loading build this is the whole contract: call it once, then use
/// this module as if it were linked. Calling it again with the same request
/// succeeds and changes nothing; calling it with a different request after a
/// success is `ProviderMismatch`, and the library already in use stays in use. A
/// failed attempt publishes nothing and can be retried explicitly, by calling
/// this again: there is no automatic retry, and no implicit second source.
///
/// It keeps the process handle and its own copy of the request to the end of the
/// process. There is no unload and no reset, because the table is process-global
/// state that other code may already have called through.
///
/// Safe to call from any thread. A thread that arrives while an attempt for the
/// same request is in flight waits for that attempt and gets its result, whatever
/// it was. A call from the thread that is running the attempt is
/// `ReentrantLoad` rather than a deadlock.
///
/// In a linked build there is no provider, no table and nothing to resolve, so
/// this stops the program with a message saying so instead of quietly succeeding.
/// `runtime_loaded` is false there, so a consumer that supports both
/// configurations can tell the two apart at comptime instead of meeting this at
/// run time.
pub fn load(source: LoadSource) LoadError!void {
    if (comptime !runtime_loaded) {
        std.debug.panic(
            "libunibreak: load was called on a linked build; this module is not " ++
                "runtime-loaded, so there is no library to load. Build with " ++
                "-Druntime=true, or do not call load.",
            .{},
        );
    }
    return c.load(source);
}

/// The request that succeeded, or null when nothing has loaded yet.
///
/// The answer is the loader's own retained copy and stays valid for the life of
/// the process. Null in a linked build, which has no request.
pub fn loadedSource() ?LoadSource {
    if (comptime !runtime_loaded) return null;
    return c.loadedSource();
}

/// The address of the provider's own `unibreak_version` object, or null when
/// this is a linked build.
///
/// In a runtime-loading build this is the loaded image's storage, not a copy of
/// it: the dispatch resolves the symbol once and hands back the address it
/// resolved, so a caller that reads through this pointer reads what the provider
/// holds right now. `version` is the way most callers want it, and this is
/// published for the one case that needs the address itself — comparing it, or
/// keeping it across a call that might load something else. It is null in a
/// linked build, where the object is reached directly through `c` and there is
/// no table to ask.
pub fn versionPointer() ?*const c_int {
    if (comptime !runtime_loaded) return null;
    return c.unibreak_versionAddr();
}

/// A Unicode scalar value, as `utf32_t` is `unsigned int`
/// (`src/unibreakbase.h:48`).
pub const CodePoint = u32;

/// `UNIBREAK_VERSION` as the library reports it at run time.
///
/// `src/unibreakbase.h:42-43` declares `extern const int unibreak_version`, so
/// this reads the value the linked archive was compiled with rather than a
/// constant restated here. Which upstream release that is belongs to the
/// package's provenance record, not to this accessor.
///
/// In a runtime-loading build the read is a dereference of the address the
/// loader resolved (see [versionPointer]), so it is the loaded image's own
/// storage and not a copy of the value that was there when `load` ran. In a
/// linked build it is a direct read of the linked object. Either way it is a
/// read of the object and not a value this module kept.
pub fn version() c_int {
    if (comptime runtime_loaded) return c.unibreak_versionAddr().*;
    return c.unibreak_version;
}

// ---------------------------------------------------------------------------
// Opcodes. All three enums are one byte wide because every native entry point
// writes a `char`, and every value is read out of the upstream macro of the
// same name rather than written down a second time.
// ---------------------------------------------------------------------------

/// One `char` of a `brks` buffer written by `set_linebreaks*`.
///
/// `src/linebreak.h:59-63` defines the five values. All five are preserved:
/// `indeterminate` has no counterpart in the Unicode test files and upstream's
/// own harness folds it into `mustBreak` (`src/tests.c:266-273`) purely because
/// the oracle cannot express it. That fold belongs to the comparison against the
/// oracle and nowhere else; this enum keeps the two apart so a caller can see
/// which one it got.
pub const LineOpcode = enum(u8) {
    /// `LINEBREAK_MUSTBREAK`. A mandatory break, written by rule LB4/LB5/LB6
    /// and by the final position of text that ends in an explicit break.
    must_break = c.LINEBREAK_MUSTBREAK,
    /// `LINEBREAK_ALLOWBREAK`. A permitted break opportunity.
    allow_break = c.LINEBREAK_ALLOWBREAK,
    /// `LINEBREAK_NOBREAK`. A position where UAX #14 prohibits a break.
    no_break = c.LINEBREAK_NOBREAK,
    /// `LINEBREAK_INSIDEACHAR`. A unit before the final unit of a code point.
    /// The final unit carries the following break. The raw C route also uses
    /// this marker for truncated input; the typed route rejects malformed UTF.
    inside_char = c.LINEBREAK_INSIDEACHAR,
    /// `LINEBREAK_INDETERMINATE`. The final position of text that does not end
    /// in an explicit break (`src/linebreak.c:1512-1515`). Distinct from
    /// `must_break`, which is what an explicit break leaves there.
    indeterminate = c.LINEBREAK_INDETERMINATE,
};

/// One `char` of a `brks` buffer written by `set_wordbreaks*`.
///
/// `src/wordbreak.h:60-62`. This is a different vocabulary from [LineOpcode]
/// with different numbers: `allow_break` is `0` here and `1` in line breaking.
/// The two enums are separate types so neither can be used where the other
/// belongs.
pub const WordOpcode = enum(u8) {
    /// `WORDBREAK_BREAK`. A word boundary.
    allow_break = c.WORDBREAK_BREAK,
    /// `WORDBREAK_NOBREAK`. Inside a word.
    no_break = c.WORDBREAK_NOBREAK,
    /// `WORDBREAK_INSIDEACHAR`. The code unit continues a code point started
    /// earlier.
    inside_char = c.WORDBREAK_INSIDEACHAR,
};

/// One `char` of a `brks` buffer written by `set_graphemebreaks*`.
///
/// `src/graphemebreak.h:57-59`. A separate vocabulary again, kept as its own
/// type rather than shared with the word opcodes.
pub const GraphemeOpcode = enum(u8) {
    /// `GRAPHEMEBREAK_BREAK`. Between two extended grapheme clusters.
    allow_break = c.GRAPHEMEBREAK_BREAK,
    /// `GRAPHEMEBREAK_NOBREAK`. Inside one extended grapheme cluster.
    no_break = c.GRAPHEMEBREAK_NOBREAK,
    /// `GRAPHEMEBREAK_INSIDEACHAR`. The code unit continues a code point started
    /// earlier.
    inside_char = c.GRAPHEMEBREAK_INSIDEACHAR,
};

/// A borrowed NUL-terminated language tag for line breaking.
///
/// The sentinel is load-bearing, not decoration: upstream's `lang` is a C
/// string, read with `strlen`, `strncmp` and `memcmp`
/// (`src/linebreak.c:436-466`, `:559-573`), so a slice with no terminator is
/// not a valid argument. The slice is borrowed for the duration of the call and
/// nothing is retained.
///
/// `null` selects no tailoring, which is the same as `""`.
///
/// See the module documentation's "Language tailoring" section for the prefix
/// matching this type inherits from upstream.
pub const Language = [:0]const u8;

/// Every refusal this package can report.
///
/// Each entry is a condition established here, checked before the native call
/// and before any output byte is written. Upstream has no error channel at all,
/// so nothing in this set describes a native failure.
pub const Error = error{
    /// The output buffer cannot hold what the method writes: too few entries
    /// for the per-code-unit methods, fewer than the code point count for the
    /// per-code-point ones.
    ///
    /// The bound is this package's own. Upstream takes a raw `char *` and
    /// writes past it without looking.
    OutputTooSmall,
    /// The caller's output buffer shares storage with the input text, so
    /// writing an opcode would overwrite a code unit the native pass has not
    /// read yet. Refused rather than executed in either order.
    ///
    /// Byte ranges that merely touch — the output starting exactly where the
    /// input ends — do not overlap and are accepted.
    InputOutputOverlap,
    /// The input is not well-formed UTF-8: a continuation byte or an overlong
    /// two-byte lead in first position, a lead outside `0xC2..0xF4`, a missing
    /// continuation byte, a sequence cut short by the end of input, an overlong
    /// form, an encoded surrogate, or a value above `U+10FFFF`.
    ///
    /// Upstream accepts all of these silently (`src/unibreakdef.c:66-104`).
    MalformedUtf8,
    /// The input is not well-formed UTF-16: an unpaired high surrogate, an
    /// unpaired low surrogate, or a high surrogate in the last position with no
    /// low surrogate behind it.
    ///
    /// Upstream returns the surrogate value itself in every one of those cases
    /// (`src/unibreakdef.c:134-146`).
    MalformedUtf16,
    /// The input is not well-formed UTF-32: a surrogate code point, or a value
    /// above `U+10FFFF`.
    ///
    /// Upstream returns such a `utf32_t` verbatim (`src/unibreakdef.c:172`).
    MalformedUtf32,
    /// A decode was asked to start past the end of its input.
    ///
    /// `src/unibreakdef.c:59,127,167` each begin with `assert(*ip <= len)`.
    /// `assert` is removed by `NDEBUG`, which this package's own four optimize
    /// modes set in the two release ones, so an out-of-range index is not a
    /// diagnostic at all in a release build — it is a read of whatever follows
    /// the buffer. Refusing it here is what makes that index a caller error the
    /// caller can see.
    ///
    /// This is the only condition [Decode] establishes that the break passes
    /// above do not: a break pass is handed a whole buffer and reads it from the
    /// start, so it has no index to be wrong about.
    IndexPastEnd,
};

/// The three code-point decoders upstream exports, as a typed cursor.
///
/// `ub_get_next_char_utf8`, `ub_get_next_char_utf16` and `ub_get_next_char_utf32`
/// (`src/unibreakdef.h:61-63`) are the three functions the break passes above
/// are built out of, and they are declared in one of the five installed headers,
/// so they are part of the public surface rather than an implementation detail
/// that happens to be visible. The break passes are the interesting use; this is
/// the one a caller reaches for when it wants the code points themselves, to
/// index something alongside the break positions — a character map, a glyph
/// lookup, a search.
///
/// Every method returns a [Step] rather than a bare code point, because the
/// native contract is a pair: a value *and* the index it advanced to. Returning
/// only the value would force a caller to guess how many units it had to add.
///
/// Nothing here re-decodes anything. [Step.code_point] is whatever the native
/// decoder answered, which for well-formed input is the code point at the index
/// and for anything else is upstream's own answer for that malformed case: a
/// lone UTF-8 continuation byte comes back as itself, a truncated sequence comes
/// back as end-of-string, an unpaired UTF-16 high surrogate comes back as
/// itself. The break passes above do not do that — they refuse malformed input
/// before calling in, which is the right trade for a buffer this package sizes
/// on the caller's behalf, and the wrong one for a caller already walking its
/// own string and wanting to see what the library makes of it. The difference is
/// deliberate and it is the only place the two disagree.
///
/// Malformed input here does not mean a crash or a wrong index: [Step.end] is
/// true exactly when there is nothing left at the index it was given, and in
/// every such case [Step.index] is that index, unchanged. That is upstream's
/// own behaviour — a truncated UTF-8 sequence returns `EOS` without advancing
/// (`src/unibreakdef.c:78-81,84-86,92-94,100-102`) and a trailing high
/// surrogate rewinds and returns `EOS` (`src/unibreakdef.c:138-142`) — so a loop
/// that stops on [Step.end] cannot spin, whatever the input contains.
///
/// "Nothing left" is read from the index rather than from the returned value,
/// because in UTF-32 the value cannot say it. Upstream returns `EOS` for
/// end-of-input and returns a stored `0xFFFFFFFF` as the very same `utf32_t`
/// (`src/unibreakdef.c:168-172`), so [Decode.utf32] answers on position. The
/// other two keep reading `EOS` off the value, which for them is unambiguous.
pub const Decode = struct {
    /// One decoder answer: the code point, where it ended, and whether that was
    /// end-of-string rather than a character.
    ///
    /// `code_point` is meaningless when `end` is true; it is zero there rather
    /// than left undefined, so a caller that ignores `end` gets a defined value
    /// instead of undefined behaviour.
    pub const Step = struct {
        /// The decoded code point, or zero when [end] is true.
        code_point: CodePoint,
        /// The index the decoder left at. This is the index to pass to the next
        /// call, and it is exactly the value upstream wrote through `size_t *ip`.
        ///
        /// When [end] is true it equals the index that was passed in, because
        /// none of the three decoders advances past the position at which it
        /// reports end-of-string. When [end] is false it is strictly greater:
        /// every answer that is not the end consumed at least one unit, and a
        /// caller may rely on that to bound its walk.
        index: usize,
        /// True when there is nothing left at the index that was passed in: the
        /// index was already at the end, or — in UTF-8 and UTF-16 — a sequence
        /// ran off the end of the input. Stop here.
        ///
        /// This is `true` when the native call answered `EOS`
        /// (`src/unibreakdef.h:52`), except in UTF-32, where the same `utf32_t`
        /// is also a value a buffer may hold; see [Decode.utf32]. A stored
        /// `0xFFFFFFFF` there is a character, so it leaves `end` false.
        end: bool,
    };

    /// Refuses an index past the end before the call, so the `assert` upstream
    /// relies on is never the thing that has to catch it.
    fn requireIndex(index: usize, len: usize) Error!void {
        if (index > len) return error.IndexPastEnd;
    }

    /// The code point at `index` in UTF-8 `text`, and the index after it.
    ///
    /// `index` must be at or below `text.len`; anything else is
    /// [Error.IndexPastEnd].
    pub fn utf8(text: []const u8, index: usize) Error!Step {
        try requireIndex(index, text.len);
        var at = index;
        const value = c.ub_get_next_char_utf8(text.ptr, text.len, &at);
        return step(@as(CodePoint, value), at);
    }

    /// The code point at `index` in UTF-16 `units`, and the index after it.
    ///
    /// A well-formed surrogate pair advances `index` by two; anything else
    /// advances it by one, because that is what the decoder consumed.
    pub fn utf16(units: []const u16, index: usize) Error!Step {
        try requireIndex(index, units.len);
        var at = index;
        const value = c.ub_get_next_char_utf16(units.ptr, units.len, &at);
        return step(@as(CodePoint, value), at);
    }

    /// The code point at `index` in UTF-32 `units`, and the index after it.
    ///
    /// Upstream returns any `utf32_t` verbatim here, so this does too: a
    /// surrogate or a value above `U+10FFFF` comes back as itself and advances
    /// one unit. The break passes refuse those; see [Decode].
    ///
    /// `0xFFFFFFFF` is the case that decides how the end of the input is
    /// recognised, because it is both `EOS` (`src/unibreakdef.h:52`) and a
    /// `utf32_t` a buffer may hold. It is not told apart from a character by
    /// the value; upstream answers it for either reason and returns the same
    /// `utf32_t` (`src/unibreakdef.c:168-172`). It is told apart by the index,
    /// which is the only thing that differs: upstream answers `EOS` without
    /// advancing and returns a stored unit by advancing one. So [Step.end] here
    /// means *the index was at `units.len`*, and a unit holding `0xFFFFFFFF`
    /// comes back as itself, with `end` false, exactly like a surrogate.
    pub fn utf32(units: []const u32, index: usize) Error!Step {
        try requireIndex(index, units.len);
        var at = index;
        const value = c.ub_get_next_char_utf32(units.ptr, units.len, &at);
        return verbatim(@as(CodePoint, value), at, index == units.len);
    }

    /// Builds a [Step] from what a native call returned, taking the end of the
    /// input from the returned value.
    ///
    /// This is right for UTF-8 and UTF-16 because neither decoder can answer
    /// `0xFFFFFFFF` as a character: a `utf8_t` is `unsigned char`
    /// (`src/unibreakbase.h:47`) and every UTF-16 answer is at most `U+10FFFF`.
    /// For those two encodings `EOS` is unambiguous. UTF-32 has to be told apart
    /// by position instead, and uses [verbatim].
    fn step(value: CodePoint, at: usize) Step {
        return verbatim(value, at, value == c.EOS);
    }

    /// Builds a [Step] from a native call whose end of input is already known.
    ///
    /// `end` is the caller's own answer rather than a reading of `value`,
    /// because in UTF-32 the value cannot carry it: upstream returns the same
    /// `utf32_t` for end-of-input and for a stored `0xFFFFFFFF`
    /// (`src/unibreakdef.c:168-172`). `value` passes through unchanged when
    /// `end` is false, which is what keeps a verbatim `0xFFFFFFFF`, a surrogate
    /// or any other stored unit intact, instead of folding it into the zero
    /// that stands for "no code point".
    fn verbatim(value: CodePoint, at: usize, end: bool) Step {
        return .{
            .code_point = if (end) 0 else value,
            .index = at,
            .end = end,
        };
    }
};

// ---------------------------------------------------------------------------
// Validation. One linear scan that counts code points at the same time, so the
// per-code-point methods get their capacity bound without a second pass and
// without materialising anything.
// ---------------------------------------------------------------------------

fn isContinuation(byte: u8) bool {
    return byte >= 0x80 and byte <= 0xBF;
}

/// Scans `text` as UTF-8 and returns its code point count.
///
/// Every rejection is [Error.MalformedUtf8]; the per-code-unit callers discard
/// the count. The rules implemented are the definition of well-formed UTF-8,
/// which is a *stricter* contract than upstream's decoder and is documented as
/// such on [Error].
fn countUtf8(text: []const u8) Error!usize {
    var at: usize = 0;
    var count: usize = 0;
    while (at < text.len) {
        const lead = text[at];
        if (lead < 0x80) {
            at += 1;
        } else if (lead < 0xC2) {
            // A continuation byte in lead position, or the overlong two-byte
            // leads 0xC0 and 0xC1.
            return error.MalformedUtf8;
        } else if (lead < 0xE0) {
            if (at + 1 >= text.len or !isContinuation(text[at + 1])) {
                return error.MalformedUtf8;
            }
            at += 2;
        } else if (lead < 0xF0) {
            if (at + 2 >= text.len or
                !isContinuation(text[at + 1]) or !isContinuation(text[at + 2]))
            {
                return error.MalformedUtf8;
            }
            const value: u32 = (@as(u32, lead & 0x0F) << 12) |
                (@as(u32, text[at + 1] & 0x3F) << 6) |
                @as(u32, text[at + 2] & 0x3F);
            // Below U+0800 the form is overlong; the surrogate range is not a
            // scalar value and must not be encoded in UTF-8 at all.
            if (value < 0x800 or (value >= 0xD800 and value <= 0xDFFF)) {
                return error.MalformedUtf8;
            }
            at += 3;
        } else if (lead <= 0xF4) {
            if (at + 3 >= text.len or
                !isContinuation(text[at + 1]) or
                !isContinuation(text[at + 2]) or !isContinuation(text[at + 3]))
            {
                return error.MalformedUtf8;
            }
            const value: u32 = (@as(u32, lead & 0x07) << 18) |
                (@as(u32, text[at + 1] & 0x3F) << 12) |
                (@as(u32, text[at + 2] & 0x3F) << 6) |
                @as(u32, text[at + 3] & 0x3F);
            if (value < 0x10000 or value > 0x10FFFF) {
                return error.MalformedUtf8;
            }
            at += 4;
        } else {
            return error.MalformedUtf8;
        }
        count += 1;
    }
    return count;
}

/// Scans `units` as UTF-16 and returns its code point count.
fn countUtf16(units: []const u16) Error!usize {
    var at: usize = 0;
    var count: usize = 0;
    while (at < units.len) {
        const unit = units[at];
        if (unit < 0xD800 or unit > 0xDFFF) {
            at += 1;
        } else if (unit >= 0xDC00) {
            // A low surrogate with no high surrogate behind it.
            return error.MalformedUtf16;
        } else {
            if (at + 1 >= units.len) return error.MalformedUtf16;
            const low = units[at + 1];
            if (low < 0xDC00 or low > 0xDFFF) return error.MalformedUtf16;
            at += 2;
        }
        count += 1;
    }
    return count;
}

/// Scans `units` as UTF-32 and returns its code point count.
///
/// The count equals the length: UTF-32 has no multi-unit code point and no
/// decoder state, so the scan is a bound check and nothing else.
fn countUtf32(units: []const u32) Error!usize {
    for (units) |value| {
        if (value > 0x10FFFF or (value >= 0xD800 and value <= 0xDFFF)) {
            return error.MalformedUtf32;
        }
    }
    return units.len;
}

/// Rejects an output buffer that shares storage with the input.
///
/// The comparison is over byte addresses, so `input_bytes` and `out_bytes` are
/// byte lengths rather than element counts: the two buffers can have different
/// code unit widths. A zero-length range cannot overlap anything, which is why
/// empty input is never refused for this reason.
fn rejectOverlap(input: anytype, input_bytes: usize, out: anytype, out_bytes: usize) Error!void {
    if (input.len == 0 or out.len == 0) return;
    const input_addr = @intFromPtr(input.ptr);
    const out_addr = @intFromPtr(out.ptr);
    if (input_addr < out_addr + out_bytes and out_addr < input_addr + input_bytes) {
        return error.InputOutputOverlap;
    }
}

fn requireCapacity(needed: usize, out_len: usize) Error!void {
    if (out_len < needed) return error.OutputTooSmall;
}

// ---------------------------------------------------------------------------
// Line breaking, UAX #14 revision 55.
// ---------------------------------------------------------------------------

/// Line breaking over UTF-8, UTF-16 and UTF-32, plus the native per-code-point
/// output and the native pair query.
///
/// No state: every method is a free function over borrowed arguments.
pub const Line = struct {
    fn languagePointer(lang: ?Language) [*c]const u8 {
        return if (lang) |tag| tag.ptr else null;
    }

    /// Line breaks of UTF-8 `text`, one opcode per input code unit.
    ///
    /// Writes `out[0..text.len]`; `out` must hold at least `text.len` entries.
    /// Each code point's final unit carries its following break; earlier units
    /// carry `inside_char`. The final output is `must_break` for an explicit
    /// ending break and `indeterminate` otherwise.
    /// A position before the first code point is not part of the output.
    ///
    /// With empty `text` nothing is written at all, because `set_linebreaks`
    /// returns before touching `brks` (`src/linebreak.c:1450-1453`).
    pub fn perCodeUnit(text: []const u8, lang: ?Language, out: []LineOpcode) Error!void {
        try rejectOverlap(text, text.len, out, out.len);
        try requireCapacity(text.len, out.len);
        _ = try countUtf8(text);
        c.set_linebreaks_utf8(text.ptr, text.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// Line breaks of UTF-16 `units`, one opcode per code unit.
    ///
    /// Native-endianness `u16` code units, which is what
    /// `typedef unsigned short utf16_t` (`src/unibreakbase.h:47`) means. Writes
    /// `out[0..units.len]`; everything else about the output is as for
    /// [Line.perCodeUnit].
    pub fn perCodeUnit16(units: []const u16, lang: ?Language, out: []LineOpcode) Error!void {
        try rejectOverlap(units, units.len * 2, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf16(units);
        c.set_linebreaks_utf16(units.ptr, units.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// Line breaks of UTF-32 `units`, one opcode per code unit.
    ///
    /// Here a code unit *is* a code point, so the two units coincide and every
    /// entry carries a real opcode — `inside_char` never appears. Writes
    /// `out[0..units.len]`.
    pub fn perCodeUnit32(units: []const u32, lang: ?Language, out: []LineOpcode) Error!void {
        try rejectOverlap(units, units.len * 4, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf32(units);
        c.set_linebreaks_utf32(units.ptr, units.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// Line breaks of UTF-8 `text`, one opcode per code point.
    ///
    /// This is native `set_linebreaks_utf8_per_code_point` with the buffer
    /// problem it leaves to the caller solved: one scan validates the encoding
    /// and counts the code points, capacity is checked against that count, and
    /// only then is the native call made. Writes `out[0..returned count]` and
    /// nothing else.
    ///
    /// The count returned is the number of entries written, which for
    /// well-formed input is the number of code points.
    pub fn perCodePoint(text: []const u8, lang: ?Language, out: []LineOpcode) Error!usize {
        try rejectOverlap(text, text.len, out, out.len);
        const count = try countUtf8(text);
        try requireCapacity(count, out.len);
        return c.set_linebreaks_utf8_per_code_point(text.ptr, text.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// Line breaks of UTF-16 `units`, one opcode per code point.
    ///
    /// The UTF-16 counterpart of [Line.perCodePoint], and the only other
    /// per-code-point form upstream has. There is no UTF-32 equivalent natively,
    /// because in UTF-32 the two units are the same thing.
    pub fn perCodePoint16(units: []const u16, lang: ?Language, out: []LineOpcode) Error!usize {
        try rejectOverlap(units, units.len * 2, out, out.len);
        const count = try countUtf16(units);
        try requireCapacity(count, out.len);
        return c.set_linebreaks_utf16_per_code_point(units.ptr, units.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// The break opcode between two code points.
    ///
    /// Native `is_line_breakable` (`src/linebreak.c:1656-1667`), which builds a
    /// two-code-point string on the stack and returns `brks[0]`.
    ///
    /// Both arguments must be scalar values: a surrogate or a value above
    /// `U+10FFFF` is refused as [Error.MalformedUtf32] rather than handed to a
    /// decoder that would accept it.
    ///
    /// Upstream's own documentation recommends against this entry point for text
    /// that involves combining marks or spaces (`src/linebreak.c:1646-1648`),
    /// and that advice is passed on unchanged: a pair query cannot see the
    /// context rules LB9-LB15 need, and [Line.perCodeUnit32] is the answer for
    /// real text. What this method is for is asking about two isolated
    /// characters.
    ///
    /// The opcode is returned exactly as native returns it. Native writes
    /// `brks[0]` from the same decision that fills the first entry of a
    /// per-code-unit pass, so this agrees with [Line.perCodeUnit32] on a
    /// two-code-point string; that equality is a property callers can rely on,
    /// not an extra rule this method applies.
    pub fn breakBetween(first: CodePoint, second: CodePoint, lang: ?Language) Error!LineOpcode {
        _ = try countUtf32(&.{ first, second });
        const raw = c.is_line_breakable(first, second, languagePointer(lang));
        return @enumFromInt(@as(u8, @truncate(@as(u32, @bitCast(raw)))));
    }
};

// ---------------------------------------------------------------------------
// Word breaking, UAX #29 revision 47. No language: upstream ignores it.
// ---------------------------------------------------------------------------

/// Word breaking over UTF-8, UTF-16 and UTF-32.
///
/// No state, no options and no language: `src/wordbreak.c:169-170` is
/// `/* TODO: Language-specific specialization. */ (void)lang;`, so a typed
/// language option here would promise tailoring the library does not perform.
pub const Word = struct {
    /// Word breaks of UTF-8 `text`, one opcode per input code unit.
    ///
    /// Writes `out[0..text.len]`. A code point's final unit carries its following
    /// break; earlier units carry `inside_char`. The last entry is the final
    /// position. Empty input writes nothing.
    pub fn perCodeUnit(text: []const u8, out: []WordOpcode) Error!void {
        try rejectOverlap(text, text.len, out, out.len);
        try requireCapacity(text.len, out.len);
        _ = try countUtf8(text);
        c.set_wordbreaks_utf8(text.ptr, text.len, null, @ptrCast(out.ptr));
    }

    /// Word breaks of UTF-16 `units`, one opcode per code unit.
    pub fn perCodeUnit16(units: []const u16, out: []WordOpcode) Error!void {
        try rejectOverlap(units, units.len * 2, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf16(units);
        c.set_wordbreaks_utf16(units.ptr, units.len, null, @ptrCast(out.ptr));
    }

    /// Word breaks of UTF-32 `units`, one opcode per code unit.
    ///
    /// A code unit is a code point here, so `inside_char` never appears.
    pub fn perCodeUnit32(units: []const u32, out: []WordOpcode) Error!void {
        try rejectOverlap(units, units.len * 4, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf32(units);
        c.set_wordbreaks_utf32(units.ptr, units.len, null, @ptrCast(out.ptr));
    }
};

// ---------------------------------------------------------------------------
// Grapheme breaking, UAX #29 revision 47. No language: upstream ignores it.
// ---------------------------------------------------------------------------

/// Extended grapheme cluster breaking over UTF-8, UTF-16 and UTF-32.
///
/// No state, no options and no language: all three native entry points begin
/// with `(void)lang;` (`src/graphemebreak.c:330`, `:352`, `:374`).
pub const Grapheme = struct {
    /// Grapheme cluster breaks of UTF-8 `text`, one opcode per input code unit.
    ///
    /// Writes `out[0..text.len]`. Each code point's final code unit carries
    /// its following break. Earlier units carry `inside_char`.
    /// Empty input leaves every output byte unchanged. The wrapper skips the
    /// native empty pass, which would index one byte before `out`.
    pub fn perCodeUnit(text: []const u8, out: []GraphemeOpcode) Error!void {
        try rejectOverlap(text, text.len, out, out.len);
        try requireCapacity(text.len, out.len);
        _ = try countUtf8(text);
        if (text.len == 0) return;
        c.set_graphemebreaks_utf8(text.ptr, text.len, null, @ptrCast(out.ptr));
    }

    /// Grapheme cluster breaks of UTF-16 `units`, one opcode per code unit.
    pub fn perCodeUnit16(units: []const u16, out: []GraphemeOpcode) Error!void {
        try rejectOverlap(units, units.len * 2, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf16(units);
        if (units.len == 0) return;
        c.set_graphemebreaks_utf16(units.ptr, units.len, null, @ptrCast(out.ptr));
    }

    /// Grapheme cluster breaks of UTF-32 `units`, one opcode per code unit.
    ///
    /// A code unit is a code point here, so `inside_char` never appears.
    pub fn perCodeUnit32(units: []const u32, out: []GraphemeOpcode) Error!void {
        try rejectOverlap(units, units.len * 4, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf32(units);
        if (units.len == 0) return;
        c.set_graphemebreaks_utf32(units.ptr, units.len, null, @ptrCast(out.ptr));
    }
};
