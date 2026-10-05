//! A runnable, deterministic demonstration of the facade.
//!
//! Three published conformance rows, one per algorithm, each asserted against
//! the answer Unicode prints beside it in the fixture:
//!
//!   * `src/GraphemeBreakTest.txt` line 757,
//!     `÷ 0061 ÷ 1F1E6 × 1F1E7 ÷ 1F1E8 ÷ 0062 ÷` — four clusters: a letter, the
//!     regional-indicator pair that rules GB12 and GB13 keep together, the odd
//!     indicator left over from the next pair, and a second letter.
//!   * `src/WordBreakTest.txt` line 1729, `÷ 0031 × 002C × 0030 ÷` — rules WB11
//!     and WB12 make the comma part of the number, so "1,0" is one word.
//!   * `src/LineBreakTest.txt` line 28, `× 2757 × 0020 ÷ 2757 ÷` — LB7 forbids a
//!     break before the space and requires one after it, so the two exclamation
//!     marks sit on different lines.
//!
//! The per-entry comparison below is stated in the same terms the fixtures use.
//! A row is `m0 c0 m1 c1 … m(n-1) c(n-1) mn`, and the entry `i` of a break buffer
//! is the break **before** code point `i + 1` — so entry `i` is compared with
//! marker `m(i+1)`, and `m0`, the marker before the very first code point, is
//! not something any output buffer reports. Upstream's own harness works the
//! same way (`src/tests.c:246-260`).
//!
//! The line example is also run twice, once with the `-strict` tailoring that
//! `LineBreakTest.txt` line 279 is stated for and once without, which is the one
//! place the typed language option changes an answer.
//!
//! Every expectation is written out as a literal keyed by its own fixture line
//! rather than read from the fixture: a smoke run should not depend on the
//! package's test data, which is what makes these assertions independent of
//! `tests.zig`.
//!
//! Nothing below this program's first two printed lines depends on timing, on
//! a locale or on an environment variable: those lines are this package's own
//! assertions against literals keyed by fixture line, and a change in one is a
//! change in behaviour.
//!
//! The first two lines are not claimed to be configuration-independent. In a
//! linked build the version line reads the linked library and the route line
//! names the linked route, and both are then identical on every host, because
//! nothing is read from the environment at all. Under `-Druntime=true` the
//! version line is whatever the named provider reported, the route line names
//! the runtime-loaded route, and a run told neither fails before printing
//! anything; see the section below. So the output a reader may diff across
//! hosts and across configurations is everything after those two lines.
//!
//! ## The provider, in a runtime-loading build
//!
//! Nothing native is linked into the module under `-Druntime=true`, so this
//! program cannot ask the library anything until it has been told which file to
//! open. The file is named by `--provider /path/to/libunibreak.so`, or in
//! `LIBUNIBREAK_TEST_PROVIDER` when no argument says otherwise, and a run that
//! was told neither reports that and fails: there is nothing else to call, and
//! quietly carrying on would report success for a program that never asked the
//! library a question. In a linked build no provider is needed and none is read.

const std = @import("std");
const libunibreak = @import("libunibreak");

/// A shared object exporting the eighteen functions and the `unibreak_version`
/// object of the five public headers.
const provider_variable = "LIBUNIBREAK_TEST_PROVIDER";

/// Which native library to open, or null in a linked build.
///
/// `--provider <path>` wins over the environment variable, so a caller can point
/// this program at a different provider without changing the environment of the
/// whole run. Neither channel falls back to the other: an explicit path is used
/// or the run fails.
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

/// GraphemeBreakTest.txt line 757, as code points. Kept in UTF-32 so a code
/// point index in the output is also a character index and can be read against
/// the fixture.
const regional = [_]u32{
    0x0061, // LATIN SMALL LETTER A
    0x1F1E6, // REGIONAL INDICATOR SYMBOL LETTER A
    0x1F1E7, // REGIONAL INDICATOR SYMBOL LETTER B
    0x1F1E8, // REGIONAL INDICATOR SYMBOL LETTER C
    0x0062, // LATIN SMALL LETTER B
};

/// WordBreakTest.txt line 1729.
const number = [_]u32{
    0x0031, // DIGIT ONE
    0x002C, // COMMA
    0x0030, // DIGIT ZERO
};

/// LineBreakTest.txt line 28.
const two_marks = [_]u32{
    0x2757, // HEAVY EXCLAMATION MARK SYMBOL
    0x0020, // SPACE
    0x2757, // HEAVY EXCLAMATION MARK SYMBOL
};

