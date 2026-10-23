//! Unicode fixture conformance and wrapper-behavior tests for libunibreak.

const std = @import("std");
const libunibreak = @import("libunibreak");

/// Environment variable naming the runtime test provider.
const provider_variable = "LIBUNIBREAK_TEST_PROVIDER";

const absent_provider = "/libunibreak-no-such-directory/libunibreak.so";

/// Setup error when no runtime provider is configured.
const Setup = error{MissingProvider};

/// Returns the provider source currently loaded by the process.
fn inUse() ?[]const u8 {
    const source = libunibreak.loadedSource() orelse return null;
    return switch (source) {
        .path => |p| p,
        .system => |s| s,
    };
}

/// Loads a provider when runtime loading is enabled.
fn loadProvider() (Setup || libunibreak.LoadError)!void {
    if (!libunibreak.runtime_loaded) return;
    if (inUse() != null) return;
    const value = std.testing.environ.getAlloc(std.testing.allocator, provider_variable) catch |err| switch (err) {
        error.EnvironmentVariableMissing, error.InvalidWtf8 => {
            std.debug.print(
                "\n{s}: not set. This is a runtime-loading build, so nothing native " ++
                    "is linked into the module and there is no provider to call.\n" ++
                    "Build one with `zig build -Dlinkage=dynamic --prefix <dir>` and " ++
                    "point {s} at <dir>/lib/libunibreak.so.\n",
                .{ @errorName(err), provider_variable },
            );
            return error.MissingProvider;
        },
        error.OutOfMemory => return error.MissingProvider,
    };
    defer std.testing.allocator.free(value);
    if (value.len == 0) {
        std.debug.print("\n{s} is empty; there is no provider to name.\n", .{provider_variable});
        return error.MissingProvider;
    }
    try libunibreak.load(.{ .path = value });
}

test "a request that names nothing is refused before the platform is called" {
    if (!libunibreak.runtime_loaded) return error.SkipZigTest;
    try std.testing.expect(inUse() == null);

    try std.testing.expectError(error.EmptySource, libunibreak.load(.{ .path = "" }));
    try std.testing.expectError(error.EmptySource, libunibreak.load(.{ .system = "" }));

    try std.testing.expect(inUse() == null);
}

test "a provider that cannot be opened publishes nothing, and the retry is the caller's to make" {
    if (!libunibreak.runtime_loaded) return error.SkipZigTest;
    try std.testing.expect(inUse() == null);

    try std.testing.expectError(error.OpenFailed, libunibreak.load(.{ .path = absent_provider }));
    try std.testing.expect(inUse() == null);

    try loadProvider();
    try std.testing.expect(inUse() != null);

    // A different request is refused outright, and the provider already in use
    // stays in use; the same request again is a no-op that succeeds.
    try std.testing.expectError(
        error.ProviderMismatch,
        libunibreak.load(.{ .system = "libunibreak-not-installed.so" }),
    );
    const retained = inUse().?;
    try loadProvider();
    try std.testing.expect(std.mem.eql(u8, retained, inUse().?));
}

const line_fixture = @embedFile("src/LineBreakTest.txt");
const word_fixture = @embedFile("src/WordBreakTest.txt");
const grapheme_fixture = @embedFile("src/GraphemeBreakTest.txt");

/// Expected data-row counts from the Unicode fixture footers.
const expected_line_rows = 19338;
const expected_word_rows = 1944;
const expected_grapheme_rows = 766;

/// Maximum code points in a fixture row.
const max_row_code_points = 256;

const TestError = libunibreak.Error || error{
    ConformanceFailure,
    FixtureRowTooLong,
    UnexpectedFixtureSyntax,
    /// Runtime-loading tests need a configured provider.
    MissingProvider,
};

/// Parsed code points and break markers; `marks[i]` precedes `points[i]`.
const ParsedRow = struct {
    points: [max_row_code_points]u32,
    marks: [max_row_code_points + 1]bool,
    len: usize,
};

fn isSpace(byte: u8) bool {
    return byte == ' ' or byte == '\t';
}

/// Iterates the space- and tab-separated tokens in a fixture row.
const Tokens = struct {
    text: []const u8,
    at: usize = 0,

    fn next(self: *Tokens) ?[]const u8 {
        while (self.at < self.text.len and isSpace(self.text[self.at])) self.at += 1;
        if (self.at >= self.text.len) return null;
        const start = self.at;
        while (self.at < self.text.len and !isSpace(self.text[self.at])) self.at += 1;
        return self.text[start..self.at];
    }
};

/// Maps the fixture's `÷` and `×` markers to break expectations.
fn markerAllowsBreak(token: []const u8) ?bool {
    if (std.mem.eql(u8, token, "\xC3\xB7")) return true;
    if (std.mem.eql(u8, token, "\xC3\x97")) return false;
    return null;
}

