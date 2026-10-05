// SPDX-License-Identifier: MIT
//
//! libunibreak's side of the runtime loader: the names its synchronization
//! binding has, and what it requires of a provider beyond resolving its
//! symbols.
//!
//! Everything else about the runtime route is generic. `runtime/loader.zig` is
//! the state machine and the platform layer; `runtime/generate.zig` builds the
//! dispatch from whatever the translation step actually produced;
//! `runtime/graph.zig` wires them together. This file is what makes them
//! libunibreak's, and it is the file another SDK replaces.
//!
//! ## What a provider must be
//!
//! Nineteen names: eighteen functions and one data object, which is the whole
//! extern surface of the five public headers this package translates.
//!
//! **Data (1).** `unibreak_version`, declared `extern const int`
//! (`src/unibreakbase.h:43`) and defined at `src/unibreakbase.c:40`. It is an
//! object in the loaded image, not a callable entry point, so it is resolved as
//! an address and kept live: the dispatch stores `*const c_int` and hands that
//! address out, and `libunibreak.version()` dereferences it on every call.
//!
//! **Functions (18).** Four in `unibreakdef.h:61-63` — `ub_get_next_char_utf8`,
//! `ub_get_next_char_utf16`, `ub_get_next_char_utf32`, and the end-of-string
//! sentinel `EOS` they return; seven in `linebreak.h:65-76` — `init_linebreak`,
//! `set_linebreaks_utf8`, `set_linebreaks_utf16`, `set_linebreaks_utf32`,
//! `set_linebreaks_utf8_per_code_point`, `set_linebreaks_utf16_per_code_point`,
//! `is_line_breakable`; four in `wordbreak.h:64-71`; and four in
//! `graphemebreak.h:61-67`. Every one of them is defined in one of the nine
//! core translation units (`src/Makefile.am:11-20`), and none is conditional at
//! this pin, so a provider that exports fewer than all of them is refused before
//! anything is published rather than half used.
//!
//! One declaration in those headers is deliberately *not* a provider
//! requirement: `ub_bsearch` is a C99 `inline` definition **with a body**
//! (`src/unibreakdef.h:65-95`), so what the translation sees is that body and
//! the generator copies it verbatim instead of routing it. The compiled library
//! does export the symbol — `src/unibreakdef.c:175` closes it with an
//! `extern inline` external definition, which is the only reason the symbol
//! exists at all — but nothing in the dispatch calls it, so requiring it would
//! refuse a provider for a name this header never asks a caller to reach.
//!
//! The other two things those headers declare are not symbols either. `EOS`
//! (`src/unibreakdef.h:52`) and `ARRAY_LEN` (`src/unibreakdef.h:42`) are
//! macros; `get_next_char_t` (`src/unibreakdef.h:58`) is a function-pointer
//! typedef that libunibreak itself never calls through, so there is no caller
//! to fix a calling convention for. All three are re-exported from the
//! translated header by the dispatch, which is why `dispatch.EOS` below is the
//! header's own sentinel rather than a number written down twice.
//!
//! ## The ABI boundary, stated honestly
//!
//! libunibreak's public ABI is unusually narrow, and it is worth being precise
//! about what it does and does not pin, because "resolve the symbols and they
//! match" is not the claim.
//!
//!   * **Scalars, and which of them are load-bearing.** `utf8_t`, `utf16_t` and
//!     `utf32_t` are `unsigned char`, `unsigned short` and `unsigned int`
//!     (`src/unibreakbase.h:47-49`), so the code-unit widths are 1, 2 and 4 bytes
//!     on every ABI this package targets — that part is not a variable. What
//!     *is* load-bearing is `size_t`, which appears by value in every signature
//!     (`len`) and by pointer in the three decoders (`size_t *ip`), and
//!     `unsigned int` as both `utf32_t` and the return type of
//!     `is_line_breakable`. A provider built for a target where `size_t` is not
//!     the pointer width, or where `int` is not 32 bits, disagrees with this
//!     translation about the very first argument.
//!   * **Layout.** There is none to speak of. No public header declares a
//!     struct, and no entry point takes or returns one by value; the largest
//!     objects the API moves are the code-unit arrays and the `char *brks`
//!     output buffers, both of which are caller-allocated plain arrays whose
//!     element type the header states. That is why `unibreak_version` is the only
//!     data object: it is the only thing the API has whose *size* is part of a
//!     contract, and it is a single `int`.
//!   * **Configuration.** Two macros affect the compiled core, and both are
//!     build-time rather than ABI. `UNIBREAK_LAZY_INCB`
//!     (`src/graphemebreak.c:57-63`) selects whether Indic conjunct break
//!     clusters are computed lazily; it is left at upstream's own default of 0
//!     by this package's compile line. The C dialect is pinned to C99 on the
//!     same line, and it has to be: `ub_bsearch` is a C99 `inline` definition,
//!     and under C89's inline rule that definition emits no external symbol at
//!     all. Neither macro is visible to a caller, and neither changes a
//!     signature, so a provider built with different values has a *different
//!     answer for some text* rather than a different calling convention. The
//!     Unicode revision the tables were generated from is the same kind of fact:
//!     this tree is UAX #14 revision 55 and UAX #29 revision 47
//!     (`src/linebreak.h:33-34`, `src/graphemebreak.h:31-32`), and a provider
//!     generated from a different revision answers differently on the rows that
//!     changed.
//!   * **Allocator.** There is none. The core allocates nothing at all: the
//!     break passes write into buffers the caller supplies, and nothing here has
//!     a `free`, an allocator hook or a hidden static scratch area. The only
//!     mutable state in the whole library is what the caller passes in, so there
//!     is no ownership boundary a provider could get wrong and nothing for a test
//!     harness to supply a leak oracle for.
//!   * **Callbacks.** There are none. `get_next_char_t` names a function
//!     pointer type, but no public entry point takes one, so there is no
//!     callback convention for a provider and a caller to agree on.
//!   * **Variadics.** There are none. Every signature in the five headers is
//!     fixed-arity, so the dispatch's variadic `@call` path is not used here.
//!     It exists in the generator for SDKs that do have them; naming it as
//!     unused is more useful than leaving a reader to wonder.
//!
//! ## What is checked at load time, and what is not
//!
//! Resolving nineteen symbols and translating a header are the boundary. They
//! are not proof that a provider is compatible, and this file does not pretend
//! to add one. Three things are exercised after every symbol resolved and before
//! anything is published, and each is a check that an entry point *behaves* on a
//! library that is already fully resolved:
//!
//!   * The data object is **read through its own address**, never copied. This
//!     is the only way the one non-function symbol is exercised at all: a
//!     resolved address that is not readable provider storage would fail here
//!     rather than at the first `libunibreak.version()` in the program.
//!   * `ub_get_next_char_utf32` is called on a three-code-unit stack buffer, and
//!     its return value, its `EOS` answer at end of input, and the `size_t` it
//!     wrote back are all checked. That covers the `size_t` width, the
//!     `utf32_t` width and the sentinel constant in one call.
//!   * `set_linebreaks_utf32` is called on `"a b"` and its `char` buffer is read
//!     back. Rule LB7 forbids a break before the space and rule LB18 requires
//!     one after it, and the final position of text that does not end in an
//!     explicit break is `LINEBREAK_INDETERMINATE`, so those three opcodes are
//!     independent known answers rather than an echo of whatever the function
//!     does. It also proves the output buffer really is a caller-owned `char`
//!     array.
//!
//! **No version comparison is made, on purpose.** `unibreak_version` is read and
//! required to be non-zero, and that is all. Its value is `UNIBREAK_VERSION`,
//! `0x0800` (`src/unibreakbase.h:42`), at every 8.x release of this library, and
//! libunibreak's C ABI is stable across that series: the same eighteen
//! signatures, the same scalar widths, no struct added or resized. Refusing a
//! provider for reporting a different number would therefore reject a provider
//! this package's headers describe perfectly well, in exchange for no extra
//! safety. The Unicode revision that provider was built from is the fact that
//! actually changes its answers, and it is a build-time fact of the provider's
//! own tree, not something a load-time call can observe.
//!
//! None of these checks inspects a struct layout, and no load-time check could:
//! the caller is the only party that knows what it built. A caller that cares
//! about layout has to compile the same headers, which is what this package does.
const rt = @import("rt");

