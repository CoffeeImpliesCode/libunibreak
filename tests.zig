//! Behaviour tests for the `libunibreak` package.
//!
//! The centrepiece is conformance. `src/LineBreakTest.txt`,
//! `src/WordBreakTest.txt` and `src/GraphemeBreakTest.txt` are the three test
//! files Unicode publishes with UAX #14 and UAX #29, shipped unmodified in the
//! upstream checkout and used in place — there is no `testdata/` copy. **Every**
//! data row of all three is replayed here, with no sampling and no skip list,
//! and each test asserts the row count it reached, so a pass states that it
//! covered the whole file rather than an error-free prefix. The expectations
//! were produced by the Unicode consortium, not by this fork and not by
//! libunibreak.
//!
//! What each row is checked against, and how:
//!
//!   * All three encodings independently. Every row is encoded to UTF-8, UTF-16
//!     and UTF-32 by this harness and run through the native pass in all three,
//!     so a decoder disagreement between them cannot pass unnoticed.
//!   * Per-unit markers. Where a code point occupies more than one code unit,
//!     every trailing unit must carry `insideChar` and only the leading unit
//!     carries the real opcode. That is upstream's documented behaviour
//!     (`src/linebreak.c:1461-1464`, `src/wordbreak.c:117-119`,
//!     `src/graphemebreak.c:162`) and it is the part a facade most easily gets
//!     wrong.
//!   * Per-code-point line output. The two native per-code-point line entry
//!     points (UTF-8 and UTF-16) are run as well, and the count each returns
//!     must equal the code point count of the row.
//!
//! The line fixture is compared under `"-strict"`, the tailoring upstream's own
//! harness uses (`src/tests.c:250`). The Unicode files cannot express "break
//! allowed" as against "break mandatory", so for the oracle comparison only a
//! break expectation accepts either `must_break` or `allow_break`. **That fold
//! lives only in the fixture comparison.** The direct behaviour tests below
//! assert `must_break` and `indeterminate` as the distinct values they are,
//! which is what the typed API promises.
//!
//! The rest of this file covers what no fixture can reach: the empty input, the
//! final-position distinction, the per-code-point count and the untouched tail,
//! language tailoring and its prefix matching, the pair query, the fact that
//! the word and grapheme vocabularies answer different questions about the same
//! text, and every refusal this package makes — undersized output,
//! input/output overlap, and malformed encoding in each of the three encodings,
//! each checked to leave the output buffer exactly as the caller passed it.
//!
//! This file is the test root. Because it sits at the package root, its module
//! root directory is the package directory, which is what lets `@embedFile`
//! reach `src/`.
//!
//! ## The provider, in a runtime-loading build
//!
//! Nothing native is linked into the module under `-Druntime=true`, so every
//! case below needs a provider before it can ask the library anything. The
//! provider is named by `LIBUNIBREAK_TEST_PROVIDER`, an absolute path to a
//! shared object exporting the eighteen functions and the `unibreak_version`
//! object of the five public headers. A linked build links the library and has
//! nothing to load, so [loadProvider] returns immediately there and every case
//! is an ordinary direct call.
//!
//! Nothing is skipped when the variable is missing. In a runtime-loading build
//! a case that cannot name a provider has nothing to test, and passing anyway
//! would say nothing at all, so the run fails and says which variable to set.

const std = @import("std");
const libunibreak = @import("libunibreak");

/// A shared object exporting the eighteen functions and the `unibreak_version`
/// object of the five public headers.
const provider_variable = "LIBUNIBREAK_TEST_PROVIDER";

/// A directory no machine has, which is what makes the open failure below a real
/// one rather than a guess about what might be missing.
const absent_provider = "/libunibreak-no-such-directory/libunibreak.so";

/// What can be wrong with this file's own setup rather than with the library.
const Setup = error{MissingProvider};

/// The provider this process is using, or null when none has loaded yet.
fn inUse() ?[]const u8 {
    const source = libunibreak.loadedSource() orelse return null;
    return switch (source) {
        .path => |p| p,
        .system => |s| s,
    };
}