/// Parses one whole fixture row and rejects unsupported syntax.
fn parseRow(line: []const u8) TestError!ParsedRow {
    const data = if (std.mem.indexOfScalar(u8, line, '#')) |at| line[0..at] else line;

    var row: ParsedRow = undefined;
    row.len = 0;
    var tokens: Tokens = .{ .text = data };
    var want_marker = true;

    while (tokens.next()) |token| {
        if (want_marker) {
            if (row.len > max_row_code_points) return error.FixtureRowTooLong;
            row.marks[row.len] = markerAllowsBreak(token) orelse return error.UnexpectedFixtureSyntax;
            want_marker = false;
        } else {
            if (row.len >= max_row_code_points) return error.FixtureRowTooLong;
            row.points[row.len] = std.fmt.parseInt(u32, token, 16) catch
                return error.UnexpectedFixtureSyntax;
            row.len += 1;
            want_marker = true;
        }
    }
    // Each row must end with a marker and contain at least two code points.
    if (want_marker or row.len < 2) return error.UnexpectedFixtureSyntax;
    return row;
}

/// Streams data rows from one fixture.
const FixtureRows = struct {
    name: []const u8,
    text: []const u8,
    offset: usize = 0,
    line_number: usize = 0,

    fn next(self: *FixtureRows) ?struct { number: usize, text: []const u8 } {
        while (self.offset < self.text.len) {
            const start = self.offset;
            const end = std.mem.indexOfScalarPos(u8, self.text, start, '\n') orelse self.text.len;
            self.offset = if (end < self.text.len) end + 1 else self.text.len;
            self.line_number += 1;
            const text = self.text[start..end];
            if (text.len == 0 or text[0] == '#') continue;
            return .{ .number = self.line_number, .text = text };
        }
        return null;
    }

    /// Converts parse errors into named conformance failures.
    fn nextParsed(self: *FixtureRows) TestError!?struct { number: usize, row: ParsedRow } {
        const entry = self.next() orelse return null;
        const row = parseRow(entry.text) catch |err| {
            std.debug.print("{s} line {d}: unparsable row ({s})\n", .{ self.name, entry.number, @errorName(err) });
            return error.ConformanceFailure;
        };
        return .{ .number = entry.number, .row = row };
    }
};

fn failOpcode(
    fixture: []const u8,
    line_number: usize,
    index: usize,
    expected: []const u8,
    actual: []const u8,
) error{ConformanceFailure} {
    std.debug.print("{s} line {d} position {d}: expected {s}, got {s}\n", .{
        fixture, line_number, index, expected, actual,
    });
    return error.ConformanceFailure;
}

fn utf8Width(value: u32) usize {
    if (value < 0x80) return 1;
    if (value < 0x800) return 2;
    if (value < 0x10000) return 3;
    return 4;
}

fn utf16Width(value: u32) usize {
    return if (value < 0x10000) 1 else 2;
}

/// Encoded fixture row and code-unit widths for all three encodings.
/// Widths map code-point markers to their code-unit output positions.
const Encoded = struct {
    utf8: [max_row_code_points * 4]u8,
    utf8_len: usize,
    utf16: [max_row_code_points * 2]u16,
    utf16_len: usize,
    utf32: [max_row_code_points]u32,
    widths_utf8: [max_row_code_points]usize,
    widths_utf16: [max_row_code_points]usize,
    /// UTF-32 uses one code unit per code point.
    widths_utf32: [max_row_code_points]usize,
};

fn encodeRow(row: ParsedRow, encoded: *Encoded) void {
    encoded.utf8_len = 0;
    encoded.utf16_len = 0;

    for (row.points[0..row.len], 0..) |value, index| {
        encoded.utf32[index] = value;
        encoded.widths_utf8[index] = utf8Width(value);
        encoded.widths_utf16[index] = utf16Width(value);
        encoded.widths_utf32[index] = 1;

        if (value < 0x80) {
            encoded.utf8[encoded.utf8_len] = @intCast(value);
            encoded.utf8_len += 1;
        } else if (value < 0x800) {
            encoded.utf8[encoded.utf8_len] = @intCast(0xC0 | (value >> 6));
            encoded.utf8[encoded.utf8_len + 1] = @intCast(0x80 | (value & 0x3F));
            encoded.utf8_len += 2;
        } else if (value < 0x10000) {
            encoded.utf8[encoded.utf8_len] = @intCast(0xE0 | (value >> 12));
            encoded.utf8[encoded.utf8_len + 1] = @intCast(0x80 | ((value >> 6) & 0x3F));
            encoded.utf8[encoded.utf8_len + 2] = @intCast(0x80 | (value & 0x3F));
            encoded.utf8_len += 3;
        } else {
            encoded.utf8[encoded.utf8_len] = @intCast(0xF0 | (value >> 18));
            encoded.utf8[encoded.utf8_len + 1] = @intCast(0x80 | ((value >> 12) & 0x3F));
            encoded.utf8[encoded.utf8_len + 2] = @intCast(0x80 | ((value >> 6) & 0x3F));
            encoded.utf8[encoded.utf8_len + 3] = @intCast(0x80 | (value & 0x3F));
            encoded.utf8_len += 4;
        }

        if (value < 0x10000) {
            encoded.utf16[encoded.utf16_len] = @intCast(value);
            encoded.utf16_len += 1;
        } else {
            const rest = value - 0x10000;
            encoded.utf16[encoded.utf16_len] = @intCast(0xD800 | (rest >> 10));
            encoded.utf16[encoded.utf16_len + 1] = @intCast(0xDC00 | (rest & 0x3FF));
            encoded.utf16_len += 2;
        }
    }
}

