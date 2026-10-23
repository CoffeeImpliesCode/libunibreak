//! Unicode line, word, and grapheme breaking with validated caller-owned buffers.
//! Native behavior and raw C declarations remain available through `c`.
const std = @import("std");

/// The upstream C declarations and constants, re-exported without a Zig wrapper.
pub const c = @import("c");

const rt = @import("rt");

/// Whether native calls use the runtime loader instead of the linked library.
/// This comptime constant selects configuration-specific code.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Explicit file path or library name for the platform loader; neither falls back to the other.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Errors returned by [load].
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Loads a provider and retains its handle and request for the process lifetime.
/// Same requests are idempotent; different providers return `ProviderMismatch`; linked builds panic.
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

/// Returns the retained request, or `null` for linked or unloaded builds.
pub fn loadedSource() ?LoadSource {
    if (comptime !runtime_loaded) return null;
    return c.loadedSource();
}

/// Returns the provider-owned `unibreak_version` address, or `null` in linked builds.
pub fn versionPointer() ?*const c_int {
    if (comptime !runtime_loaded) return null;
    return c.unibreak_versionAddr();
}

/// Unicode scalar value represented as `u32`.
pub const CodePoint = u32;

/// Reads `unibreak_version` from the linked library or loaded provider.
pub fn version() c_int {
    if (comptime runtime_loaded) return c.unibreak_versionAddr().*;
    return c.unibreak_version;
}

/// Native line-break opcode with all five upstream values preserved.
pub const LineOpcode = enum(u8) {
    /// Mandatory break.
    must_break = c.LINEBREAK_MUSTBREAK,
    /// Permitted break.
    allow_break = c.LINEBREAK_ALLOWBREAK,
    /// Prohibited break.
    no_break = c.LINEBREAK_NOBREAK,
    /// Code unit continues a code point; its final unit carries the opcode.
    inside_char = c.LINEBREAK_INSIDEACHAR,
    /// Indeterminate final position, distinct from a mandatory break.
    indeterminate = c.LINEBREAK_INDETERMINATE,
};

/// Native word-break opcode, distinct from [LineOpcode].
pub const WordOpcode = enum(u8) {
    /// Word boundary.
    allow_break = c.WORDBREAK_BREAK,
    /// Position inside a word.
    no_break = c.WORDBREAK_NOBREAK,
    /// Code unit continues a code point started earlier.
    inside_char = c.WORDBREAK_INSIDEACHAR,
};

/// Native extended-grapheme-break opcode.
pub const GraphemeOpcode = enum(u8) {
    /// Between extended grapheme clusters.
    allow_break = c.GRAPHEMEBREAK_BREAK,
    /// Inside an extended grapheme cluster.
    no_break = c.GRAPHEMEBREAK_NOBREAK,
    /// Code unit continues a code point started earlier.
    inside_char = c.GRAPHEMEBREAK_INSIDEACHAR,
};

/// Borrowed, NUL-terminated line-break language tag; `null` disables tailoring.
/// Upstream matches two-byte prefixes and a trailing `-strict` suffix.
pub const Language = [:0]const u8;

/// Wrapper errors are returned before the native call or any output write.
pub const Error = error{
    /// Output buffer cannot hold the method's results.
    OutputTooSmall,
    /// Input and output byte ranges overlap.
    InputOutputOverlap,
    /// Input is not well-formed UTF-8.
    MalformedUtf8,
    /// Input contains an unpaired UTF-16 surrogate.
    MalformedUtf16,
    /// Input contains a surrogate or value above `U+10FFFF`.
    MalformedUtf32,
    /// Decoder index exceeds input length.
    IndexPastEnd,
};

