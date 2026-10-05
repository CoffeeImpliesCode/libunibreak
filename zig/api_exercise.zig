//! Compile-time and run-time exercise of every public declaration.
//!
//! Referencing a declaration only proves it exists. A Zig function body is
//! analysed when something calls it, so a `pub fn` nobody references can sit in
//! a facade indefinitely without ever being compiled. This file calls every one
//! of them:
//!
//!   * `zig build check` compiles this program for each of the six matrix
//!     targets, which is what forces every facade body to be instantiated, and
//!   * it is a program with a `main`, so every call it makes is compiled wherever
//!     the program is built, without needing a test runner.
//!
//! Both routes are exercised, not just the typed one. Every `pub` function of
//! `zig/root.zig` is called, and so is every public function of the translated
//! headers reached through `libunibreak.c` — the eleven `set_*` entry points,
//! `is_line_breakable`, the three `ub_get_next_char_*` decoders and the three
//! empty `init_*` compatibility calls, which exist upstream
//! (`src/linebreak.c:548-550`) and stay reachable only on that route.
//!
//! In a runtime-loading build `libunibreak.c` is a generated dispatch, so the one
//! name that is reached rather than called is the data object: the exercise
//! reads it through `unibreak_versionAddr()` there and through the plain
//! `unibreak_version` decl in a linked build, which is the same read of the same
//! object through whichever route this configuration built.
//!
//! The results checked afterwards are the same independent ones the test suite
//! uses: a combining mark stays inside its base character, "1,0" is one word,
//! an explicit break at the end of a line is mandatory while an ordinary end is
//! indeterminate, and each refusal is refused for the stated reason.

// Both imports name one C ABI: the facade already binds `c`, and binding it
// again here describes the same translation rather than a second one.
const std = @import("std");
const c = @import("c");
const libunibreak = @import("libunibreak");

/// A public call produced a result that contradicts an independent expectation.
pub const Failure = error{
    UnexpectedResult,
    /// This is a runtime-loading build and no provider was named, so there is
    /// nothing to call. See [loadProvider].
    MissingProvider,
};

/// A shared object exporting the eighteen functions and the `unibreak_version`
/// object of the five public headers.
const provider_variable = "LIBUNIBREAK_TEST_PROVIDER";

/// Open the provider this build needs, once, or say why it cannot.
///
/// A linked build has nothing to open, so this returns immediately there and
/// every call below is a direct C call. A runtime-loading build has no library
/// in its module at all, so a run that was not told which file to open has
/// nothing to call and says so instead of passing by doing nothing. The value
/// read here belongs to the environment the process was given; the loader keeps
/// its own copy for the life of the process, which is what survives the call.
fn loadProvider(init: std.process.Init) (Failure || libunibreak.LoadError)!void {
    if (!libunibreak.runtime_loaded) return;
    const path = init.environ_map.get(provider_variable) orelse {
        std.debug.print(
            "\napi_exercise: {s} is not set. This is a runtime-loading build, so " ++
                "nothing native is linked into the module and there is no provider " ++
                "to call. Build one with `zig build -Dlinkage=dynamic --prefix " ++
                "<dir>` and point {s} at <dir>/lib/libunibreak.so.\n",
            .{ provider_variable, provider_variable },
        );
        return error.MissingProvider;
    };
    if (path.len == 0) return error.MissingProvider;
    try libunibreak.load(.{ .path = path });
}

fn expect(condition: bool) Failure!void {
    if (!condition) return error.UnexpectedResult;
}

fn expectEqual(expected: anytype, actual: @TypeOf(expected)) Failure!void {
    if (expected != actual) return error.UnexpectedResult;
}

/// Assert that a fallible call failed, and failed for the stated reason.
///
/// The boundary between an accepted and a rejected buffer is part of the public
/// contract, so it is exercised rather than merely declared.
fn expectFailure(expected: anyerror, call: anytype) Failure!void {
    if (call) |_| {
        return error.UnexpectedResult;
    } else |err| {
        if (err != expected) return error.UnexpectedResult;
    }
}

const ExerciseError = Failure || libunibreak.Error;