/// Compares code-unit output with one fixture row using per-encoding widths.
/// Line-fixture checks fold allowed and mandatory breaks; direct tests do not.
fn checkPerCodeUnit(
    comptime O: type,
    fixture: []const u8,
    observed: []const O,
    row: ParsedRow,
    widths: []const usize,
    folds_allow_break: bool,
    line_number: usize,
) TestError!void {
    var at: usize = 0;
    for (0..row.len) |index| {
        const width = widths[index];
        const opcode = observed[at + width - 1];
        const accept = if (row.marks[index + 1])
            if (O == libunibreak.LineOpcode and folds_allow_break)
                opcode == .allow_break or opcode == .must_break or opcode == .indeterminate
            else
                opcode == .allow_break
        else
            opcode == .no_break;
        if (!accept) return failOpcode(fixture, line_number, index, "a break marker", @tagName(opcode));

        for (observed[at .. at + width - 1]) |interior| {
            if (interior != .inside_char) {
                return failOpcode(fixture, line_number, index, "inside_char before the final unit", @tagName(interior));
            }
        }
        at += width;
    }
    if (at != observed.len) {
        std.debug.print("{s} line {d}: pass wrote {d} units, row covers {d}\n", .{
            fixture, line_number, observed.len, at,
        });
        return error.ConformanceFailure;
    }
}

/// Checks per-code-point line output against one fixture row.
fn checkLineCodePoints(
    fixture: []const u8,
    observed: []const libunibreak.LineOpcode,
    row: ParsedRow,
    line_number: usize,
) TestError!void {
    for (0..row.len) |index| {
        const opcode = observed[index];
        const accept: bool = if (row.marks[index + 1]) blk: {
            break :blk opcode == .allow_break or opcode == .must_break or opcode == .indeterminate;
        } else opcode == .no_break;
        if (!accept) return failOpcode(fixture, line_number, index, "a break marker", @tagName(opcode));
    }
}

test "line breaking: every row of LineBreakTest.txt, all three encodings and both per-code-point forms" {
    try loadProvider();
    var rows = FixtureRows{ .name = "LineBreakTest.txt", .text = line_fixture };
    var encoded: Encoded = undefined;
    var reached: usize = 0;

    while (try rows.nextParsed()) |entry| {
        encodeRow(entry.row, &encoded);
        const strict: libunibreak.Language = "-strict";

        var out8: [max_row_code_points * 4]libunibreak.LineOpcode = undefined;
        try libunibreak.Line.perCodeUnit(encoded.utf8[0..encoded.utf8_len], strict, &out8);
        try checkPerCodeUnit(libunibreak.LineOpcode, rows.name, out8[0..encoded.utf8_len], entry.row, &encoded.widths_utf8, true, entry.number);

        var out16: [max_row_code_points * 2]libunibreak.LineOpcode = undefined;
        try libunibreak.Line.perCodeUnit16(encoded.utf16[0..encoded.utf16_len], strict, &out16);
        try checkPerCodeUnit(libunibreak.LineOpcode, rows.name, out16[0..encoded.utf16_len], entry.row, &encoded.widths_utf16, true, entry.number);

        var out32: [max_row_code_points]libunibreak.LineOpcode = undefined;
        try libunibreak.Line.perCodeUnit32(encoded.utf32[0..entry.row.len], strict, &out32);
        try checkPerCodeUnit(libunibreak.LineOpcode, rows.name, out32[0..entry.row.len], entry.row, &encoded.widths_utf32, true, entry.number);

        var points8: [max_row_code_points]libunibreak.LineOpcode = undefined;
        const count8 = try libunibreak.Line.perCodePoint(encoded.utf8[0..encoded.utf8_len], strict, &points8);
        if (count8 != entry.row.len) {
            std.debug.print("LineBreakTest.txt line {d}: per-code-point UTF-8 filled {d} of {d}\n", .{
                entry.number, count8, entry.row.len,
            });
            return error.ConformanceFailure;
        }
        try checkLineCodePoints(rows.name, points8[0..count8], entry.row, entry.number);

        var points16: [max_row_code_points]libunibreak.LineOpcode = undefined;
        const count16 = try libunibreak.Line.perCodePoint16(encoded.utf16[0..encoded.utf16_len], strict, &points16);
        if (count16 != entry.row.len) {
            std.debug.print("LineBreakTest.txt line {d}: per-code-point UTF-16 filled {d} of {d}\n", .{
                entry.number, count16, entry.row.len,
            });
            return error.ConformanceFailure;
        }
        try checkLineCodePoints(rows.name, points16[0..count16], entry.row, entry.number);

        reached += 1;
    }

    try std.testing.expectEqual(expected_line_rows, reached);
}