/// Load the configured provider, once, if this build needs one at all.
///
/// A linked build links `set_linebreaks*` and has nothing to load, so this
/// returns immediately there and every case below is a direct call. A
/// runtime-loading build has to be told, and the only two outcomes that mean
/// anything are "a provider is in use" and "there is none"; the middle state is
/// not a third thing a caller has to handle, so it reports the error instead.
///
/// The value is copied by the loader, which keeps its own copy for the life of
/// the process, so the environment block it came from is released here.
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

// ---------------------------------------------------------------------------
// Which provider is in use
//
// These two cases are the loader's own lifecycle, and they sit above everything
// else on purpose. The loader is process-global with no unload and no reset, so
// "nothing has loaded yet" is a state this file is in exactly once; a case that
// needed it again later could only be asserting about a state it could not
// reach. In a linked build both are skipped, because there is no provider, no
// table and nothing to resolve.
// ---------------------------------------------------------------------------

test "a request that names nothing is refused before the platform is called" {
    if (!libunibreak.runtime_loaded) return error.SkipZigTest;
    try std.testing.expect(inUse() == null);

    try std.testing.expectError(error.EmptySource, libunibreak.load(.{ .path = "" }));
    try std.testing.expectError(error.EmptySource, libunibreak.load(.{ .system = "" }));

    // Neither reached the platform, and neither published anything.
    try std.testing.expect(inUse() == null);
}

test "a provider that cannot be opened publishes nothing, and the retry is the caller's to make" {
    if (!libunibreak.runtime_loaded) return error.SkipZigTest;
    try std.testing.expect(inUse() == null);

    // A path under a directory no machine has. The attempt fails and, being a
    // failure, leaves no table behind: there is no partial state to call
    // through, and the next call still sees an unloaded module.
    try std.testing.expectError(error.OpenFailed, libunibreak.load(.{ .path = absent_provider }));
    try std.testing.expect(inUse() == null);

    // Nothing retries by itself. This call is the retry, and it is the only way
    // forward.
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

/// The number of data rows in each fixture, as each file's own footer states it
/// (`# Lines: 19338`, `# Lines: 1944`, `# Lines: 766`). The conformance tests
/// assert they reached exactly these, so a row that failed to parse — and was
/// therefore skipped — turns the test red instead of quietly reducing coverage.
const expected_line_rows = 19338;
const expected_word_rows = 1944;
const expected_grapheme_rows = 766;

/// The longest row in the three fixtures is 199 code points, which bounds every
/// fixed buffer here. A longer row is a loud failure, never a truncation.
const max_row_code_points = 256;

const TestError = libunibreak.Error || error{
    ConformanceFailure,
    FixtureRowTooLong,
    UnexpectedFixtureSyntax,
    /// This is a runtime-loading build and no provider was named, so there is
    /// nothing to call. See [loadProvider].
    MissingProvider,
};

// ---------------------------------------------------------------------------
// Fixture parsing
// ---------------------------------------------------------------------------

/// One parsed fixture row: its code points, and one marker per gap.
///
/// `marks[i]` is the marker **before** `points[i]`, and `marks[len]` is the
/// trailing marker after the last code point. `marks[0]` is the marker the
/// format puts before the very first code point; no entry of any output buffer
/// reports a break there, so it is parsed and never compared — upstream's own
/// harness writes it into position 0 and starts the library one position later
/// (`src/tests.c:246-260`).
const ParsedRow = struct {
    points: [max_row_code_points]u32,
    marks: [max_row_code_points + 1]bool,
    len: usize,
};

fn isSpace(byte: u8) bool {
    return byte == ' ' or byte == '\t';
}

/// Whitespace-separated tokens of a fixture data segment.
///
/// Hand-rolled rather than taken from `std.mem` because the separator set is
/// exactly space and TAB — every row contains one TAB, which separates the data
/// from its `#` comment — and because a row containing an unexpected character
/// has to be reported rather than quietly tokenised away.
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

/// The two break markers in the file's own UTF-8 bytes: `÷` is U+00F7 and `×` is
/// U+00D7. `src/tests.c:206-220` matches the same two byte pairs.
fn markerAllowsBreak(token: []const u8) ?bool {
    if (std.mem.eql(u8, token, "\xC3\xB7")) return true;
    if (std.mem.eql(u8, token, "\xC3\x97")) return false;
    return null;
}

/// Parses one whole fixture line into `row`.
///
/// The comment after `#` is dropped first, exactly as `src/tests.c:230-233`
/// does. Anything the format does not allow is an error, so no row can be lost
/// without the test failing.
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
    // A row ends with a marker and has at least two code points.
    if (want_marker or row.len < 2) return error.UnexpectedFixtureSyntax;
    return row;
}