/// The two code points of LineBreakTest.txt line 279, whose `×` before U+3041 is
/// stated for `lang = "-strict"`.
const conditional_starter = [_]u32{
    0x2757, // HEAVY EXCLAMATION MARK SYMBOL
    0x3041, // HIRAGANA LETTER SMALL A, line break class CJ
};

/// Markers `m1 … mn` of each cited row, `true` for `÷` and `false` for `×`.
const regional_markers = [_]bool{ true, false, true, true, true };
const number_markers = [_]bool{ false, false, true };
const two_marks_markers = [_]bool{ false, true, true };

/// LineBreakTest.txt line 279 is `× 2757 × 3041 ÷`. Its middle marker `m1` is the
/// `×`: under `-strict` class CJ resolves to NS and rule LB21 prohibits the
/// break, while with no tailoring CJ resolves to ID and the break is permitted.
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
    // Which route produced the answers below is part of the answer: in a linked
    // build every call above was a direct C call, and in a runtime-loading one
    // every one went through the table this provider filled.
    try w.print("{s}\n", .{
        if (libunibreak.runtime_loaded)
            "runtime-loaded: every entry point below went through the loaded provider"
        else
            "linked: every entry point below resolved at link time",
    });

    // --- Grapheme clusters, UTF-32 ---------------------------------------
    var clusters: [regional.len]libunibreak.GraphemeOpcode = undefined;
    try libunibreak.Grapheme.perCodeUnit32(&regional, &clusters);
    try w.print("\nGraphemeBreakTest.txt line 757, {d} code points:\n", .{regional.len});
    for (regional, clusters, regional_markers) |codepoint, opcode, marker| {
        try w.print("  after U+{X:0>4}: {s}\n", .{ codepoint, @tagName(opcode) });
        if ((opcode == .allow_break) != marker) return error.GraphemeClusterMismatch;
    }

    // --- Word boundaries, UTF-32 ------------------------------------------
    var words: [number.len]libunibreak.WordOpcode = undefined;
    try libunibreak.Word.perCodeUnit32(&number, &words);
    try w.print("\nWordBreakTest.txt line 1729, \"1,0\":\n", .{});
    for (number, words, number_markers) |codepoint, opcode, marker| {
        try w.print("  after U+{X:0>4}: {s}\n", .{ codepoint, @tagName(opcode) });
        if ((opcode == .allow_break) != marker) return error.WordBoundaryMismatch;
    }
    try w.print("  one word: the comma is inside it\n", .{});

    // --- Line breaks, UTF-32 ----------------------------------------------
    var lines: [two_marks.len]libunibreak.LineOpcode = undefined;
    try libunibreak.Line.perCodeUnit32(&two_marks, null, &lines);
    try w.print("\nLineBreakTest.txt line 28, two exclamation marks around a space:\n", .{});
    for (two_marks, lines, two_marks_markers) |codepoint, opcode, marker| {
        try w.print("  after U+{X:0>4}: {s}\n", .{ codepoint, @tagName(opcode) });
        // The oracle cannot say "allowed" as against "mandatory", so either
        // answers the marker here. The two are told apart further down.
        if ((opcode == .allow_break or opcode == .must_break or opcode == .indeterminate) != marker) {
            return error.LineBreakMismatch;
        }
    }

    // The pair query answers the same question about two isolated characters.
    // Upstream documents it as inferior to the full pass (`src/linebreak.c:1646-1648`);
    // on two characters the two agree, which is what this shows.
    const between = try libunibreak.Line.breakBetween(0x2757, 0x0020, null);
    if (between != lines[0]) return error.PairQueryMismatch;
    try w.print("  is_line_breakable(U+2757, U+0020) is {s}, the same as entry 0\n", .{@tagName(between)});

    // --- Language tailoring ----------------------------------------------
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

    // --- The per-code-point form, and its buffer bound --------------------
    // Six UTF-8 bytes, two code points, so two entries — not six. The count comes
    // back from the call rather than being assumed, and a buffer one entry short
    // is refused before anything is written.
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

    // --- The code-point cursor -------------------------------------------
    // The same six bytes walked one code point at a time, which is what a caller
    // indexing something alongside the break positions needs: two code points
    // over six code units, and the cursor says where each one ended.
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
    // An index past the end is refused rather than handed to an assert that two
    // of this package's four optimize modes have removed.
    if (libunibreak.Decode.utf8(encoded, encoded.len + 1)) |_| {
        return error.OutOfRangeIndexAccepted;
    } else |err| {
        if (err != error.IndexPastEnd) return err;
        try w.print("  an index past the end is refused as {s}\n", .{@errorName(err)});
    }

    try w.print("\nevery published expectation for these rows was reproduced\n", .{});
    try w.flush();
}