test "word breaking: every row of WordBreakTest.txt, all three encodings" {
    try loadProvider();
    var rows = FixtureRows{ .name = "WordBreakTest.txt", .text = word_fixture };
    var encoded: Encoded = undefined;
    var reached: usize = 0;

    while (try rows.nextParsed()) |entry| {
        encodeRow(entry.row, &encoded);

        var out8: [max_row_code_points * 4]libunibreak.WordOpcode = undefined;
        try libunibreak.Word.perCodeUnit(encoded.utf8[0..encoded.utf8_len], &out8);
        try checkPerCodeUnit(libunibreak.WordOpcode, rows.name, out8[0..encoded.utf8_len], entry.row, &encoded.widths_utf8, false, entry.number);

        var out16: [max_row_code_points * 2]libunibreak.WordOpcode = undefined;
        try libunibreak.Word.perCodeUnit16(encoded.utf16[0..encoded.utf16_len], &out16);
        try checkPerCodeUnit(libunibreak.WordOpcode, rows.name, out16[0..encoded.utf16_len], entry.row, &encoded.widths_utf16, false, entry.number);

        var out32: [max_row_code_points]libunibreak.WordOpcode = undefined;
        try libunibreak.Word.perCodeUnit32(encoded.utf32[0..entry.row.len], &out32);
        try checkPerCodeUnit(libunibreak.WordOpcode, rows.name, out32[0..entry.row.len], entry.row, &encoded.widths_utf32, false, entry.number);

        reached += 1;
    }

    try std.testing.expectEqual(expected_word_rows, reached);
}

test "grapheme breaking: every row of GraphemeBreakTest.txt, all three encodings" {
    try loadProvider();
    var rows = FixtureRows{ .name = "GraphemeBreakTest.txt", .text = grapheme_fixture };
    var encoded: Encoded = undefined;
    var reached: usize = 0;

    while (try rows.nextParsed()) |entry| {
        encodeRow(entry.row, &encoded);

        var out8: [max_row_code_points * 4]libunibreak.GraphemeOpcode = undefined;
        try libunibreak.Grapheme.perCodeUnit(encoded.utf8[0..encoded.utf8_len], &out8);
        try checkPerCodeUnit(libunibreak.GraphemeOpcode, rows.name, out8[0..encoded.utf8_len], entry.row, &encoded.widths_utf8, false, entry.number);

        var out16: [max_row_code_points * 2]libunibreak.GraphemeOpcode = undefined;
        try libunibreak.Grapheme.perCodeUnit16(encoded.utf16[0..encoded.utf16_len], &out16);
        try checkPerCodeUnit(libunibreak.GraphemeOpcode, rows.name, out16[0..encoded.utf16_len], entry.row, &encoded.widths_utf16, false, entry.number);

        var out32: [max_row_code_points]libunibreak.GraphemeOpcode = undefined;
        try libunibreak.Grapheme.perCodeUnit32(encoded.utf32[0..entry.row.len], &out32);
        try checkPerCodeUnit(libunibreak.GraphemeOpcode, rows.name, out32[0..entry.row.len], entry.row, &encoded.widths_utf32, false, entry.number);

        reached += 1;
    }

    try std.testing.expectEqual(expected_grapheme_rows, reached);
}

test "the final position distinguishes an explicit break from an ordinary one" {
    try loadProvider();
    // Final-position opcodes distinguish explicit breaks from ordinary ends.
    const with_break = [_]u32{ 0x0061, 0x0062, 0x000A };
    var explicit: [3]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&with_break, null, &explicit);
    try std.testing.expectEqual(libunibreak.LineOpcode.must_break, explicit[2]);

    const without_break = [_]u32{ 0x0061, 0x0062 };
    var ordinary: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&without_break, null, &ordinary);
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, ordinary[1]);

    const spaced = [_]u32{ 0x0061, 0x0020, 0x0062 };
    var interior: [3]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&spaced, null, &interior);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, interior[0]);
    try std.testing.expectEqual(libunibreak.LineOpcode.allow_break, interior[1]);
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, interior[2]);
}

test "per-unit opcodes follow completed UTF-8 and UTF-16 code points" {
    try loadProvider();
    // LB9 keeps the combining mark inside its base character.
    const utf8_text = "a\xCC\x81";
    var out8: [3]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit(utf8_text, null, &out8);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, out8[0]);
    try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, out8[1]);
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, out8[2]);

    const utf16_text = [_]u16{ 0x0061, 0x0301 };
    var out16: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit16(&utf16_text, null, &out16);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, out16[0]);
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, out16[1]);

    const utf32_text = [_]u32{ 0x0061, 0x0301 };
    var out32: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&utf32_text, null, &out32);
    for (out32) |opcode| try std.testing.expect(opcode != .inside_char);

    const emoji_text = "a\xF0\x9F\x98\x80";
    var out_emoji: [5]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit(emoji_text, null, &out_emoji);
    for (out_emoji[1..4]) |opcode| {
        try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, opcode);
    }
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, out_emoji[4]);

    var word_out: [3]libunibreak.WordOpcode = undefined;
    try libunibreak.Word.perCodeUnit(utf8_text, &word_out);
    try std.testing.expectEqual(libunibreak.WordOpcode.inside_char, word_out[1]);
    try std.testing.expectEqual(libunibreak.WordOpcode.allow_break, word_out[2]);

    var grapheme_out: [3]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit(utf8_text, &grapheme_out);
    try std.testing.expectEqual(libunibreak.GraphemeOpcode.inside_char, grapheme_out[1]);
    try std.testing.expectEqual(libunibreak.GraphemeOpcode.allow_break, grapheme_out[2]);
}