/// A streaming walk over one fixture's data rows.
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

    /// Parses the next row, turning a parse failure into a named conformance
    /// failure rather than a bare error the reader has to decode.
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

// ---------------------------------------------------------------------------
// Encoding a row into the three forms, and checking one pass back
// ---------------------------------------------------------------------------

fn utf8Width(value: u32) usize {
    if (value < 0x80) return 1;
    if (value < 0x800) return 2;
    if (value < 0x10000) return 3;
    return 4;
}

fn utf16Width(value: u32) usize {
    return if (value < 0x10000) 1 else 2;
}

/// The three encodings of one row, plus the code unit width of each code point
/// in each of them.
///
/// The widths are what turns "the oracle expects no break before code point
/// `i`" into "entry `i * width[i]` of this buffer must say so and the entries
/// after it must say `insideChar`". Every buffer is filled in place, so a row is
/// encoded once and never copied.
const Encoded = struct {
    utf8: [max_row_code_points * 4]u8,
    utf8_len: usize,
    utf16: [max_row_code_points * 2]u16,
    utf16_len: usize,
    utf32: [max_row_code_points]u32,
    widths_utf8: [max_row_code_points]usize,
    widths_utf16: [max_row_code_points]usize,
    /// Every UTF-32 code point is one unit; kept as a buffer so the same check
    /// serves all three encodings.
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

/// Checks a per-code-unit pass against one fixture row.
///
/// `widths[i]` is how many code units code point `i` occupies in the encoding
/// this pass ran over, so the leading unit carries the opcode and every trailing
/// unit must be `insideChar`.
///
/// `folds_allow_break` is the oracle-only concession for line breaking. It is
/// `false` for word and grapheme, whose fixtures do express the difference, and
/// `false` in every direct behaviour test in this file.
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

/// Checks a per-code-point line pass against one fixture row.
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

// ---------------------------------------------------------------------------
// Conformance
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Direct behaviour
// ---------------------------------------------------------------------------

test "the final position distinguishes an explicit break from an ordinary one" {
    try loadProvider();
    // UAX #14 rules LB4, LB5 and LB6 make the break after a mandatory-break
    // character mandatory, so text ending in one ends in `must_break`. Text that
    // does not ends in `indeterminate`, which the Unicode oracle cannot express
    // and which upstream's own harness folds away (`src/tests.c:266-273`). The
    // typed API keeps them apart, so this test asserts both by name instead of
    // folding.
    const with_break = [_]u32{ 0x0061, 0x0062, 0x000A };
    var explicit: [3]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&with_break, null, &explicit);
    try std.testing.expectEqual(libunibreak.LineOpcode.must_break, explicit[2]);

    const without_break = [_]u32{ 0x0061, 0x0062 };
    var ordinary: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&without_break, null, &ordinary);
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, ordinary[1]);

    // An `allow_break` at an interior position is a third thing again, and none
    // of the three is interchangeable with the others.
    const spaced = [_]u32{ 0x0061, 0x0020, 0x0062 };
    var interior: [3]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&spaced, null, &interior);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, interior[0]);
    try std.testing.expectEqual(libunibreak.LineOpcode.allow_break, interior[1]);
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, interior[2]);
}

