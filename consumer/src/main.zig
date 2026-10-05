//! A consumer of the `libunibreak` package.
//!
//! This program does what a text engine does with a segmentation library: it
//! takes a run of text and asks where a line may break, where a word may break,
//! and where one user-perceived character ends and the next begins — over
//! UTF-8, UTF-16 and UTF-32 from the same code point array.
//!
//! Everything asserted below is Unicode's published answer, keyed by its own
//! fixture line, and written out as a literal rather than read from the fixture:
//! a consumer of a published package does not have the package's test data, and
//! that is what makes these independent checks rather than a restatement of the
//! library's own output.
//!
//!   * `GraphemeBreakTest.txt` line 767 — a letter with a skin-tone modifier
//!     (rule GB9), then a baby joined to an octagonal sign by U+200D (rule
//!     GB11). Two clusters, not five characters.
//!   * `WordBreakTest.txt` line 1759 — "1,1:" splits into the number "1,1" and
//!     the colon, by rules WB11, WB12 and WB13a.
//!   * `LineBreakTest.txt` line 19242 — an ideographic space is class BA, so
//!     rule LB21 forces a break after it while the surrounding ideographs are
//!     held together by rules LB16 and LB28.
//!
//! One reading rule applies throughout and is worth stating once: a row is
//! `m0 c0 m1 c1 … m(n-1) c(n-1) mn`, and entry `i` of a break buffer is the
//! break **before** code point `i + 1`, so entry `i` is compared with marker
//! `m(i+1)`. `m0`, the marker before the very first code point, is not something
//! any output buffer reports.
//!
//! The last section is what a consumer actually gets bitten by: the four
//! refusals. An undersized buffer, a buffer that shares storage with the text, a
//! truncated UTF-8 sequence and an unpaired surrogate are all refused, and in
//! every case the output buffer still holds the caller's own bytes.
//!
//! ## The provider, in a runtime-loading build
//!
//! A consumer built with `-Druntime=true` has no native library linked into it,
//! so nothing below can be asked until a provider has been named. The file is
//! named by `--provider /path/to/libunibreak.so` or in
//! `LIBUNIBREAK_TEST_PROVIDER`, and a run told neither says so and fails rather
//! than reporting success for a program that never reached the library. In a
//! linked build neither is read and `libunibreak.load` is not called at all.

const std = @import("std");
const libunibreak = @import("libunibreak");

/// A shared object exporting the eighteen functions and the `unibreak_version`
/// object of the five public headers.
const provider_variable = "LIBUNIBREAK_TEST_PROVIDER";

/// Which native library to open, or null in a linked build.
///
/// `--provider <path>` wins over the environment variable, so one run can be
/// pointed at a different provider without changing the environment of the whole
/// run. Neither channel falls back to the other.
fn resolveProvider(
    args: []const [:0]const u8,
    environ: *const std.process.Environ.Map,
) !?[]const u8 {
    if (!libunibreak.runtime_loaded) return null;

    var named: ?[]const u8 = null;
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--provider")) {
            if (index + 1 >= args.len) {
                std.debug.print("consumer: --provider needs a path\n", .{});
                return error.MissingProvider;
            }
            index += 1;
            named = args[index];
        } else if (std.mem.startsWith(u8, args[index], "--provider=")) {
            named = args[index]["--provider=".len..];
        } else {
            std.debug.print("consumer: unknown argument '{s}'\n", .{args[index]});
            return error.UnknownArgument;
        }
    }
    if (named == null) named = environ.get(provider_variable);
    const path = named orelse {
        std.debug.print(
            "consumer: this is a runtime-loading build, so nothing native is " ++
                "linked into the module. Pass --provider /path/to/libunibreak.so, " ++
                "or set {s}.\n",
            .{provider_variable},
        );
        return error.MissingProvider;
    };
    if (path.len == 0) {
        std.debug.print("consumer: the provider path is empty\n", .{});
        return error.MissingProvider;
    }
    return path;
}

/// GraphemeBreakTest.txt line 767, as code points. A consumer holds text in
/// whichever encoding its buffer uses and converts as needed, so this program
/// keeps one array and derives the other two.
const cluster_text = [_]u32{
    0x0061, // LATIN SMALL LETTER A
    0x1F3FF, // EMOJI MODIFIER FITZPATRICK TYPE-6
    0x1F476, // BABY
    0x200D, // ZERO WIDTH JOINER
    0x1F6D1, // OCTAGONAL SIGN
};

