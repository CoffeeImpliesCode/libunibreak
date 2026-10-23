// SPDX-License-Identifier: MIT
//
//! libunibreak-specific loader configuration: synchronization, required exports and validation.
//! The provider must match this target's translated C ABI and export 18 functions plus `unibreak_version`.
//! Validation checks the version object, UTF-32 decoding and one line-break result, not the Unicode table revision.
const rt = @import("rt");

/// Namespaced synchronization functions used by the loader.
/// Prefix must match `runtime/graph.zig` at link time.
pub const Sync = struct {
    extern fn libunibreak_rt_lock() void;
    extern fn libunibreak_rt_unlock() void;
    extern fn libunibreak_rt_wait() void;
    extern fn libunibreak_rt_broadcast() void;
    // `unsigned long long` maps to `u64` on this target set.
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

/// Builds the libunibreak-specific loader configuration for the generated dispatch.
/// The descriptor binds names and synchronization without importing the dispatch.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Name shown in pre-load panic messages.
        pub const library_name = "libunibreak";

        /// Generated table and symbol lists from the translated header.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// Namespaced synchronization binding.
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

        /// Validates the resolved provider before the loader publishes its table.
        /// Returns a diagnostic when the candidate must be rejected.
        pub fn validate(dst: *const table) ?[]const u8 {
            // Read the exported version from the provider-owned object.
            const version = dst.unibreak_version.*;
            if (version == 0) {
                return "unibreak_version read as zero, so the symbol resolved to " ++
                    "storage that is not the data object this header describes";
            }

            // Decode all three units, then require EOS without advancing past the input.
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

            // Verify "a b": no break before the space, break after, and indeterminate at end.
            // The provider writes into caller-owned `char` storage.
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