test "per-unit opcodes follow completed UTF-8 and UTF-16 code points" {
    try loadProvider();
    // LB9 prohibits a break before the combining mark. Its final code unit
    // carries the final indeterminate break, not an interior-unit marker.
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

    // In UTF-32 there is no continuation unit to mark, so `inside_char` cannot
    // appear at all: the two units are the same thing here.
    const utf32_text = [_]u32{ 0x0061, 0x0301 };
    var out32: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&utf32_text, null, &out32);
    for (out32) |opcode| try std.testing.expect(opcode != .inside_char);

    // A four-unit code point: U+1F600 GRINNING FACE after "a".
    const emoji_text = "a\xF0\x9F\x98\x80";
    var out_emoji: [5]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit(emoji_text, null, &out_emoji);
    for (out_emoji[1..4]) |opcode| {
        try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, opcode);
    }
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, out_emoji[4]);

    // The same rule in the other two vocabularies.
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
    // Native grapheme breaking indexes posNext - 1 even for empty input.
    // Check the surrounding guard as well as the passed output region.
    const untouched_line = [_]libunibreak.LineOpcode{.inside_char} ** 4;

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

    const untouched_word = [_]libunibreak.WordOpcode{.inside_char} ** 4;
    var word_out: [4]libunibreak.WordOpcode = undefined;
    @memcpy(&word_out, &untouched_word);
    try libunibreak.Word.perCodeUnit("", &word_out);
    try std.testing.expectEqualSlices(libunibreak.WordOpcode, &untouched_word, &word_out);

    const untouched_grapheme = [_]libunibreak.GraphemeOpcode{.inside_char} ** 6;
    var grapheme_out = untouched_grapheme;
    try libunibreak.Grapheme.perCodeUnit("", grapheme_out[1..5]);
    try std.testing.expectEqualSlices(libunibreak.GraphemeOpcode, &untouched_grapheme, &grapheme_out);
    try libunibreak.Grapheme.perCodeUnit16(&.{}, grapheme_out[1..5]);
    try std.testing.expectEqualSlices(libunibreak.GraphemeOpcode, &untouched_grapheme, &grapheme_out);
    try libunibreak.Grapheme.perCodeUnit32(&.{}, grapheme_out[1..5]);
    try std.testing.expectEqualSlices(libunibreak.GraphemeOpcode, &untouched_grapheme, &grapheme_out);

    // A zero-length input is not an overlap with anything, however the caller's
    // two buffers are arranged.
    try libunibreak.Line.perCodeUnit("", null, line_out[0..0]);
}

test "the per-code-point pass writes one entry per code point and leaves the tail alone" {
    try loadProvider();
    // The bound is the code point count, not the code unit count: three UTF-8
    // bytes here, two code points, two entries. Upstream never computes that
    // count for the caller — its own harness over-allocates to the input length
    // (`src/tests.c:188-190`) — which is the buffer problem this facade closes.
    const text = "a\xCC\x81";

    var out: [4]libunibreak.LineOpcode = undefined;
    @memset(&out, libunibreak.LineOpcode.inside_char);
    const count = try libunibreak.Line.perCodePoint(text, null, &out);
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, out[0]);
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, out[1]);
    // Entries past the returned count are residue and keep the caller's values.
    try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, out[2]);
    try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, out[3]);

    const units = [_]u16{ 0x0061, 0x0301 };
    var out16: [4]libunibreak.LineOpcode = undefined;
    @memset(&out16, libunibreak.LineOpcode.inside_char);
    const count16 = try libunibreak.Line.perCodePoint16(&units, null, &out16);
    try std.testing.expectEqual(@as(usize, 2), count16);
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, out[0..2], out16[0..2]);

    // One entry is too small; a spare third entry must remain untouched.
    var tight: [3]libunibreak.LineOpcode = undefined;
    @memset(&tight, libunibreak.LineOpcode.inside_char);
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodePoint(text, null, tight[0..1]));
    const filled = try libunibreak.Line.perCodePoint(text, null, &tight);
    try std.testing.expectEqual(@as(usize, 2), filled);
    try std.testing.expectEqual(libunibreak.LineOpcode.inside_char, tight[2]);
}