/// The synchronization this loader calls, bound by exact name.
///
/// The names below are `runtime/sync.h` compiled with
/// `RT_SYNC_PREFIX=libunibreak_rt`, which is what `runtime/graph.zig` passes. Two
/// spellings of that prefix have to agree: this file names the symbols, and
/// graph.zig defines the macro. A build where they disagree does not link, and
/// that is the whole error report: there is no runtime path that could hide it.
///
/// The core in `runtime/loader.zig` never names a symbol of its own, which is
/// what lets two SDKs, or two configurations of one SDK, hold their own loader
/// state in one process without sharing any of it.
pub const Sync = struct {
    extern fn libunibreak_rt_lock() void;
    extern fn libunibreak_rt_unlock() void;
    extern fn libunibreak_rt_wait() void;
    extern fn libunibreak_rt_broadcast() void;
    // `unsigned long long`. Declared as u64, which is the same type in every
    // ABI this SDK targets: 64-bit on x86_64, aarch64, riscv64 and wasm32.
    extern fn libunibreak_rt_thread_self() u64;

    pub fn lock() void {
        libunibreak_rt_lock();
    }
    pub fn unlock() void {
        libunibreak_rt_unlock();
    }
    pub fn wait() void {
        libunibreak_rt_wait();
    }
    pub fn broadcast() void {
        libunibreak_rt_broadcast();
    }
    pub fn threadSelf() u64 {
        return libunibreak_rt_thread_self();
    }
};

