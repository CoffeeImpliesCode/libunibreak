# Zig facade reference

The typed API borrows input slices and writes to caller-owned opcode buffers. It does not allocate. Buffer methods validate UTF encoding, overlap and capacity before calling C; a refusal leaves output unchanged. `Line.breakBetween` checks its code points.

## Types

| Type | Meaning |
|---|---|
| `CodePoint` | `u32`; break methods require a Unicode scalar. `Decode` preserves native values. |
| `Language` | `[:0]const u8`, borrowed for line-breaking tailoring; `null` and `""` mean none. Prefix matching and the `-strict` suffix follow upstream. |
| `LineOpcode` | `must_break`, `allow_break`, `no_break`, `inside_char`, `indeterminate`. |
| `WordOpcode`, `GraphemeOpcode` | `allow_break`, `no_break`, `inside_char`; distinct enum types. |
| `Error` | `OutputTooSmall`, `InputOutputOverlap`, `MalformedUtf8`, `MalformedUtf16`, `MalformedUtf32`, `IndexPastEnd` (decode only). |
| `Decode.Step` | `{ code_point: CodePoint, index: usize, end: bool }`; code point is zero at end and index is the cursor after consumed units. |

Each buffer method writes one opcode per input code unit, or one per code point for `Line.perCodePoint*`. Earlier units of a multi-unit code point are `inside_char`; its final unit carries the following break. UTF-32 has one unit per code point. A successful call writes only its output prefix; errors do not change the output.

## Break methods

| Family | Methods | Output / result |
|---|---|---|
| `Line` | `perCodeUnit(text: []const u8, lang: ?Language, out: []LineOpcode) Error!void`; `perCodeUnit16(units: []const u16, lang: ?Language, out: []LineOpcode) Error!void`; `perCodeUnit32(units: []const u32, lang: ?Language, out: []LineOpcode) Error!void` | One opcode per code unit. |
| `Line` | `perCodePoint(text: []const u8, lang: ?Language, out: []LineOpcode) Error!usize`; `perCodePoint16(units: []const u16, lang: ?Language, out: []LineOpcode) Error!usize` | One opcode per code point; returns the number written. No UTF-32 variant is needed. |
| `Line` | `breakBetween(first: CodePoint, second: CodePoint, lang: ?Language) Error!LineOpcode` | Query an isolated pair; rejects non-scalar values with `MalformedUtf32`. |
| `Word` | `perCodeUnit(text: []const u8, out: []WordOpcode) Error!void`; `perCodeUnit16(units: []const u16, out: []WordOpcode) Error!void`; `perCodeUnit32(units: []const u32, out: []WordOpcode) Error!void` | One opcode per code unit; no language parameter. |
| `Grapheme` | `perCodeUnit(text: []const u8, out: []GraphemeOpcode) Error!void`; `perCodeUnit16(units: []const u16, out: []GraphemeOpcode) Error!void`; `perCodeUnit32(units: []const u32, out: []GraphemeOpcode) Error!void` | One opcode per code unit; no language parameter. Empty input leaves output unchanged. |

`OutputTooSmall` means `out` has fewer entries than the input's code-unit count, or the code-point count for `perCodePoint*`. `InputOutputOverlap` compares byte ranges; adjacent ranges are allowed. `MalformedUtf8`, `MalformedUtf16` and `MalformedUtf32` reject invalid text or non-scalar code points. Buffer-method errors are returned before C runs or output changes. `IndexPastEnd` applies only to `Decode` and rejects indices greater than the input length.

## Decoding

`Decode.utf8(text: []const u8, index: usize) Error!Step`, `Decode.utf16(units: []const u16, index: usize) Error!Step` and `Decode.utf32(units: []const u32, index: usize) Error!Step` expose upstream's code-point decoders. They preserve native handling of malformed input rather than validating the whole slice; `end` marks an exhausted or truncated sequence, with the index unchanged when nothing is consumed. In UTF-32, `end` is determined by the index because `0xFFFFFFFF` can also be a stored value.

## Runtime loading

`c` exposes the translated upstream headers. `runtime_loaded` is a comptime `bool` indicating whether this module uses runtime dispatch.

`LoadSource` is a tagged union: `.path` takes an absolute file path; `.system` takes a library basename or SONAME, not a path. Neither falls back to the other. In a runtime-loaded build, call `load(source: LoadSource) LoadError!void` before any native call. A successful provider and request remain for the process lifetime; repeating the same request succeeds, while a different request returns `ProviderMismatch`. Failed attempts publish nothing and may be retried explicitly. Concurrent calls for the same in-flight request share its result; reentrant loading returns `ReentrantLoad`. There is no unload or reset. A pre-load native call panics; in a linked build, `load` also panics because there is no provider to load.

`LoadError` contains `EmptySource`, `SourceTooLong`, `InvalidSource`, `UnsupportedTarget`, `OpenFailed`, `MissingSymbol`, `ValidationFailed`, `ProviderMismatch` and `ReentrantLoad`. The first three reject empty, overlong or malformed requests; the next four report loader, symbol or provider-validation failure.

| Function | Result |
|---|---|
| `loadedSource() ?LoadSource` | Successful request, or `null` when no provider is loaded; always `null` in a linked build. |
| `version() c_int` | The provider's `unibreak_version` value. |
| `versionPointer() ?*const c_int` | Address of the provider's data symbol when runtime-loaded; `null` when linked. |