test "language tailoring is line breaking's alone, matched by prefix" {
    try loadProvider();
    // U+3041 HIRAGANA LETTER SMALL A has line break class CJ. `resolve_lb_class`
    // (`src/linebreak.c:678-682`) resolves CJ to NS under `-strict` and to ID
    // otherwise. The pair table then gives `AL × NS` no break
    // (`baTable[AL][NS] = IND_BRK` with no preceding space, `:209-216`) but
    // `AL × ID` a direct one (`DIR_BRK`). U+2757 HEAVY EXCLAMATION MARK SYMBOL is
    // AI, which resolves to AL for any language that is not zh, ja or ko.
    //
    // The strict half of this is the published expectation:
    // `LineBreakTest.txt` line 279, `× 2757 × 3041 ÷`, which upstream's harness
    // replays with `lang = "-strict"`.
    const text = [_]u32{ 0x2757, 0x3041 };

    var untailored: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&text, null, &untailored);
    try std.testing.expectEqual(libunibreak.LineOpcode.allow_break, untailored[0]);

    var strict: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&text, "-strict", &strict);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, strict[0]);

    // Matching is by two-byte prefix (`src/linebreakdef.c:120-128` with
    // `strncmp` at `src/linebreak.c:566`), so a region tag whose prefix is a
    // known language tailors identically to the bare language, and an arbitrary
    // string that happens to start the same way does too. No tailoring is `null`
    // and `""` alike: `is_lang_cjk`, `ends_with` and the map walk all read a
    // two-byte prefix, which an empty string never matches.
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
    // `is_line_breakable` returns `brks[0]` of a two-code-point run
    // (`src/linebreak.c:1656-1667`), so it must equal the first entry a
    // per-code-unit UTF-32 pass produces for the same pair. Rule LB7 forbids a
    // break before a space, so the answer for "A" then " " is `no_break`.
    const pair = [_]u32{ 0x0041, 0x0020 };

    var pass: [2]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&pair, null, &pass);

    const queried = try libunibreak.Line.breakBetween(0x0041, 0x0020, null);
    try std.testing.expectEqual(pass[0], queried);
    try std.testing.expectEqual(libunibreak.LineOpcode.no_break, queried);

    // The final position of that run is indeterminate, which the pair query does
    // not report and the pass does.
    try std.testing.expectEqual(libunibreak.LineOpcode.indeterminate, pass[1]);

    // A surrogate is not a code point and a value above U+10FFFF is not
    // either; neither is handed to a decoder that would accept it.
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.breakBetween(0xD800, 0x0041, null));
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.breakBetween(0x0041, 0x110000, null));
}

test "word and grapheme breaking answer different questions about the same text" {
    try loadProvider();
    // "1,0". `WordBreakTest.txt` line 1729 publishes `÷ 0031 × 002C × 0030 ÷`,
    // so a word boundary appears neither at the comma nor at the zero (rules
    // WB11 and WB12). Grapheme breaking has no notion of a word: UAX #29 rule
    // GB999 puts a boundary at every one of these positions. One input, two
    // vocabularies, two published answers, three different enum types.
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

// ---------------------------------------------------------------------------
// The refusals. Each one is checked to arrive before any output byte is written.
// ---------------------------------------------------------------------------

test "an output buffer one entry short is refused, and nothing is written" {
    try loadProvider();
    const text = "abcd";

    var out: [4]libunibreak.LineOpcode = undefined;
    @memset(&out, libunibreak.LineOpcode.must_break);
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodeUnit(text, null, out[0..3]));
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &[_]libunibreak.LineOpcode{.must_break} ** 4, &out);
    try libunibreak.Line.perCodeUnit(text, null, &out);

    // The same bound applies in every encoding and to every vocabulary: three
    // UTF-16 code units are three entries, not two.
    const units = [_]u16{ 0x0061, 0x0062, 0x0063 };
    var out16: [3]libunibreak.WordOpcode = undefined;
    @memset(&out16, libunibreak.WordOpcode.no_break);
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Word.perCodeUnit16(&units, out16[0..2]));
    try std.testing.expectEqualSlices(libunibreak.WordOpcode, &[_]libunibreak.WordOpcode{.no_break} ** 3, &out16);

    var out32: [2]libunibreak.GraphemeOpcode = undefined;
    @memset(&out32, libunibreak.GraphemeOpcode.no_break);
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Grapheme.perCodeUnit32(&[_]u32{ 0x0061, 0x0062, 0x0063 }, &out32));
    try std.testing.expectEqualSlices(libunibreak.GraphemeOpcode, &[_]libunibreak.GraphemeOpcode{.no_break} ** 2, &out32);

    // A per-code-point pass needs the code point count, which for three UTF-8
    // bytes of two code points is two, and for a surrogate pair plus a letter is
    // two as well.
    var points: [2]libunibreak.LineOpcode = undefined;
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodePoint("a\xCC\x81", null, points[0..1]));
    const paired: [3]u16 = .{ 0xD83D, 0xDE00, 0x0061 };
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodePoint16(&paired, null, points[0..1]));
    try std.testing.expectError(error.OutputTooSmall, libunibreak.Line.perCodePoint(text, null, out[0..3]));
}

