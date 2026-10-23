//! Smoke checks against published Unicode fixture examples.
const std = @import("std");
const libunibreak = @import("libunibreak");

/// Environment variable naming the runtime provider.
const provider_variable = "LIBUNIBREAK_TEST_PROVIDER";

/// Resolves the runtime provider from `--provider` or the environment.
/// Explicit paths have no fallback; linked builds need no provider.
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
                std.debug.print("smoke: --provider needs a path\n", .{});
                return error.MissingProvider;
            }
            index += 1;
            named = args[index];
        } else if (std.mem.startsWith(u8, args[index], "--provider=")) {
            named = args[index]["--provider=".len..];
        } else {
            std.debug.print("smoke: unknown argument '{s}'\n", .{args[index]});
            return error.UnknownArgument;
        }
    }
    if (named == null) named = environ.get(provider_variable);
    const path = named orelse {
        std.debug.print(
            "smoke: this is a runtime-loading build, so nothing native is linked " ++
                "into the module. Pass --provider /path/to/libunibreak.so, or set " ++
                "{s}. Build one with `zig build -Dlinkage=dynamic --prefix <dir>`.\n",
            .{provider_variable},
        );
        return error.MissingProvider;
    };
    if (path.len == 0) {
        std.debug.print("smoke: the provider path is empty\n", .{});
        return error.MissingProvider;
    }
    return path;
}

/// Grapheme fixture row 757 in UTF-32.
const regional = [_]u32{
    0x0061, // LATIN SMALL LETTER A
    0x1F1E6, // REGIONAL INDICATOR SYMBOL LETTER A
    0x1F1E7, // REGIONAL INDICATOR SYMBOL LETTER B
    0x1F1E8, // REGIONAL INDICATOR SYMBOL LETTER C
    0x0062, // LATIN SMALL LETTER B
};

/// Word fixture row 1729 in UTF-32.
const number = [_]u32{
    0x0031, // DIGIT ONE
    0x002C, // COMMA
    0x0030, // DIGIT ZERO
};

/// Line fixture row 28 in UTF-32.
const two_marks = [_]u32{
    0x2757, // HEAVY EXCLAMATION MARK SYMBOL
    0x0020, // SPACE
    0x2757, // HEAVY EXCLAMATION MARK SYMBOL
};

/// Line fixture row 279, whose result changes under `-strict`.
const conditional_starter = [_]u32{
    0x2757, // HEAVY EXCLAMATION MARK SYMBOL
    0x3041, // HIRAGANA LETTER SMALL A, line break class CJ
};

/// Break markers for each fixture row.
const regional_markers = [_]bool{ true, false, true, true, true };
const number_markers = [_]bool{ false, false, true };
const two_marks_markers = [_]bool{ false, true, true };