/// The loader's configuration for this SDK, given the dispatch that owns the
/// table.
///
/// `dispatch` is the generated module, passed as a type by the dispatch itself
/// so that this file never has to import it. The direction is one-way on
/// purpose: the descriptor knows what the loader needs, the dispatch knows what
/// the header said, and neither imports the other.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Named in the pre-load panic, so the message says which library was
        /// reached for before it was loaded.
        pub const library_name = "libunibreak";

        /// The table the generated dispatch declares, and the symbols it needs
        /// to fill it. Both come from the translated header, not from this file.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// The project's namespaced synchronization binding.
        pub const sync = Sync;

        pub fn tablePtr() *table {
            return dispatch.tablePtr();
        }

        pub fn ready() *rt.Ready {
            return &dispatch.ready;
        }

        pub fn assign(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assign(index, dst, address);
        }

        pub inline fn assignOptional(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assignOptional(index, dst, address);
        }

        pub inline fn assignMissing(comptime index: usize, dst: *table) void {
            dispatch.assignMissing(index, dst);
        }

        /// The library-specific checks, run after every symbol resolved and
        /// before anything is published.
        ///
        /// A non-null answer is `ValidationFailed`: the candidate is closed and
        /// nothing is published. Every check here runs on stack buffers and
        /// touches no global state, because the library has none — see the
        /// module comment for why there is no allocator here to be careful with.
        pub fn validate(dst: *const table) ?[]const u8 {
            // The one exported data object, read through the address the loader
            // resolved. This is the provider's own storage, not a copy of it,
            // which is the only honest way to exercise a non-function symbol:
            // a value read here is a value the loaded image holds right now.
            const version = dst.unibreak_version.*;
            if (version == 0) {
                return "unibreak_version read as zero, so the symbol resolved to " ++
                    "storage that is not the data object this header describes";
            }

            // Decode all three UTF-32 units, then require EOS without advancing
            // the index beyond the input (`src/unibreakdef.c:161-175`).
            const units = [_]u32{ 0x0061, 0x0020, 0x0062 };
            var at: usize = 0;
            if (dst.ub_get_next_char_utf32(&units, units.len, &at) != 0x0061 or at != 1) {
                return "ub_get_next_char_utf32 did not decode U+0061 and advance " ++
                    "one unit, so this provider's size_t and utf32_t widths are " ++
                    "not the ones these headers describe";
            }
            if (dst.ub_get_next_char_utf32(&units, units.len, &at) != 0x0020 or at != 2) {
                return "ub_get_next_char_utf32 decoded the wrong code point on " ++
                    "the second unit, so the symbol resolved but did not behave";
            }
            if (dst.ub_get_next_char_utf32(&units, units.len, &at) != 0x0062 or at != 3) {
                return "ub_get_next_char_utf32 did not decode U+0062 and advance " ++
                    "to the end of the input";
            }
            if (dst.ub_get_next_char_utf32(&units, units.len, &at) != dispatch.EOS) {
                return "ub_get_next_char_utf32 did not answer EOS at the end of " ++
                    "the input, so the end-of-string sentinel these headers " ++
                    "declare is not the one this provider returns";
            }
            if (at != 3) {
                return "ub_get_next_char_utf32 advanced past the end of the input, " ++
                    "so its index handling is not the one these headers describe";
            }

            // `set_linebreaks_utf32` on "a b", read back through the `char *`
            // buffer the C wrote. Rule LB7 forbids a break before the space
            // (`src/linebreak.c:1461` onward), rule LB18 permits one after it,
            // and text that does not end in an explicit break ends in
            // `LINEBREAK_INDETERMINATE` (`src/linebreak.c:1512-1515`), which is
            // a different opcode from both. Three independent answers, and the
            // write itself proves `brks` is a caller-owned `char` array.
            const spaced = [_]u32{ 0x0061, 0x0020, 0x0062 };
            var brks = [_]u8{ 0xFF, 0xFF, 0xFF };
            dst.set_linebreaks_utf32(&spaced, spaced.len, null, &brks);
            if (brks[0] != dispatch.LINEBREAK_NOBREAK) {
                return "set_linebreaks_utf32 did not report LINEBREAK_NOBREAK " ++
                    "before the space, so this provider's line-break rules are " ++
                    "not the UAX #14 set these headers describe";
            }
            if (brks[1] != dispatch.LINEBREAK_ALLOWBREAK) {
                return "set_linebreaks_utf32 did not report LINEBREAK_ALLOWBREAK " ++
                    "after the space, so this provider's line-break rules are " ++
                    "not the UAX #14 set these headers describe";
            }
            if (brks[2] != dispatch.LINEBREAK_INDETERMINATE) {
                return "set_linebreaks_utf32 did not report " ++
                    "LINEBREAK_INDETERMINATE at the end of ordinary text, so " ++
                    "this provider's final-position behaviour differs";
            }
            return null;
        }
    };
}