test "empty input writes nothing at all" {
    try loadProvider();
    // Upstream indexes `posNext - 1` even for empty grapheme input.
    const untouched_line: [4]libunibreak.LineOpcode = @splat(.inside_char);

    var line_out: [4]libunibreak.LineOpcode = undefined;
    @memcpy(&line_out, &untouched_line);
    try libunibreak.Line.perCodeUnit("", null, &line_out);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &untouched_line, &line_out);

    var line_out16: [4]libunibreak.LineOpcode = undefined;
    @memcpy(&line_out16, &untouched_line);
    try libunibreak.Line.perCodeUnit16(&[_]u16{}, null, &line_out16);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &untouched_line, &line_out16);

    var line_out32: [4]libunibreak.LineOpcode = undefined;
    @memcpy(&line_out32, &untouched_line);
    try libunibreak.Line.perCodeUnit32(&[_]u32{}, null, &line_out32);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &untouched_line, &line_out32);

    const untouched_word: [4]libunibreak.WordOpcode = @splat(.inside_char);
    var word_out: [4]libunibreak.WordOpcode = undefined;
    @memcpy(&word_out, &untouched_word);
    try libunibreak.Word.perCodeUnit("", &word_out);
    try std.testing.expectEqualSlices(libunibreak.WordOpcode, &untouched_word, &word_out);

    const untouched_grapheme: [6]libunibreak.GraphemeOpcode = @splat(.inside_char);
    var grapheme_out = untouched_grapheme;
    try libunibreak.Grapheme.perCodeUnit("", grapheme_out[1..5]);
    try std.testing.expectEqualSlices(libunibreak.GraphemeOpcode, &untouched_grapheme, &grapheme_out);
    try libunibreak.Grapheme.perCodeUnit16(&.{}, grapheme_out[1..5]);
    try std.testing.expectEqualSlices(libunibreak.GraphemeOpcode, &untouched_grapheme, &grapheme_out);
    try libunibreak.Grapheme.perCodeUnit32(&.{}, grapheme_out[1..5]);
    try std.testing.expectEqualSlices(libunibreak.GraphemeOpcode, &untouched_grapheme, &grapheme_out);

    // Empty input is not an overlap, regardless of buffer placement.
    try libunibreak.Line.perCodeUnit("", null, line_out[0..0]);
}

test "the per-code-point pass writes one entry per code point and leaves the tail alone" {
    try loadProvider();
    // Capacity is the code-point count, not the UTF-8 byte length.
    const text = "a\xCC\x81";

    var out: [4]libunibreak.LineOpcode = undefined;
    @memset(&out, libunibreak.LineOpcode.inside_char);
    const count = try libunibreak.Line.perCodePoint(text, null, &out);
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, out[0]);
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, out[1]);
    // Entries beyond the returned count remain unchanged.
    try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, out[2]);
    try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, out[3]);

    const units = [_]u16{ 0x0061, 0x0301 };
    var out16: [4]libunibreak.LineOpcode = undefined;
    @memset(&out16, libunibreak.LineOpcode.inside_char);
    const count16 = try libunibreak.Line.perCodePoint16(&units, null, &out16);
    try std.testing.expectEqual(@as(usize, 2), count16);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, out[0..2], out16[0..2]);

    var tight: [3]libunibreak.LineOpcode = undefined;
    @memset(&tight, libunibreak.LineOpcode.inside_char);
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodePoint(text, null, tight[0..1]));
    const filled = try libunibreak.Line.perCodePoint(text, null, &tight);
    try std.testing.expectEqual(@as(usize, 2), filled);
    try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, tight[2]);
}

test "language tailoring is line breaking's alone, matched by prefix" {
    try loadProvider();
    // Under `-strict`, CJ resolves to NS and suppresses the break; otherwise it resolves to ID.
    // The strict expectation is fixture line 279.
    const text = [_]u32{ 0x2757, 0x3041 };

    var untailored: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&text, null, &untailored);
    try std.testing.expectEqual(libunibreak.LineOpcode.allow_break, untailored[0]);

    var strict: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&text, "-strict", &strict);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, strict[0]);

    // Language tags match two-byte prefixes; `null` and `""` disable tailoring.
    const probe = [_]u32{ 0x0041, 0x0020, 0x2018, 0x0042 };
    var bare: [4]libunibreak.LineOpcode = undefined;
    var region: [4]libunibreak.LineOpcode = undefined;
    var same_prefix: [4]libunibreak.LineOpcode = undefined;
    var empty: [4]libunibreak.LineOpcode = undefined;
    var none: [4]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&probe, "en", &bare);
    try libunibreak.Line.perCodeUnit32(&probe, "en-GB", &region);
    try libunibreak.Line.perCodeUnit32(&probe, "enx", &same_prefix);
    try libunibreak.Line.perCodeUnit32(&probe, "", &empty);
    try libunibreak.Line.perCodeUnit32(&probe, null, &none);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &bare, &region);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &bare, &same_prefix);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &empty, &none);
}