test "an output buffer that shares storage with the input is refused" {
    try loadProvider();
    // One buffer, viewed twice: the text is "abcd" in the first four bytes and
    // the opcodes are the next four. Writing an opcode would overwrite a code
    // unit the native pass has not read yet, so the call is refused rather than
    // executed in either order.
    var storage: [8]u8 = "abcdXXXX".*;
    const text: []const u8 = storage[0..4];
    const out: []libunibreak.LineOpcode = @as([*]libunibreak.LineOpcode, @ptrCast(storage[2..6].ptr))[0..4];
    try std.testing.expectError(error.InputOutputOverlap, libunibreak.Line.perCodeUnit(text, null, out));
    try std.testing.expectEqualStrings("abcdXXXX", &storage);

    // Byte ranges that only touch do not overlap: the output starting exactly
    // where the input ends is accepted, and the input really is read.
    var separate: [8]u8 = "abcdYYYY".*;
    const touching: []libunibreak.LineOpcode = @as([*]libunibreak.LineOpcode, @ptrCast(separate[4..8].ptr))[0..4];
    try libunibreak.Line.perCodeUnit(separate[0..4], null, touching);
    try std.testing.expectEqualStrings("abcd", separate[0..4]);

    // The same rule with different code unit widths on the two sides: two UTF-16
    // code units are four bytes, so an output buffer inside them overlaps.
    var wide: [8]u8 align(2) = undefined;
    @memset(&wide, 0);
    const wide_text: []const u16 = @as([*]const u16, @ptrCast(&wide))[0..2];
    const wide_out: []libunibreak.LineOpcode = @as([*]libunibreak.LineOpcode, @ptrCast(wide[1..3].ptr))[0..2];
    try std.testing.expectError(error.InputOutputOverlap, libunibreak.Line.perCodeUnit16(wide_text, null, wide_out));

    // And in the other two vocabularies.
    var shared = [_]u8{ 'a', 'b', 0, 0 };
    const shared_text: []const u8 = shared[0..];
    const shared_out: []libunibreak.WordOpcode = @as([*]libunibreak.WordOpcode, @ptrCast(shared[0..2].ptr))[0..2];
    try std.testing.expectError(error.InputOutputOverlap, libunibreak.Word.perCodeUnit(shared_text, shared_out));
}

test "malformed UTF-8 is refused in every shape, and nothing is written" {
    try loadProvider();
    const cases = [_]struct { name: []const u8, bytes: []const u8 }{
        // A continuation byte in lead position.
        .{ .name = "lone continuation byte", .bytes = "\x80" },
        // The overlong two-byte leads 0xC0 and 0xC1.
        .{ .name = "overlong NUL", .bytes = "\xC0\x80" },
        // A lead byte above the encodable range.
        .{ .name = "lead above F4", .bytes = "\xF5\x80\x80\x80" },
        // A two-byte sequence cut short by the end of input.
        .{ .name = "truncated two-byte", .bytes = "\xC2" },
        // A three-byte sequence with a non-continuation in the middle.
        .{ .name = "bad continuation", .bytes = "\xE0\x41\x80" },
        // A three-byte sequence cut short.
        .{ .name = "truncated three-byte", .bytes = "\xE0\xA0" },
        // The overlong three-byte encoding of U+0000.
        .{ .name = "overlong three-byte", .bytes = "\xE0\x80\x80" },
        // U+D800 encoded, which no scalar value may be.
        .{ .name = "encoded surrogate", .bytes = "\xED\xA0\x80" },
        // U+110000, one past the last scalar value.
        .{ .name = "above U+10FFFF", .bytes = "\xF4\x90\x80\x80" },
        // A four-byte sequence cut short.
        .{ .name = "truncated four-byte", .bytes = "\xF0\x9F\x98" },
    };

    const clean = [_]libunibreak.LineOpcode{.must_break} ** 8;
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
        // The buffer still holds the caller's values, so the refusal arrived
        // before any write.
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

    // A well-formed sequence of every length is accepted, so the refusals above
    // are about encoding and not about size.
    var out: [10]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit("a\xC2\xA9\xE2\x82\xAC\xF0\x9F\x98\x80", null, &out);
}