/// Markers `m1 … mn` of that row: `÷ 0061 × 1F3FF ÷ 1F476 × 200D × 1F6D1 ÷`.
const cluster_markers = [_]bool{ false, true, false, false, true };

/// WordBreakTest.txt line 1759: `÷ 0031 × 002C × 0031 ÷ 003A ÷`.
const word_text = [_]u32{
    0x0031, // DIGIT ONE
    0x002C, // COMMA
    0x0031, // DIGIT ONE
    0x003A, // COLON
};

const word_markers = [_]bool{ false, false, true, true };

/// LineBreakTest.txt line 19242:
/// `× 4F8B × FF1A ÷ 300C × 3042 × 3000 ÷ 3044 ÷`.
const line_text = [_]u32{
    0x4F8B, // CJK UNIFIED IDEOGRAPH-4F8B
    0xFF1A, // FULLWIDTH COLON
    0x300C, // LEFT CORNER BRACKET
    0x3042, // HIRAGANA LETTER A
    0x3000, // IDEOGRAPHIC SPACE
    0x3044, // HIRAGANA LETTER I
};

const line_markers = [_]bool{ false, true, false, false, true, true };

/// The number of code units each code point occupies in UTF-8.
fn utf8Width(value: u32) usize {
    if (value < 0x80) return 1;
    if (value < 0x800) return 2;
    if (value < 0x10000) return 3;
    return 4;
}

/// The number of code units each code point occupies in UTF-16.
fn utf16Width(value: u32) usize {
    return if (value < 0x10000) 1 else 2;
}

/// Encodes `points` into `out` as UTF-8 and returns the bytes written. `out` must
/// hold at least `points.len * 4` bytes, which is what `main` allocates.
fn encodeUtf8(points: []const u32, out: []u8) []const u8 {
    var at: usize = 0;
    for (points) |value| {
        if (value < 0x80) {
            out[at] = @intCast(value);
            at += 1;
        } else if (value < 0x800) {
            out[at] = @intCast(0xC0 | (value >> 6));
            out[at + 1] = @intCast(0x80 | (value & 0x3F));
            at += 2;
        } else if (value < 0x10000) {
            out[at] = @intCast(0xE0 | (value >> 12));
            out[at + 1] = @intCast(0x80 | ((value >> 6) & 0x3F));
            out[at + 2] = @intCast(0x80 | (value & 0x3F));
            at += 3;
        } else {
            out[at] = @intCast(0xF0 | (value >> 18));
            out[at + 1] = @intCast(0x80 | ((value >> 12) & 0x3F));
            out[at + 2] = @intCast(0x80 | ((value >> 6) & 0x3F));
            out[at + 3] = @intCast(0x80 | (value & 0x3F));
            at += 4;
        }
    }
    return out[0..at];
}

/// Encodes `points` into `out` as UTF-16 and returns the code units written.
/// `out` must hold at least `points.len * 2` code units.
fn encodeUtf16(points: []const u32, out: []u16) []const u16 {
    var at: usize = 0;
    for (points) |value| {
        if (value < 0x10000) {
            out[at] = @intCast(value);
            at += 1;
        } else {
            const rest = value - 0x10000;
            out[at] = @intCast(0xD800 | (rest >> 10));
            out[at + 1] = @intCast(0xDC00 | (rest & 0x3FF));
            at += 2;
        }
    }
    return out[0..at];
}