test "the pair query agrees with the full pass on a two-character string" {
    try loadProvider();
    // The pair query matches the first full-pass opcode for the same pair.
    const pair = [_]u32{ 0x0041, 0x0020 };

    var pass: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&pair, null, &pass);

    const queried = try libunibreak.Line.breakBetween(0x0041, 0x0020, null);
    try std.testing.expectEqual(pass[0], queried);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, queried);

    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, pass[1]);

    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.breakBetween(0xD800, 0x0041, null));
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.breakBetween(0x0041, 0x110000, null));
}

test "word and grapheme breaking answer different questions about the same text" {
    try loadProvider();
    // The comma stays inside a word; grapheme breaking uses a different vocabulary.
    const text = [_]u32{ 0x0031, 0x002C, 0x0030 };

    var word_out: [3]libunibreak.WordOpcode = undefined;
    try libunibreak.Word.perCodeUnit32(&text, &word_out);
    try std.testing.expectEqual(libunibreak.WordOpcode.no_break, word_out[0]);
    try std.testing.expectEqual(libunibreak.WordOpcode.no_break, word_out[1]);
    try std.testing.expectEqual(libunibreak.WordOpcode.allow_break, word_out[2]);

    var grapheme_out: [3]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit32(&text, &grapheme_out);
    for (grapheme_out) |opcode| {
        try std.testing.expectEqual(libunibreak.GraphemeOpcode.allow_break, opcode);
    }
}

test "an output buffer one entry short is refused, and nothing is written" {
    try loadProvider();
    const text = "abcd";

    var out: [4]libunibreak.LineOpcode = undefined;
    @memset(&out, libunibreak.LineOpcode.must_break);
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodeUnit(text, null, out[0..3]));
    const expected_line: [4]libunibreak.LineOpcode = @splat(.must_break);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &expected_line, &out);
    try libunibreak.Line.perCodeUnit(text, null, &out);

    // Capacity is measured in UTF-16 code units.
    const units = [_]u16{ 0x0061, 0x0062, 0x0063 };
    var out16: [3]libunibreak.WordOpcode = undefined;
    @memset(&out16, libunibreak.WordOpcode.no_break);
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Word.perCodeUnit16(&units, out16[0..2]));
    const expected_word: [3]libunibreak.WordOpcode = @splat(.no_break);
    try std.testing.expectEqualSlices(libunibreak.WordOpcode, &expected_word, &out16);

    var out32: [2]libunibreak.GraphemeOpcode = undefined;
    @memset(&out32, libunibreak.GraphemeOpcode.no_break);
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Grapheme.perCodeUnit32(&[_]u32{ 0x0061, 0x0062, 0x0063 }, &out32));
    const expected_grapheme: [2]libunibreak.GraphemeOpcode = @splat(.no_break);
    try std.testing.expectEqualSlices(libunibreak.GraphemeOpcode, &expected_grapheme, &out32);

    // Per-code-point output needs two entries for either sample.
    var points: [2]libunibreak.LineOpcode = undefined;
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodePoint("a\xCC\x81", null, points[0..1]));
    const paired: [3]u16 = .{ 0xD83D, 0xDE00, 0x0061 };
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodePoint16(&paired, null, points[0..1]));
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodePoint(text, null, out[0..3]));
}

test "an output buffer that shares storage with the input is refused" {
    try loadProvider();
    // Reject output that overlaps unread input bytes.
    var storage: [8]u8 = "abcdXXXX".*;
    const text: []const u8 = storage[0..4];
    const out: []libunibreak.LineOpcode = @as([*]libunibreak.LineOpcode, @ptrCast(storage[2..6].ptr))[0..4];
    try std.testing.expectError(error.InputOutputOverlap, libunibreak.Line.perCodeUnit(text, null, out));
    try std.testing.expectEqualStrings("abcdXXXX", &storage);

    // Touching byte ranges do not overlap.
    var separate: [8]u8 = "abcdYYYY".*;
    const touching: []libunibreak.LineOpcode = @as([*]libunibreak.LineOpcode, @ptrCast(separate[4..8].ptr))[0..4];
    try libunibreak.Line.perCodeUnit(separate[0..4], null, touching);
    try std.testing.expectEqualStrings("abcd", separate[0..4]);

    // Overlap checks use byte widths across different code-unit types.
    var wide: [8]u8 align(2) = undefined;
    @memset(&wide, 0);
    const wide_text: []const u16 = @as([*]const u16, @ptrCast(&wide))[0..2];
    const wide_out: []libunibreak.LineOpcode = @as([*]libunibreak.LineOpcode, @ptrCast(wide[1..3].ptr))[0..2];
    try std.testing.expectError(error.InputOutputOverlap, libunibreak.Line.perCodeUnit16(wide_text, null, wide_out));

    var shared = [_]u8{ 'a', 'b', 0, 0 };
    const shared_text: []const u8 = shared[0..];
    const shared_out: []libunibreak.WordOpcode = @as([*]libunibreak.WordOpcode, @ptrCast(shared[0..2].ptr))[0..2];
    try std.testing.expectError(error.InputOutputOverlap, libunibreak.Word.perCodeUnit(shared_text, shared_out));
}