/// Fixture line 279 expects no break under `-strict` and a break without tailoring.
const strict_allows_at_starter = false;
const untailored_allows_at_starter = true;

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

    try w.print("libunibreak smoke, library version 0x{X:0>4}\n", .{libunibreak.version()});
    // Report which provider route produced the answers.
    try w.print("{s}\n", .{
        if (libunibreak.runtime_loaded)
            "runtime-loaded: every entry point below went through the loaded provider"
        else
            "linked: every entry point below resolved at link time",
    });

    var clusters: [regional.len]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit32(&regional, &clusters);
    try w.print("\nGraphemeBreakTest.txt line 757, {d} code points:\n", .{regional.len});
    for (regional, clusters, regional_markers) |codepoint, opcode, marker| {
        try w.print("  after U+{X:0>4}: {s}\n", .{ codepoint, @tagName(opcode) });
        if ((opcode == .allow_break) != marker) return error.GraphemeClusterMismatch;
    }

    var words: [number.len]libunibreak.WordOpcode = undefined;
    try libunibreak.Word.perCodeUnit32(&number, &words);
    try w.print("\nWordBreakTest.txt line 1729, \"1,0\":\n", .{});
    for (number, words, number_markers) |codepoint, opcode, marker| {
        try w.print("  after U+{X:0>4}: {s}\n", .{ codepoint, @tagName(opcode) });
        if ((opcode == .allow_break) != marker) return error.WordBoundaryMismatch;
    }
    try w.print("  one word: the comma is inside it\n", .{});

    var lines: [two_marks.len]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&two_marks, null, &lines);
    try w.print("\nLineBreakTest.txt line 28, two exclamation marks around a space:\n", .{});
    for (two_marks, lines, two_marks_markers) |codepoint, opcode, marker| {
        try w.print("  after U+{X:0>4}: {s}\n", .{ codepoint, @tagName(opcode) });
        // The fixture does not distinguish allowed from mandatory breaks.
        if ((opcode == .allow_break or opcode == .must_break or opcode == .indeterminate) != marker) {
            return error.LineBreakMismatch;
        }
    }

    // The pair query must match the first full-pass opcode for this pair.
    const between = try libunibreak.Line.breakBetween(0x2757, 0x0020, null);
    if (between != lines[0]) return error.PairQueryMismatch;
    try w.print("  is_line_breakable(U+2757, U+0020) is {s}, the same as entry 0\n", .{@tagName(between)});

    var strict: [conditional_starter.len]libunibreak.LineOpcode = undefined;
    var untailored: [conditional_starter.len]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&conditional_starter, "-strict", &strict);
    try libunibreak.Line.perCodeUnit32(&conditional_starter, null, &untailored);
    try w.print("\nLineBreakTest.txt line 279, a conditional Japanese starter:\n", .{});
    try w.print("  with \"-strict\": {s}\n", .{@tagName(strict[0])});
    try w.print("  without tailoring: {s}\n", .{@tagName(untailored[0])});
    if ((strict[0] == .allow_break or strict[0] == .must_break) != strict_allows_at_starter) {
        return error.StrictTailoringMismatch;
    }
    if ((untailored[0] == .allow_break or untailored[0] == .must_break) != untailored_allows_at_starter) {
        return error.DefaultTailoringMismatch;
    }

    // Six UTF-8 bytes encode two code points; capacity is checked against two.
    const encoded = "\xE2\x9D\x97\xE3\x81\x81";
    var points: [2]libunibreak.LineOpcode = undefined;
    const count = try libunibreak.Line.perCodePoint(encoded, "-strict", &points);
    if (count != 2) return error.CodePointCountMismatch;
    if (points[0] != strict[0] or points[1] != strict[1]) return error.PerCodePointMismatch;
    try w.print("\nUTF-8 per code point: {d} bytes, {d} entries written\n", .{ encoded.len, count });

    var too_small: [1]libunibreak.LineOpcode = undefined;
    if (libunibreak.Line.perCodePoint(encoded, null, &too_small)) |_| {
        return error.UndersizedBufferAccepted;
    } else |err| {
        if (err != error.OutputTooSmall) return error.UnexpectedRejection;
        try w.print("  a one-entry buffer is refused as {s}, before anything is written\n", .{@errorName(err)});
    }

    // The cursor walks the same two code points and reports each ending index.
    var at: usize = 0;
    try w.print("\nwalking U+2757 U+3041 one code point at a time:\n", .{});
    while (true) {
        const next = try libunibreak.Decode.utf8(encoded, at);
        if (next.end) break;
        try w.print("  U+{X:0>4} at byte {d}, next byte {d}\n", .{
            next.code_point, at, next.index,
        });
        if (next.index <= at) return error.CursorDidNotAdvance;
        at = next.index;
    }
    if (at != encoded.len) return error.CursorStoppedShort;
    // Reject an out-of-range index before it reaches upstream's assertion.
    if (libunibreak.Decode.utf8(encoded, encoded.len + 1)) |_| {
        return error.OutOfRangeIndexAccepted;
    } else |err| {
        if (err != error.IndexPastEnd) return err;
        try w.print("  an index past the end is refused as {s}\n", .{@errorName(err)});
    }

    try w.print("\nevery published expectation for these rows was reproduced\n", .{});
    try w.flush();
}