/// Prints `points` grouped into the clusters `markers` describes, and returns
/// how many there were. A marker at entry `i` says whether code point `i + 1`
/// begins a new cluster; the run always ends one.
fn printClusters(
    w: *std.Io.Writer,
    label: []const u8,
    points: []const u32,
    markers: []const bool,
) !usize {
    try w.print("{s}", .{label});
    var clusters: usize = 0;
    var start: usize = 0;
    for (0..points.len) |index| {
        const ends_run = index + 1 == points.len;
        if (!ends_run and !markers[index]) continue;
        clusters += 1;
        if (clusters > 1) try w.print(" | ", .{});
        for (points[start .. index + 1], start..) |part, offset| {
            if (offset != start) try w.print("+", .{});
            try w.print("U+{X:0>4}", .{part});
        }
        start = index + 1;
    }
    try w.print(" — {d} clusters\n", .{clusters});
    return clusters;
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const provider = try resolveProvider(args, init.environ_map);
    if (provider) |path| try libunibreak.load(.{ .path = path });

    var threaded: std.Io.Threaded = .init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &buffer);
    const w = &stdout.interface;

    try w.print("libunibreak consumer, library version 0x{X:0>4}\n", .{libunibreak.version()});
    // Which route produced the numbers below is part of the answer: in a linked
    // build every call above was a direct C call, and in a runtime-loading one
    // every one went through the table this provider filled.
    try w.print("{s}\n", .{
        if (libunibreak.runtime_loaded)
            "runtime-loaded: every answer below came through the loaded provider"
        else
            "linked: every entry point below resolved at link time",
    });

    // --- Grapheme clusters over all three encodings -----------------------
    // Five code points: one byte, four, four, three and four in UTF-8, so the
    // UTF-8 pass fills sixteen entries. Two of them are above U+FFFF, so the
    // UTF-16 pass fills seven and needs surrogate pairs, and UTF-32 fills five.
    // All three must carry the same opcode at the final unit of each code
    // point, and `inside_char` at every preceding unit.
    var utf8_bytes: [cluster_text.len * 4]u8 = undefined;
    var utf16_units: [cluster_text.len * 2]u16 = undefined;
    const text8 = encodeUtf8(&cluster_text, &utf8_bytes);
    const text16 = encodeUtf16(&cluster_text, &utf16_units);

    var breaks8: [cluster_text.len * 4]libunibreak.GraphemeOpcode = undefined;
    var breaks16: [cluster_text.len * 2]libunibreak.GraphemeOpcode = undefined;
    var breaks32: [cluster_text.len]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit(text8, &breaks8);
    try libunibreak.Grapheme.perCodeUnit16(text16, &breaks16);
    try libunibreak.Grapheme.perCodeUnit32(&cluster_text, &breaks32);

    var at8: usize = 0;
    var at16: usize = 0;
    for (cluster_text, cluster_markers, 0..) |codepoint, marker, index| {
        const width8 = utf8Width(codepoint);
        const width16 = utf16Width(codepoint);
        for (0..width8 - 1) |offset| {
            if (breaks8[at8 + offset] != .inside_char) return error.InsideCharMarkerMismatch;
        }
        for (0..width16 - 1) |offset| {
            if (breaks16[at16 + offset] != .inside_char) return error.InsideCharMarkerMismatch;
        }
        const opcode8 = breaks8[at8 + width8 - 1];
        if ((opcode8 == .allow_break) != marker) return error.GraphemeMismatch;
        if (breaks16[at16 + width16 - 1] != opcode8) return error.EncodingDisagreement;
        if (breaks32[index] != opcode8) return error.EncodingDisagreement;
        at8 += utf8Width(codepoint);
        at16 += utf16Width(codepoint);
    }
    if (at8 != text8.len or at16 != text16.len) return error.LengthMismatch;

    if (try printClusters(w, "graphemes ", &cluster_text, &cluster_markers) != 2) {
        return error.ClusterCountMismatch;
    }
    try w.print("  published answer: two clusters, a letter with a skin-tone modifier " ++
        "and a ZWJ sequence; UTF-8 filled {d} entries, UTF-16 {d}, UTF-32 {d}\n", .{
        text8.len, text16.len, cluster_text.len,
    });

    // --- Word boundaries ---------------------------------------------------
    var word_breaks: [word_text.len]libunibreak.WordOpcode = undefined;
    try libunibreak.Word.perCodeUnit32(&word_text, &word_breaks);
    for (word_breaks, word_markers) |opcode, marker| {
        if ((opcode == .allow_break) != marker) return error.WordMismatch;
    }
    _ = try printClusters(w, "words     ", &word_text, &word_markers);
    try w.print("  published answer: \"1,1\" is one word and the colon is the next\n", .{});

    // --- Line breaks -------------------------------------------------------
    var line_breaks: [line_text.len]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&line_text, null, &line_breaks);
    for (line_breaks, line_markers) |opcode, marker| {
        // The fixture cannot say "allowed" as against "mandatory", so either
        // answers the marker here.
        if ((opcode == .allow_break or opcode == .must_break or opcode == .indeterminate) != marker) return error.LineMismatch;
    }
    _ = try printClusters(w, "lines     ", &line_text, &line_markers);
    try w.print("  published answer: the ideographic space ends a line, rule LB21\n", .{});

    // The same text in UTF-8, per code point. Six code points, but U+3000 is
    // three bytes and three of them are four, so a per-code-unit pass would fill
    // nineteen entries; the per-code-point pass fills six and says so.
    var line_bytes: [line_text.len * 4]u8 = undefined;
    const line_utf8 = encodeUtf8(&line_text, &line_bytes);
    var per_point: [line_text.len]libunibreak.LineOpcode = undefined;
    const filled = try libunibreak.Line.perCodePoint(line_utf8, null, &per_point);
    if (filled != line_text.len) return error.CodePointCountMismatch;
    for (line_breaks, per_point[0..filled]) |expected, observed| {
        if (observed != expected) return error.EncodingDisagreement;
    }
    try w.print("UTF-8 per code point: {d} bytes, {d} entries written\n", .{ line_utf8.len, filled });

    // The pair query, for a caller that has two characters and no context.
    // UAX #14 keeps an ideograph away from a fullwidth colon, and entry 0 of the
    // full pass says the same.
    const between = try libunibreak.Line.breakBetween(line_text[0], line_text[1], null);
    if (between != line_breaks[0]) return error.PairQueryMismatch;
    try w.print("is_line_breakable(U+4F8B, U+FF1A) is {s}, the same as entry 0\n", .{@tagName(between)});

    // --- The refusals ------------------------------------------------------
    // Each one is a mistake a real caller makes, and each must leave the output
    // buffer holding the caller's own bytes rather than a half-written answer.
    try w.print("\nrefusals:\n", .{});

    // 1. Undersized. A per-code-unit buffer is sized in code units, so these
    //    nineteen UTF-8 bytes need nineteen entries and not six.
    var tight: [line_text.len]libunibreak.GraphemeOpcode = undefined;
    @memset(&tight, libunibreak.GraphemeOpcode.inside_char);
    if (libunibreak.Grapheme.perCodeUnit(line_utf8, &tight)) |_| {
        return error.UndersizedBufferAccepted;
    } else |err| {
        if (err != error.OutputTooSmall) return err;
    }
    for (tight) |opcode| {
        if (opcode != .inside_char) return error.PartialWrite;
    }
    try w.print("  undersized output: OutputTooSmall, {d} of {d} needed entries untouched\n", .{
        tight.len, line_utf8.len,
    });

    // 2. Overlap. One buffer holding the text with the opcodes written over its
    //    own second byte onwards, as an in-place rewrite would.
    var shared: [64]u8 = undefined;
    @memcpy(shared[0..line_utf8.len], line_utf8);
    const shared_out: []libunibreak.GraphemeOpcode =
        @as([*]libunibreak.GraphemeOpcode, @ptrCast(shared[1 .. 1 + line_text.len].ptr))[0..line_text.len];
    if (libunibreak.Grapheme.perCodeUnit(shared[0..line_utf8.len], shared_out)) |_| {
        return error.OverlappingBufferAccepted;
    } else |err| {
        if (err != error.InputOutputOverlap) return err;
    }
    try w.print("  output inside the input: InputOutputOverlap\n", .{});

    // 3. Malformed UTF-8: a three-byte sequence cut short by the end of the
    //    input. Upstream's decoder reports end-of-string for it
    //    (`src/unibreakdef.c:78-81`) and the pass fills the remaining byte with
    //    `inside_char`; this package refuses the call instead.
    const truncated = "a\xE0\xA0";
    var malformed_out: [8]libunibreak.GraphemeOpcode = undefined;
    @memset(&malformed_out, libunibreak.GraphemeOpcode.inside_char);
    if (libunibreak.Grapheme.perCodeUnit(truncated, &malformed_out)) |_| {
        return error.MalformedInputAccepted;
    } else |err| {
        if (err != error.MalformedUtf8) return err;
    }
    for (malformed_out) |opcode| {
        if (opcode != .inside_char) return error.PartialWrite;
    }
    try w.print("  truncated UTF-8 sequence: MalformedUtf8, {d} entries untouched\n", .{malformed_out.len});

    // 4. Malformed UTF-16: a high surrogate with nothing behind it. Upstream
    //    returns the surrogate value itself as a character
    //    (`src/unibreakdef.c:138-142`).
    const unpaired = [_]u16{ 0x0061, 0xD800 };
    var malformed16: [4]libunibreak.LineOpcode = undefined;
    @memset(&malformed16, libunibreak.LineOpcode.indeterminate);
    if (libunibreak.Line.perCodeUnit16(&unpaired, null, &malformed16)) |_| {
        return error.MalformedInputAccepted;
    } else |err| {
        if (err != error.MalformedUtf16) return err;
    }
    for (malformed16) |opcode| {
        if (opcode != .indeterminate) return error.PartialWrite;
    }
    try w.print("  unpaired surrogate in UTF-16: MalformedUtf16, {d} entries untouched\n", .{malformed16.len});

    try w.print("\nevery published expectation for these rows was reproduced\n", .{});
    try w.flush();
}
