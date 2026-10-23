//! Exercises the typed facade and translated C declarations in both build modes.
const std = @import("std");
const c = @import("c");
const libunibreak = @import("libunibreak");

/// Result of a failed expectation or missing runtime provider.
pub const Failure = error{
    UnexpectedResult,
    /// A runtime-loaded exercise has no configured provider.
    MissingProvider,
};

/// Environment variable naming the runtime provider.
const provider_variable = "LIBUNIBREAK_TEST_PROVIDER";

/// Loads the configured provider when runtime loading is enabled.
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

/// Requires a fallible call to return the specified error.
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

/// Three code points for a language-tailoring check.
const line_32 = [_]u32{ 0x4E00, 0xFF1A, 0x300C };

/// Calls every public function of the typed facade.
pub fn exerciseTyped() ExerciseError!void {
    // Check the facade's version, provider request, and provider data address.
    _ = libunibreak.version();
    const data_address = libunibreak.versionPointer();
    const request = libunibreak.loadedSource();
    if (libunibreak.runtime_loaded) {
        try expect(data_address != null);
        try expect(request != null);
    } else {
        try expect(data_address == null);
        try expect(request == null);
    }

    // Line breaking preserves distinct break opcodes.
    const spaced = [_]u32{ 0x0061, 0x0020, 0x0062 };
    var spaced_out: [3]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&spaced, null, &spaced_out);
    try expectEqual(libunibreak.LineOpcode.no_break, spaced_out[0]);
    try expectEqual(libunibreak.LineOpcode.allow_break, spaced_out[1]);
    try expectEqual(libunibreak.LineOpcode.indeterminate, spaced_out[2]);

    var line8: [16]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit(combining_text, null, &line8);
    // LB9 marks the leading UTF-8 unit inside the code point.
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

    var points8: [8]libunibreak.LineOpcode = undefined;
    const count8 = try libunibreak.Line.perCodePoint(combining_text, null, &points8);
    try expectEqual(@as(usize, 2), count8);
    var points16: [8]libunibreak.LineOpcode = undefined;
    const count16 = try libunibreak.Line.perCodePoint16(&combining_16, null, &points16);
    try expectEqual(@as(usize, 2), count16);

    const between: libunibreak.CodePoint = 0x0061;
    const queried = try libunibreak.Line.breakBetween(between, 0x0301, null);
    try expectEqual(libunibreak.LineOpcode.no_break, queried);
    try expectFailure(error.MalformedUtf32, libunibreak.Line.breakBetween(0xD800, 0x0041, null));

    const strict: libunibreak.Language = "-strict";
    var tailored: [8]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&line_32, strict, &tailored);
    var untailored: [8]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&line_32, null, &untailored);
    try expectEqual(untailored[0], tailored[0]);

    const with_break = [_]u32{ 0x0061, 0x000A };
    var ends: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&with_break, null, &ends);
    try expectEqual(libunibreak.LineOpcode.must_break, ends[1]);
    const without_break = [_]u32{0x0061};
    var open: [1]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&without_break, null, &open);
    try expectEqual(libunibreak.LineOpcode.indeterminate, open[0]);

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

    var grapheme8: [16]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit(combining_text, &grapheme8);
    var grapheme16: [8]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit16(&combining_16, &grapheme16);
    var grapheme32: [8]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit32(&combining_32, &grapheme32);
    try expectEqual(libunibreak.GraphemeOpcode.no_break, grapheme32[0]);

    var guard: [16]libunibreak.LineOpcode = undefined;
    try expectFailure(error.OutputTooSmall, libunibreak.Line.perCodeUnit(combining_text, null, guard[0..2]));
    try expectFailure(error.OutputTooSmall, libunibreak.Line.perCodePoint(combining_text, null, guard[0..1]));
    try expectFailure(error.MalformedUtf8, libunibreak.Line.perCodeUnit("\xE0\xA0", null, &guard));
    try expectFailure(error.MalformedUtf16, libunibreak.Line.perCodeUnit16(&[_]u16{0xD800}, null, &guard));
    try expectFailure(error.MalformedUtf32, libunibreak.Line.perCodeUnit32(&[_]u32{0x110000}, null, &guard));

    // The output view overlaps the input storage.
    var shared = [_]u8{ 'a', 'b', 0, 0 };
    const shared_out: []libunibreak.WordOpcode = @as([*]libunibreak.WordOpcode, @ptrCast(shared[0..2].ptr))[0..2];
    try expectFailure(error.InputOutputOverlap, libunibreak.Word.perCodeUnit(shared[0..], shared_out));

    // Decode the combining sequence in all three encodings.
    const first8 = try libunibreak.Decode.utf8(combining_text, 0);
    try expect(!first8.end);
    try expectEqual(@as(libunibreak.CodePoint, 0x0061), first8.code_point);
    try expectEqual(@as(usize, 1), first8.index);
    const second8 = try libunibreak.Decode.utf8(combining_text, first8.index);
    try expectEqual(@as(libunibreak.CodePoint, 0x0301), second8.code_point);
    try expectEqual(@as(usize, 3), second8.index);
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

    try expectFailure(error.IndexPastEnd, libunibreak.Decode.utf8(combining_text, combining_text.len + 1));
    try expectFailure(error.IndexPastEnd, libunibreak.Decode.utf16(&combining_16, combining_16.len + 1));
    try expectFailure(error.IndexPastEnd, libunibreak.Decode.utf32(&combining_32, combining_32.len + 1));
}

/// Calls the declarations exposed through the translated C namespace.
pub fn exerciseRaw() Failure!void {
    // Exercise upstream's empty compatibility entry points.
    c.init_linebreak();
    c.init_wordbreak();
    c.init_graphemebreak();

    // Read the native version directly or through the runtime dispatch.
    const version: c_int = if (libunibreak.runtime_loaded)
        c.unibreak_versionAddr().*
    else
        c.unibreak_version;
    _ = version;

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
    // Compare raw `char` output with the typed opcode value.
    try expectEqual(@as(u8, @backingInt(libunibreak.LineOpcode.no_break)), brk8[0]);
    try expectEqual(@as(u8, @backingInt(libunibreak.LineOpcode.inside_char)), brk8[1]);

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
    try expectEqual(@as(u8, @backingInt(libunibreak.LineOpcode.no_break)), @as(u8, @truncate(@as(u32, @bitCast(raw_between)))));

    // Check comma grouping and multibyte continuation markers.
    var word8: [8]u8 = undefined;
    c.set_wordbreaks_utf8(number_text.ptr, number_text.len, null, &word8);
    try expectEqual(@as(u8, @backingInt(libunibreak.WordOpcode.no_break)), word8[0]);
    try expectEqual(@as(u8, @backingInt(libunibreak.WordOpcode.no_break)), word8[1]);
    var word_combining: [8]u8 = undefined;
    c.set_wordbreaks_utf8(combining_text.ptr, combining_text.len, null, &word_combining);
    try expectEqual(@as(u8, @backingInt(libunibreak.WordOpcode.inside_char)), word_combining[1]);
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

    // Pass a NUL-terminated `-strict` tag through the raw line-break API.
    const strict: [*:0]const u8 = "-strict";
    var tailored: [8]u8 = undefined;
    c.set_linebreaks_utf32(&line_32, line_32.len, strict, &tailored);
    try expectEqual(@as(u8, @backingInt(libunibreak.LineOpcode.no_break)), tailored[0]);
}

pub fn main(init: std.process.Init) !void {
    try loadProvider(init);
    try exerciseTyped();
    try exerciseRaw();
}