/// Typed cursors over upstream's UTF-8, UTF-16, and UTF-32 decoders.
/// Malformed input keeps the native result; indices beyond the input return `IndexPastEnd`.
pub const Decode = struct {
    /// One decoder result: code point, next code-unit index, and end-of-input flag.
    pub const Step = struct {
        /// Decoded code point, or zero when `end` is true.
        code_point: CodePoint,
        /// Index after the decoded value, or the unchanged index at end-of-input.
        index: usize,
        /// True when no value remains; UTF-32 uses the index to distinguish stored `0xFFFFFFFF`.
        end: bool,
    };

    fn requireIndex(index: usize, len: usize) Error!void {
        if (index > len) return error.IndexPastEnd;
    }

    /// Decodes one UTF-8 code point at `index`; malformed bytes keep the native result.
    pub fn utf8(text: []const u8, index: usize) Error!Step {
        try requireIndex(index, text.len);
        var at = index;
        const value = c.ub_get_next_char_utf8(text.ptr, text.len, &at);
        return step(@as(CodePoint, value), at);
    }

    /// Decodes one UTF-16 code point at `index` and returns the next code-unit index.
    pub fn utf16(units: []const u16, index: usize) Error!Step {
        try requireIndex(index, units.len);
        var at = index;
        const value = c.ub_get_next_char_utf16(units.ptr, units.len, &at);
        return step(@as(CodePoint, value), at);
    }

    /// Decodes one UTF-32 unit at `index`; scalar validation is not performed.
    /// `end` is position-based because `0xFFFFFFFF` is both `EOS` and a valid unit.
    pub fn utf32(units: []const u32, index: usize) Error!Step {
        try requireIndex(index, units.len);
        var at = index;
        const value = c.ub_get_next_char_utf32(units.ptr, units.len, &at);
        return verbatim(@as(CodePoint, value), at, index == units.len);
    }

    /// Uses the returned `EOS` value for UTF-8 and UTF-16.
    fn step(value: CodePoint, at: usize) Step {
        return verbatim(value, at, value == c.EOS);
    }

    /// Uses the index for end detection when the value can also be data.
    fn verbatim(value: CodePoint, at: usize, end: bool) Step {
        return .{
            .code_point = if (end) 0 else value,
            .index = at,
            .end = end,
        };
    }
};

fn isContinuation(byte: u8) bool {
    return byte >= 0x80 and byte <= 0xBF;
}

/// Validates UTF-8 and counts code points.
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

/// Validates UTF-16 and counts code points.
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

/// Validates UTF-32 scalar values and returns the count.
fn countUtf32(units: []const u32) Error!usize {
    for (units) |value| {
        if (value > 0x10FFFF or (value >= 0xD800 and value <= 0xDFFF)) {
            return error.MalformedUtf32;
        }
    }
    return units.len;
}

/// Rejects overlapping input/output byte ranges; empty or touching ranges are allowed.
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