/// "a" followed by U+0301 COMBINING ACUTE ACCENT, as UTF-8.
const combining_text = "a\xCC\x81";

/// The same two code points in UTF-16 and UTF-32.
const combining_16 = [_]u16{ 0x0061, 0x0301 };
const combining_32 = [_]u32{ 0x0061, 0x0301 };

/// "1,0" — WordBreakTest.txt line 1729, one word.
const number_text = "1,0";
const number_32 = [_]u32{ 0x0031, 0x002C, 0x0030 };

/// An ideograph held to a fullwidth colon and released before an opening
/// bracket — the first three code points of LineBreakTest.txt line 19242.
const line_32 = [_]u32{ 0x4E00, 0xFF1A, 0x300C };

/// Calls every public function of the typed facade.
pub fn exerciseTyped() ExerciseError!void {
    // `version` reads the library's own `unibreak_version`
    // (`src/unibreakbase.h:43`) through whichever route this configuration
    // built, and `versionPointer` reports the address that route uses: null in
    // a linked build, the provider's own storage in a runtime-loading one.
    // `loadedSource` is the loader's retained request, and is likewise null in
    // a linked build, which has no request because it has nothing to load.
    _ = libunibreak.version();
    // A load has already happened by the time this runs, and the two things a
    // load produces are visible from the facade: the retained request and the
    // address of the provider's own data object. A linked build has neither.
    const data_address = libunibreak.versionPointer();
    const request = libunibreak.loadedSource();
    if (libunibreak.runtime_loaded) {
        try expect(data_address != null);
        try expect(request != null);
    } else {
        try expect(data_address == null);
        try expect(request == null);
    }

    // --- Line breaking ---------------------------------------------------
    // Every line opcode, by name, on text whose answers are known: LB7 forbids
    // a break before a space and LB18 requires one after it, so "a b" reports
    // `no_break`, `allow_break` and, at the end, `indeterminate`.
    const spaced = [_]u32{ 0x0061, 0x0020, 0x0062 };
    var spaced_out: [3]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&spaced, null, &spaced_out);
    try expectEqual(libunibreak.LineOpcode.no_break, spaced_out[0]);
    try expectEqual(libunibreak.LineOpcode.allow_break, spaced_out[1]);
    try expectEqual(libunibreak.LineOpcode.indeterminate, spaced_out[2]);

    // --- Line breaking, one entry point per encoding ----------------------
    var line8: [16]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit(combining_text, null, &line8);
    // LB9 prohibits a break before the combining mark. The marker occupies
    // its final unit; the earlier UTF-8 unit is inside_char.
    try expectEqual(libunibreak.LineOpcode.no_break, line8[0]);
    try expectEqual(libunibreak.LineOpcode.inside_char, line8[1]);
    try expectEqual(libunibreak.LineOpcode.indeterminate, line8[2]);

    var line16: [8]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit16(&combining_16, null, &line16);
    try expectEqual(libunibreak.LineOpcode.no_break, line16[0]);
    try expectEqual(libunibreak.LineOpcode.indeterminate, line16[1]);

    var line32: [8]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&combining_32, null, &line32);
    try expectEqual(libunibreak.LineOpcode.no_break, line32[0]);
    for (line32[0..combining_32.len]) |opcode| try expect(opcode != .inside_char);

    // The per-code-point forms, and the count they report.
    var points8: [8]libunibreak.LineOpcode = undefined;
    const count8 = try libunibreak.Line.perCodePoint(combining_text, null, &points8);
    try expectEqual(@as(usize, 2), count8);
    var points16: [8]libunibreak.LineOpcode = undefined;
    const count16 = try libunibreak.Line.perCodePoint16(&combining_16, null, &points16);
    try expectEqual(@as(usize, 2), count16);

    // The pair query, and the two arguments it refuses.
    const between: libunibreak.CodePoint = 0x0061;
    const queried = try libunibreak.Line.breakBetween(between, 0x0301, null);
    try expectEqual(libunibreak.LineOpcode.no_break, queried);
    try expectFailure(error.MalformedUtf32, libunibreak.Line.breakBetween(0xD800, 0x0041, null));

    // A language tag: borrowed, sentinel-terminated, and matched by prefix.
    const strict: libunibreak.Language = "-strict";
    var tailored: [8]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&line_32, strict, &tailored);
    var untailored: [8]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&line_32, null, &untailored);
    try expectEqual(untailored[0], tailored[0]);

    // The final-position distinction, with no oracle fold applied.
    const with_break = [_]u32{ 0x0061, 0x000A };
    var ends: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&with_break, null, &ends);
    try expectEqual(libunibreak.LineOpcode.must_break, ends[1]);
    const without_break = [_]u32{0x0061};
    var open: [1]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&without_break, null, &open);
    try expectEqual(libunibreak.LineOpcode.indeterminate, open[0]);

    // --- Word breaking ---------------------------------------------------
    var word8: [16]libunibreak.WordOpcode = undefined;
    try libunibreak.Word.perCodeUnit(number_text, &word8);
    var word16: [8]libunibreak.WordOpcode = undefined;
    try libunibreak.Word.perCodeUnit16(&combining_16, &word16);
    var word32: [8]libunibreak.WordOpcode = undefined;
    try libunibreak.Word.perCodeUnit32(&number_32, &word32);
    // WB11 and WB12 keep the comma inside the number.
    try expectEqual(libunibreak.WordOpcode.no_break, word32[0]);
    try expectEqual(libunibreak.WordOpcode.no_break, word32[1]);
    try expectEqual(libunibreak.WordOpcode.allow_break, word32[2]);

    // --- Grapheme breaking ----------------------------------------------
    var grapheme8: [16]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit(combining_text, &grapheme8);
    var grapheme16: [8]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit16(&combining_16, &grapheme16);
    var grapheme32: [8]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit32(&combining_32, &grapheme32);
    try expectEqual(libunibreak.GraphemeOpcode.no_break, grapheme32[0]);

    // --- Every refusal, once --------------------------------------------
    var guard: [16]libunibreak.LineOpcode = undefined;
    try expectFailure(error.OutputTooSmall, libunibreak.Line.perCodeUnit(combining_text, null, guard[0..2]));
    try expectFailure(error.OutputTooSmall, libunibreak.Line.perCodePoint(combining_text, null, guard[0..1]));
    try expectFailure(error.MalformedUtf8, libunibreak.Line.perCodeUnit("\xE0\xA0", null, &guard));
    try expectFailure(error.MalformedUtf16, libunibreak.Line.perCodeUnit16(&[_]u16{0xD800}, null, &guard));
    try expectFailure(error.MalformedUtf32, libunibreak.Line.perCodeUnit32(&[_]u32{0x110000}, null, &guard));

    // Overlap: the output buffer lives inside the input's own bytes.
    var shared = [_]u8{ 'a', 'b', 0, 0 };
    const shared_out: []libunibreak.WordOpcode = @as([*]libunibreak.WordOpcode, @ptrCast(shared[0..2].ptr))[0..2];
    try expectFailure(error.InputOutputOverlap, libunibreak.Word.perCodeUnit(shared[0..], shared_out));

    // --- The typed decoders ---------------------------------------------
    // "a" followed by U+0301, the same two code points in all three encodings.
    // A cursor is a value plus the index it left at, and the index is what makes
    // it a cursor rather than a lookup.
    const first8 = try libunibreak.Decode.utf8(combining_text, 0);
    try expect(!first8.end);
    try expectEqual(@as(libunibreak.CodePoint, 0x0061), first8.code_point);
    try expectEqual(@as(usize, 1), first8.index);
    const second8 = try libunibreak.Decode.utf8(combining_text, first8.index);
    try expectEqual(@as(libunibreak.CodePoint, 0x0301), second8.code_point);
    try expectEqual(@as(usize, 3), second8.index);
    // At the end the decoder answers EOS without advancing, so a loop that stops
    // on `end` cannot spin.
    const past8 = try libunibreak.Decode.utf8(combining_text, second8.index);
    try expect(past8.end);
    try expectEqual(second8.index, past8.index);

    const first16 = try libunibreak.Decode.utf16(&combining_16, 0);
    try expectEqual(@as(usize, 1), first16.index);
    const second16 = try libunibreak.Decode.utf16(&combining_16, first16.index);
    try expectEqual(@as(libunibreak.CodePoint, 0x0301), second16.code_point);
    try expectEqual(@as(usize, 2), second16.index);
    try expect((try libunibreak.Decode.utf16(&combining_16, second16.index)).end);

    const first32 = try libunibreak.Decode.utf32(&combining_32, 0);
    try expectEqual(@as(libunibreak.CodePoint, 0x0061), first32.code_point);
    try expectEqual(@as(usize, 1), first32.index);
    const second32 = try libunibreak.Decode.utf32(&combining_32, first32.index);
    try expectEqual(@as(libunibreak.CodePoint, 0x0301), second32.code_point);
    try expectEqual(@as(usize, 2), second32.index);
    try expect((try libunibreak.Decode.utf32(&combining_32, second32.index)).end);

    // An index past the end is refused rather than handed to an `assert` that
    // two of this package's four optimize modes have removed.
    try expectFailure(error.IndexPastEnd, libunibreak.Decode.utf8(combining_text, combining_text.len + 1));
    try expectFailure(error.IndexPastEnd, libunibreak.Decode.utf16(&combining_16, combining_16.len + 1));
    try expectFailure(error.IndexPastEnd, libunibreak.Decode.utf32(&combining_32, combining_32.len + 1));
}