test "malformed UTF-8 is refused in every shape, and nothing is written" {
    try loadProvider();
    const cases = [_]struct { name: []const u8, bytes: []const u8 }{
        .{ .name = "lone continuation byte", .bytes = "\x80" },
        .{ .name = "overlong NUL", .bytes = "\xC0\x80" },
        .{ .name = "lead above F4", .bytes = "\xF5\x80\x80\x80" },
        .{ .name = "truncated two-byte", .bytes = "\xC2" },
        .{ .name = "bad continuation", .bytes = "\xE0\x41\x80" },
        .{ .name = "truncated three-byte", .bytes = "\xE0\xA0" },
        .{ .name = "overlong three-byte", .bytes = "\xE0\x80\x80" },
        .{ .name = "encoded surrogate", .bytes = "\xED\xA0\x80" },
        .{ .name = "above U+10FFFF", .bytes = "\xF4\x90\x80\x80" },
        .{ .name = "truncated four-byte", .bytes = "\xF0\x9F\x98" },
    };

    const clean: [8]libunibreak.LineOpcode = @splat(.must_break);
    for (cases) |case| {
        var out: [8]libunibreak.LineOpcode = undefined;
        @memcpy(&out, &clean);
        libunibreak.Line.perCodeUnit(case.bytes, null, &out) catch |err| {
            if (err != error.MalformedUtf8) {
                std.debug.print("utf8 case {s}: refused as {s}, not as malformed input\n", .{
                    case.name, @errorName(err),
                });
                return err;
            }
        };
        // Rejection occurs before the output is modified.
        try std.testing.expectEqualSlices(libunibreak.LineOpcode, &clean, &out);

        var word_out: [8]libunibreak.WordOpcode = undefined;
        @memset(&word_out, libunibreak.WordOpcode.no_break);
        try std.testing.expectError(error.MalformedUtf8, libunibreak.Word.perCodeUnit(case.bytes, &word_out));
        var grapheme_out: [8]libunibreak.GraphemeOpcode = undefined;
        @memset(&grapheme_out, libunibreak.GraphemeOpcode.no_break);
        try std.testing.expectError(error.MalformedUtf8, libunibreak.Grapheme.perCodeUnit(case.bytes, &grapheme_out));
        var point_out: [8]libunibreak.LineOpcode = undefined;
        @memcpy(&point_out, &clean);
        try std.testing.expectError(error.MalformedUtf8, libunibreak.Line.perCodePoint(case.bytes, null, &point_out));
    }

    // Valid sequences of each UTF-8 width remain accepted.
    var out: [10]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit("a\xC2\xA9\xE2\x82\xAC\xF0\x9F\x98\x80", null, &out);
}

test "malformed UTF-16 is refused in every shape, and nothing is written" {
    try loadProvider();
    const cases = [_][]const u16{
        // Trailing high surrogate.
        &[_]u16{ 0x0061, 0xD800 },
        // High surrogate followed by a non-low surrogate.
        &[_]u16{ 0xD800, 0x0041 },
        // Unpaired low surrogate.
        &[_]u16{ 0xDC00, 0x0061 },
    };

    const clean: [4]libunibreak.LineOpcode = @splat(.must_break);
    for (cases) |case| {
        var out: [4]libunibreak.LineOpcode = undefined;
        @memcpy(&out, &clean);
        try std.testing.expectError(error.MalformedUtf16, libunibreak.Line.perCodeUnit16(case, null, &out));
        try std.testing.expectEqualSlices(libunibreak.LineOpcode, &clean, &out);

        var word_out: [4]libunibreak.WordOpcode = undefined;
        @memset(&word_out, libunibreak.WordOpcode.no_break);
        try std.testing.expectError(error.MalformedUtf16, libunibreak.Word.perCodeUnit16(case, &word_out));
        var grapheme_out: [4]libunibreak.GraphemeOpcode = undefined;
        @memset(&grapheme_out, libunibreak.GraphemeOpcode.no_break);
        try std.testing.expectError(error.MalformedUtf16, libunibreak.Grapheme.perCodeUnit16(case, &grapheme_out));
        var point_out: [4]libunibreak.LineOpcode = undefined;
        @memcpy(&point_out, &clean);
        try std.testing.expectError(error.MalformedUtf16, libunibreak.Line.perCodePoint16(case, null, &point_out));
    }

    // A surrogate pair uses two UTF-16 units but one code point.
    const paired = [_]u16{ 0x0061, 0xD83D, 0xDE00 };
    var out: [4]libunibreak.LineOpcode = undefined;
    const count = try libunibreak.Line.perCodePoint16(&paired, null, &out);
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "malformed UTF-32 is refused in every shape, and nothing is written" {
    try loadProvider();
    const clean: [4]libunibreak.LineOpcode = @splat(.must_break);
    var out: [4]libunibreak.LineOpcode = undefined;

    @memcpy(&out, &clean);
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.perCodeUnit32(&[_]u32{ 0x0061, 0xD800 }, null, &out));
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &clean, &out);

    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.perCodeUnit32(&[_]u32{ 0x0061, 0x110000 }, null, &out));

    try libunibreak.Line.perCodeUnit32(&[_]u32{ 0x0061, 0x10FFFF }, null, &out);

    var word_out: [4]libunibreak.WordOpcode = undefined;
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Word.perCodeUnit32(&[_]u32{0xDC00}, &word_out));
    var grapheme_out: [4]libunibreak.GraphemeOpcode = undefined;
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Grapheme.perCodeUnit32(&[_]u32{0xD800}, &grapheme_out));
}