/// Line breaking over UTF-8, UTF-16, or UTF-32, with optional language tailoring.
pub const Line = struct {
    fn languagePointer(lang: ?Language) [*c]const u8 {
        return if (lang) |tag| tag.ptr else null;
    }

    /// Writes one opcode per UTF-8 code unit to `out[0..text.len]`; empty input writes nothing.
    /// Malformed input, overlap, or insufficient capacity returns an error before writing.
    pub fn perCodeUnit(text: []const u8, lang: ?Language, out: []LineOpcode) Error!void {
        try rejectOverlap(text, text.len, out, out.len);
        try requireCapacity(text.len, out.len);
        _ = try countUtf8(text);
        c.set_linebreaks_utf8(text.ptr, text.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// Writes one opcode per UTF-16 code unit to `out[0..units.len]`.
    /// Malformed input, overlap, or insufficient capacity returns an error before writing.
    pub fn perCodeUnit16(units: []const u16, lang: ?Language, out: []LineOpcode) Error!void {
        try rejectOverlap(units, units.len * 2, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf16(units);
        c.set_linebreaks_utf16(units.ptr, units.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// Writes one opcode per UTF-32 code unit; `inside_char` never appears.
    /// Non-scalar input, overlap, or insufficient capacity returns an error before writing.
    pub fn perCodeUnit32(units: []const u32, lang: ?Language, out: []LineOpcode) Error!void {
        try rejectOverlap(units, units.len * 4, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf32(units);
        c.set_linebreaks_utf32(units.ptr, units.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// Writes one opcode per UTF-8 code point and returns the number written.
    /// Validates input and capacity before writing; only the written prefix changes.
    pub fn perCodePoint(text: []const u8, lang: ?Language, out: []LineOpcode) Error!usize {
        try rejectOverlap(text, text.len, out, out.len);
        const count = try countUtf8(text);
        try requireCapacity(count, out.len);
        return c.set_linebreaks_utf8_per_code_point(text.ptr, text.len, languagePointer(lang), @ptrCast(out.ptr));
    }

    /// Writes one opcode per UTF-16 code point and returns the number written.
    /// Validates input and capacity before writing; only the written prefix changes.
    pub fn perCodePoint16(units: []const u16, lang: ?Language, out: []LineOpcode) Error!usize {
        try rejectOverlap(units, units.len * 2, out, out.len);
        const count = try countUtf16(units);
        try requireCapacity(count, out.len);
        return c.set_linebreaks_utf16_per_code_point(units.ptr, units.len, languagePointer(lang), @ptrCast(out.ptr));
    }
    /// Returns the native break opcode between two scalar values.
    /// Invalid values return `MalformedUtf32`; use a full-text pass for context-sensitive rules.
    pub fn breakBetween(first: CodePoint, second: CodePoint, lang: ?Language) Error!LineOpcode {
        _ = try countUtf32(&.{ first, second });
        const raw = c.is_line_breakable(first, second, languagePointer(lang));
        return @fromBackingInt(@intCast(@as(u8, @truncate(@as(u32, @bitCast(raw))))));
    }
};

/// Word breaking over UTF-8, UTF-16, or UTF-32; upstream provides no language tailoring.
pub const Word = struct {
    /// Writes one opcode per UTF-8 code unit; errors on malformed input, overlap, or insufficient capacity.
    pub fn perCodeUnit(text: []const u8, out: []WordOpcode) Error!void {
        try rejectOverlap(text, text.len, out, out.len);
        try requireCapacity(text.len, out.len);
        _ = try countUtf8(text);
        c.set_wordbreaks_utf8(text.ptr, text.len, null, @ptrCast(out.ptr));
    }

    /// Writes one opcode per UTF-16 code unit; errors on malformed input, overlap, or insufficient capacity.
    pub fn perCodeUnit16(units: []const u16, out: []WordOpcode) Error!void {
        try rejectOverlap(units, units.len * 2, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf16(units);
        c.set_wordbreaks_utf16(units.ptr, units.len, null, @ptrCast(out.ptr));
    }

    /// Writes one opcode per UTF-32 code unit; errors on non-scalar input, overlap, or insufficient capacity.
    pub fn perCodeUnit32(units: []const u32, out: []WordOpcode) Error!void {
        try rejectOverlap(units, units.len * 4, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf32(units);
        c.set_wordbreaks_utf32(units.ptr, units.len, null, @ptrCast(out.ptr));
    }
};

/// Extended grapheme-cluster breaking over UTF-8, UTF-16, or UTF-32.
pub const Grapheme = struct {
    /// Writes one opcode per UTF-8 code unit; empty input is a no-op.
    /// Malformed input, overlap, or insufficient capacity returns an error before writing.
    pub fn perCodeUnit(text: []const u8, out: []GraphemeOpcode) Error!void {
        try rejectOverlap(text, text.len, out, out.len);
        try requireCapacity(text.len, out.len);
        _ = try countUtf8(text);
        if (text.len == 0) return;
        c.set_graphemebreaks_utf8(text.ptr, text.len, null, @ptrCast(out.ptr));
    }

    /// Writes one opcode per UTF-16 code unit; empty input is a no-op.
    /// Malformed input, overlap, or insufficient capacity returns an error before writing.
    pub fn perCodeUnit16(units: []const u16, out: []GraphemeOpcode) Error!void {
        try rejectOverlap(units, units.len * 2, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf16(units);
        if (units.len == 0) return;
        c.set_graphemebreaks_utf16(units.ptr, units.len, null, @ptrCast(out.ptr));
    }

    /// Writes one opcode per UTF-32 code unit; empty input is a no-op.
    /// Malformed input, overlap, or insufficient capacity returns an error before writing.
    pub fn perCodeUnit32(units: []const u32, out: []GraphemeOpcode) Error!void {
        try rejectOverlap(units, units.len * 4, out, out.len);
        try requireCapacity(units.len, out.len);
        _ = try countUtf32(units);
        if (units.len == 0) return;
        c.set_graphemebreaks_utf32(units.ptr, units.len, null, @ptrCast(out.ptr));
    }
};