/// Calls every public function of the translated headers, through `c`.
///
/// The raw route is what a C caller, or a caller whose need this facade does not
/// name, reaches. Its one rule the facade does not enforce is that the caller
/// sizes the buffer: each call below therefore passes one that is exactly the
/// input length, which is what `set_*` writes.
pub fn exerciseRaw() Failure!void {
    // The three compatibility entry points. They have empty bodies upstream and
    // are deliberately not given a typed spelling, so this is the only place
    // they are reachable.
    c.init_linebreak();
    c.init_wordbreak();
    c.init_graphemebreak();

    // The one exported data object. `src/unibreakbase.h:43` declares it
    // `extern const int`, so it is storage and not a callable entry point, and
    // the two configurations reach it differently: a linked build has the decl,
    // a runtime-loading build has the address the loader resolved. Both are read
    // here rather than copied, which is the whole difference between the two
    // routes and the reason `versionPointer` exists.
    const version: c_int = if (libunibreak.runtime_loaded)
        c.unibreak_versionAddr().*
    else
        c.unibreak_version;
    _ = version;

    // Each raw decoder consumes both code points before reporting EOS.
    var utf16_at: usize = 0;
    try expectEqual(@as(c_uint, 0x0061), c.ub_get_next_char_utf16(&combining_16, combining_16.len, &utf16_at));
    try expectEqual(@as(usize, 1), utf16_at);
    try expectEqual(@as(c_uint, 0x0301), c.ub_get_next_char_utf16(&combining_16, combining_16.len, &utf16_at));
    try expectEqual(@as(usize, 2), utf16_at);
    try expectEqual(@as(c_uint, c.EOS), c.ub_get_next_char_utf16(&combining_16, combining_16.len, &utf16_at));
    try expectEqual(@as(usize, 2), utf16_at);

    var utf8_at: usize = 0;
    try expectEqual(@as(c_uint, 0x0061), c.ub_get_next_char_utf8(combining_text.ptr, combining_text.len, &utf8_at));
    try expectEqual(@as(usize, 1), utf8_at);
    try expectEqual(@as(c_uint, 0x0301), c.ub_get_next_char_utf8(combining_text.ptr, combining_text.len, &utf8_at));
    try expectEqual(@as(usize, 3), utf8_at);

    var utf32_at: usize = 0;
    try expectEqual(@as(c_uint, 0x0061), c.ub_get_next_char_utf32(&combining_32, combining_32.len, &utf32_at));
    try expectEqual(@as(usize, 1), utf32_at);
    try expectEqual(@as(c_uint, 0x0301), c.ub_get_next_char_utf32(&combining_32, combining_32.len, &utf32_at));
    try expectEqual(@as(usize, 2), utf32_at);
    try expectEqual(@as(c_uint, c.EOS), c.ub_get_next_char_utf32(&combining_32, combining_32.len, &utf32_at));
    try expectEqual(@as(usize, 2), utf32_at);

    var brk8: [8]u8 = undefined;
    c.set_linebreaks_utf8(combining_text.ptr, combining_text.len, null, &brk8);
    // The `char` the C wrote is read back as `u8` and compared with the typed
    // opcode's own value, which is how a caller migrating from the raw route
    // checks that the two spell the same number.
    try expectEqual(@as(u8, @intFromEnum(libunibreak.LineOpcode.no_break)), brk8[0]);
    try expectEqual(@as(u8, @intFromEnum(libunibreak.LineOpcode.inside_char)), brk8[1]);

    var brk16: [8]u8 = undefined;
    c.set_linebreaks_utf16(&combining_16, combining_16.len, null, &brk16);

    var brk32: [8]u8 = undefined;
    c.set_linebreaks_utf32(&combining_32, combining_32.len, null, &brk32);

    var per_point8: [8]u8 = undefined;
    const filled8 = c.set_linebreaks_utf8_per_code_point(combining_text.ptr, combining_text.len, null, &per_point8);
    try expectEqual(@as(usize, 2), filled8);

    var per_point16: [8]u8 = undefined;
    const filled16 = c.set_linebreaks_utf16_per_code_point(&combining_16, combining_16.len, null, &per_point16);
    try expectEqual(@as(usize, 2), filled16);

    const raw_between: c_int = c.is_line_breakable(0x0061, 0x0301, null);
    try expectEqual(@as(u8, @intFromEnum(libunibreak.LineOpcode.no_break)), @as(u8, @truncate(@as(u32, @bitCast(raw_between)))));

    // WB11 and WB12 keep the comma inside the number, and WB4 keeps a
    // combining mark in its base's word. Multibyte codepoints carry the opcode
    // on the final unit; earlier units carry `inside_char`.
    var word8: [8]u8 = undefined;
    c.set_wordbreaks_utf8(number_text.ptr, number_text.len, null, &word8);
    try expectEqual(@as(u8, @intFromEnum(libunibreak.WordOpcode.no_break)), word8[0]);
    try expectEqual(@as(u8, @intFromEnum(libunibreak.WordOpcode.no_break)), word8[1]);
    var word_combining: [8]u8 = undefined;
    c.set_wordbreaks_utf8(combining_text.ptr, combining_text.len, null, &word_combining);
    try expectEqual(@as(u8, @intFromEnum(libunibreak.WordOpcode.inside_char)), word_combining[1]);
    var word16: [8]u8 = undefined;
    c.set_wordbreaks_utf16(&combining_16, combining_16.len, null, &word16);
    var word32: [8]u8 = undefined;
    c.set_wordbreaks_utf32(&number_32, number_32.len, null, &word32);

    var grapheme8: [8]u8 = undefined;
    c.set_graphemebreaks_utf8(combining_text.ptr, combining_text.len, null, &grapheme8);
    var grapheme16: [8]u8 = undefined;
    c.set_graphemebreaks_utf16(&combining_16, combining_16.len, null, &grapheme16);
    var grapheme32: [8]u8 = undefined;
    c.set_graphemebreaks_utf32(&combining_32, combining_32.len, null, &grapheme32);

    // A language tag reaches the raw entry points too, and `"-strict"` is the
    // sentinel-terminated slice the C expects. These are the first three code
    // points of LineBreakTest.txt line 19242: U+FF1A is class NS, so LB21 holds
    // it to the ideograph before it.
    const strict: [*:0]const u8 = "-strict";
    var tailored: [8]u8 = undefined;
    c.set_linebreaks_utf32(&line_32, line_32.len, strict, &tailored);
    try expectEqual(@as(u8, @intFromEnum(libunibreak.LineOpcode.no_break)), tailored[0]);
}

pub fn main(init: std.process.Init) !void {
    try loadProvider(init);
    try exerciseTyped();
    try exerciseRaw();
}