test "malformed UTF-16 is refused in every shape, and nothing is written" {
    try loadProvider();
    const cases = [_][]const u16{
        // A high surrogate with nothing behind it.
        &[_]u16{ 0x0061, 0xD800 },
        // A high surrogate followed by something that is not a low surrogate.
        &[_]u16{ 0xD800, 0x0041 },
        // A low surrogate with no high surrogate in front of it.
        &[_]u16{ 0xDC00, 0x0061 },
    };

    const clean = [_]libunibreak.LineOpcode{.must_break} ** 4;
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

    // A well-formed surrogate pair is two code units and one code point, so
    // "a" followed by U+1F600 is two entries, not three.
    const paired = [_]u16{ 0x0061, 0xD83D, 0xDE00 };
    var out: [4]libunibreak.LineOpcode = undefined;
    const count = try libunibreak.Line.perCodePoint16(&paired, null, &out);
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "malformed UTF-32 is refused in every shape, and nothing is written" {
    try loadProvider();
    const clean = [_]libunibreak.LineOpcode{.must_break} ** 4;
    var out: [4]libunibreak.LineOpcode = undefined;

    // A surrogate is not a scalar value.
    @memcpy(&out, &clean);
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.perCodeUnit32(&[_]u32{ 0x0061, 0xD800 }, null, &out));
    try std.testing.expectEqualSlices(libunibreak.LineOpcode, &clean, &out);

    // One past the last scalar value.
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.perCodeUnit32(&[_]u32{ 0x0061, 0x110000 }, null, &out));

    // The largest legal value is accepted.
    try libunibreak.Line.perCodeUnit32(&[_]u32{ 0x0061, 0x10FFFF }, null, &out);

    var word_out: [4]libunibreak.WordOpcode = undefined;
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Word.perCodeUnit32(&[_]u32{0xDC00}, &word_out));
    var grapheme_out: [4]libunibreak.GraphemeOpcode = undefined;
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Grapheme.perCodeUnit32(&[_]u32{0xD800}, &grapheme_out));
}

// ---------------------------------------------------------------------------
// The code-point cursor
// ---------------------------------------------------------------------------

test "the cursor advances one code point at a time and stops without moving" {
    try loadProvider();
    // "a", U+0301, U+1F600: one, two and four UTF-8 bytes, so seven code units
    // for three code points.
    const text = "a\xCC\x81\xF0\x9F\x98\x80";
    const points = [_]u32{ 0x0061, 0x0301, 0x1F600 };
    // Where each code point ends, in bytes: after one, after three, after seven.
    const ends = [_]usize{ 1, 3, 7 };

    var at: usize = 0;
    for (points, 0..) |expected, unit| {
        const step = try libunibreak.Decode.utf8(text, at);
        try std.testing.expect(!step.end);
        try std.testing.expectEqual(expected, step.code_point);
        // The unit widths are what the break passes write one entry per, so the
        // cursor and a per-code-unit pass must agree on where each code point is.
        try std.testing.expectEqual(ends[unit], step.index);
        at = step.index;
    }
    try std.testing.expectEqual(text.len, at);

    // At the end the decoder answers EOS and leaves the index alone, so a loop
    // that stops on `end` cannot spin.
    const past = try libunibreak.Decode.utf8(text, at);
    try std.testing.expect(past.end);
    try std.testing.expectEqual(at, past.index);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0), past.code_point);

    // An index past the end is refused. `src/unibreakdef.c:59` only asserts it,
    // and that assert is gone in the two release optimize modes.
    try std.testing.expectError(error.IndexPastEnd, libunibreak.Decode.utf8(text, text.len + 1));
    try std.testing.expectError(error.IndexPastEnd, libunibreak.Decode.utf16(&.{}, 1));
    try std.testing.expectError(error.IndexPastEnd, libunibreak.Decode.utf32(&.{}, 1));
}