test "the cursor advances one code point at a time and stops without moving" {
    try loadProvider();
    // The sequence uses seven UTF-8 bytes for three code points.
    const text = "a\xCC\x81\xF0\x9F\x98\x80";
    const points = [_]u32{ 0x0061, 0x0301, 0x1F600 };
    const ends = [_]usize{ 1, 3, 7 };

    var at: usize = 0;
    for (points, 0..) |expected, unit| {
        const step = try libunibreak.Decode.utf8(text, at);
        try std.testing.expect(!step.end);
        try std.testing.expectEqual(expected, step.code_point);
        // Decoder offsets must match code-unit break positions.
        try std.testing.expectEqual(ends[unit], step.index);
        at = step.index;
    }
    try std.testing.expectEqual(text.len, at);

    const past = try libunibreak.Decode.utf8(text, at);
    try std.testing.expect(past.end);
    try std.testing.expectEqual(at, past.index);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0), past.code_point);

    try std.testing.expectError(error.IndexPastEnd, libunibreak.Decode.utf8(text, text.len + 1));
    try std.testing.expectError(error.IndexPastEnd, libunibreak.Decode.utf16(&.{}, 1));
    try std.testing.expectError(error.IndexPastEnd, libunibreak.Decode.utf32(&.{}, 1));
}

test "a truncated sequence ends the cursor rather than reporting a character" {
    try loadProvider();
    const truncated = "\xC2";
    const step = try libunibreak.Decode.utf8(truncated, 0);
    try std.testing.expect(step.end);
    try std.testing.expectEqual(@as(usize, 0), step.index);

    // A trailing high surrogate reports end without advancing.
    const lone_surrogate = [_]u16{0xD83D};
    const step16 = try libunibreak.Decode.utf16(&lone_surrogate, 0);
    try std.testing.expect(step16.end);
    try std.testing.expectEqual(@as(usize, 0), step16.index);

    // A nontrailing high surrogate is returned as a value by upstream.
    const unpaired = [_]u16{ 0xD83D, 0x0041 };
    const step_unpaired = try libunibreak.Decode.utf16(&unpaired, 0);
    try std.testing.expect(!step_unpaired.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0xD83D), step_unpaired.code_point);
    try std.testing.expectEqual(@as(usize, 1), step_unpaired.index);

    // A valid surrogate pair decodes as one code point.
    const pair = [_]u16{ 0xD83D, 0xDE00 };
    const step_pair = try libunibreak.Decode.utf16(&pair, 0);
    try std.testing.expect(!step_pair.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0x1F600), step_pair.code_point);
    try std.testing.expectEqual(@as(usize, 2), step_pair.index);

    const single = [_]u32{0x1F600};
    const step32 = try libunibreak.Decode.utf32(&single, 0);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0x1F600), step32.code_point);
    try std.testing.expectEqual(@as(usize, 1), step32.index);
}

test "a UTF-32 unit holding U+FFFFFFFF is a character, not the end of the input" {
    try loadProvider();
    // `0xFFFFFFFF` is both `EOS` and a valid UTF-32 unit; the decoder distinguishes them by index.
    // Stored values advance the index; end-of-input leaves it unchanged.
    const units = [_]u32{ 0x0061, 0xFFFFFFFF, 0x0062 };

    const sentinel = try libunibreak.Decode.utf32(&units, 1);
    try std.testing.expect(!sentinel.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0xFFFFFFFF), sentinel.code_point);
    try std.testing.expectEqual(@as(usize, 2), sentinel.index);

    const after = try libunibreak.Decode.utf32(&units, sentinel.index);
    try std.testing.expect(!after.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0x0062), after.code_point);
    try std.testing.expectEqual(@as(usize, 3), after.index);

    const past = try libunibreak.Decode.utf32(&units, units.len);
    try std.testing.expect(past.end);
    try std.testing.expectEqual(@as(usize, 3), past.index);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0), past.code_point);

    const empty = try libunibreak.Decode.utf32(&[_]u32{}, 0);
    try std.testing.expect(empty.end);
    try std.testing.expectEqual(@as(usize, 0), empty.index);

    var at: usize = 0;
    var reached: usize = 0;
    while (true) {
        const step = try libunibreak.Decode.utf32(&units, at);
        if (step.end) break;
        try std.testing.expect(step.index > at);
        at = step.index;
        reached += 1;
    }
    try std.testing.expectEqual(@as(usize, 3), reached);
    try std.testing.expectEqual(@as(usize, 3), at);

    const surrogate = try libunibreak.Decode.utf32(&[_]u32{ 0x0061, 0xD800, 0x0062 }, 1);
    try std.testing.expect(!surrogate.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0xD800), surrogate.code_point);
    try std.testing.expectEqual(@as(usize, 2), surrogate.index);

    // Break passes reject non-scalars that `Decode` returns verbatim.
    var out: [3]libunibreak.LineOpcode = undefined;
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.perCodeUnit32(&units, null, &out));
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.breakBetween(0x0061, 0xFFFFFFFF, null));
}