test "a truncated sequence ends the cursor rather than reporting a character" {
    try loadProvider();
    // The two-byte sequence for U+00E9 with its second byte missing.
    const truncated = "\xC2";
    const step = try libunibreak.Decode.utf8(truncated, 0);
    try std.testing.expect(step.end);
    // `src/unibreakdef.c:73-76` returns EOS without advancing, so the caller
    // learns that the input ended mid-sequence and not that a character was read.
    try std.testing.expectEqual(@as(usize, 0), step.index);

    // The same in UTF-16: a high surrogate with nothing behind it is
    // `src/unibreakdef.c:138-142`, which rewinds the index it had already
    // advanced and answers EOS.
    const lone_surrogate = [_]u16{0xD83D};
    const step16 = try libunibreak.Decode.utf16(&lone_surrogate, 0);
    try std.testing.expect(step16.end);
    try std.testing.expectEqual(@as(usize, 0), step16.index);

    // A high surrogate followed by something that is not a low surrogate is not
    // truncated: upstream returns the surrogate value itself and advances one
    // unit (`src/unibreakdef.c:143-146`), and the cursor reports exactly that
    // rather than substituting an error the native call never made.
    const unpaired = [_]u16{ 0xD83D, 0x0041 };
    const step_unpaired = try libunibreak.Decode.utf16(&unpaired, 0);
    try std.testing.expect(!step_unpaired.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0xD83D), step_unpaired.code_point);
    try std.testing.expectEqual(@as(usize, 1), step_unpaired.index);

    // A well-formed pair is one code point over two units.
    const pair = [_]u16{ 0xD83D, 0xDE00 };
    const step_pair = try libunibreak.Decode.utf16(&pair, 0);
    try std.testing.expect(!step_pair.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0x1F600), step_pair.code_point);
    try std.testing.expectEqual(@as(usize, 2), step_pair.index);

    // And a UTF-32 pass never invents a surrogate pair, because a unit is a
    // code point there.
    const single = [_]u32{0x1F600};
    const step32 = try libunibreak.Decode.utf32(&single, 0);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0x1F600), step32.code_point);
    try std.testing.expectEqual(@as(usize, 1), step32.index);
}

test "a UTF-32 unit holding U+FFFFFFFF is a character, not the end of the input" {
    try loadProvider();
    // `0xFFFFFFFF` is `EOS` (`src/unibreakdef.h:52`) and also a `utf32_t` a
    // buffer may hold: `ub_get_next_char_utf32` returns the stored unit
    // verbatim (`src/unibreakdef.c:172`). Upstream tells the two apart by the
    // index alone — it answers `EOS` without advancing and returns a stored
    // unit by advancing one (`:167-172`) — so the cursor does too.
    const units = [_]u32{ 0x0061, 0xFFFFFFFF, 0x0062 };

    const sentinel = try libunibreak.Decode.utf32(&units, 1);
    try std.testing.expect(!sentinel.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0xFFFFFFFF), sentinel.code_point);
    try std.testing.expectEqual(@as(usize, 2), sentinel.index);

    // The unit behind it is still reachable, which is what a walk that stops on
    // `end` depends on.
    const after = try libunibreak.Decode.utf32(&units, sentinel.index);
    try std.testing.expect(!after.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0x0062), after.code_point);
    try std.testing.expectEqual(@as(usize, 3), after.index);

    // The real end of the range is the only thing that ends the cursor, and it
    // leaves the index it was given, unchanged.
    const past = try libunibreak.Decode.utf32(&units, units.len);
    try std.testing.expect(past.end);
    try std.testing.expectEqual(@as(usize, 3), past.index);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0), past.code_point);

    // An empty buffer has nothing to return, so it ends at once.
    const empty = try libunibreak.Decode.utf32(&[_]u32{}, 0);
    try std.testing.expect(empty.end);
    try std.testing.expectEqual(@as(usize, 0), empty.index);

    // The whole buffer, walked the way a caller walks one. The index strictly
    // increases and the walk stops at the true end.
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

    // A surrogate is the other value the same rule covers: it is above
    // `U+10FFFF` and comes back as itself rather than as an end.
    const surrogate = try libunibreak.Decode.utf32(&[_]u32{ 0x0061, 0xD800, 0x0062 }, 1);
    try std.testing.expect(!surrogate.end);
    try std.testing.expectEqual(@as(libunibreak.CodePoint, 0xD800), surrogate.code_point);
    try std.testing.expectEqual(@as(usize, 2), surrogate.index);

    // The break passes keep the other half of the convention: they refuse the
    // same values rather than decoding them, which is the one place the two
    // halves of this file deliberately disagree.
    var out: [3]libunibreak.LineOpcode = undefined;
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.perCodeUnit32(&units, null, &out));
    try std.testing.expectError(error.MalformedUtf32, libunibreak.Line.breakBetween(0x0061, 0xFFFFFFFF, null));
}
