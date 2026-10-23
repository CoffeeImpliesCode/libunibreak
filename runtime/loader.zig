// SPDX-License-Identifier: Zlib
//
//! Generic dynamic-library loader for generated C dispatch modules.
//! It loads only the requested path or system name, then publishes after symbol resolution and validation succeed.
//! Failed attempts close their handle and remain retryable; successful handles stay loaded for process lifetime.

const std = @import("std");
const builtin = @import("builtin");

/// Names a library file or a system-loader name.
/// The two forms do not fall back or normalize into each other.
pub const LoadSource = union(enum) {
    /// Absolute file path; relative paths are rejected.
    path: []const u8,
    /// Basename or SONAME; path separators and embedded NULs are rejected.
    system: []const u8,
};

/// Every way `load` can decline.
pub const LoadError = error{
    /// The selected `.path` or `.system` value is empty.
    EmptySource,
    /// The request exceeds `max_source_len`; it is refused rather than truncated.
    SourceTooLong,
    /// A path is not absolute, a system name has a path component, or the request contains NUL.
    InvalidSource,
    /// The target has no dynamic loader; no provider is opened or published.
    UnsupportedTarget,
    /// The platform loader refused the requested library.
    OpenFailed,
    /// The provider lacks a required symbol; the candidate is closed and not published.
    MissingSymbol,
    /// Provider validation failed; the candidate is closed and not published.
    ValidationFailed,
    /// Another request is loaded or in flight; this call changes nothing.
    ProviderMismatch,
    /// The current thread called `load` recursively; it returns instead of deadlocking.
    ReentrantLoad,
};

/// The longest request the loader will remember, in bytes.
pub const max_source_len = 32768;

/// Stores a fixed-buffer request copy for later idempotence checks.
const SourceRecord = struct {
    tag: enum(u8) { none = 0, path, system } = .none,
    len: u32 = 0,
    bytes: [max_source_len]u8 = undefined,

    /// Called under the loader lock after checking the request length.
    fn set(self: *SourceRecord, request: LoadSource) void {
        const text = switch (request) {
            .path => |p| p,
            .system => |s| s,
        };
        @memcpy(self.bytes[0..text.len], text);
        self.len = @intCast(text.len);
        self.tag = switch (request) {
            .path => .path,
            .system => .system,
        };
    }

    /// Returns the request slice stored in this record.
    pub fn source(self: *const SourceRecord) ?LoadSource {
        const text = self.bytes[0..self.len];
        return switch (self.tag) {
            .none => null,
            .path => .{ .path = text },
            .system => .{ .system = text },
        };
    }
};

/// Compares request kind and bytes without normalization.
pub fn eqlSource(a: LoadSource, b: LoadSource) bool {
    return switch (a) {
        .path => |pa| switch (b) {
            .path => |pb| std.mem.eql(u8, pa, pb),
            .system => false,
        },
        .system => |sa| switch (b) {
            .system => |sb| std.mem.eql(u8, sa, sb),
            .path => false,
        },
    };
}

fn validateSource(source: LoadSource) LoadError!void {
    const text = switch (source) {
        .path => |p| p,
        .system => |s| s,
    };
    if (text.len == 0) return error.EmptySource;
    if (text.len > max_source_len) return error.SourceTooLong;
    if (std.mem.indexOfScalar(u8, text, 0) != null) return error.InvalidSource;
    switch (source) {
        .path => {
            const absolute = if (builtin.os.tag == .windows)
                switch (std.fs.path.getWin32PathType(u8, text)) {
                    .drive_absolute, .unc_absolute, .local_device, .root_local_device => true,
                    .relative, .rooted, .drive_relative => false,
                }
            else
                std.fs.path.isAbsolutePosix(text);
            if (!absolute) return error.InvalidSource;
        },
        .system => {
            for (text) |byte| {
                if (std.fs.path.isSep(byte)) return error.InvalidSource;
                if (builtin.os.tag == .windows and byte == ':') return error.InvalidSource;
            }
        },
    }
}

/// The three states of a configured module's table.
pub const Phase = enum(u8) {
    /// No provider is published; a new attempt may start after waiters drain.
    not_loaded = 0,
    /// One thread is filling the table.
    loading = 1,
    /// The table is published and usable.
    ready = 2,
};

/// Readiness flag for the table.
/// Release stores publish table writes to readers using acquire loads.
pub const Ready = struct {
    phase: std.atomic.Value(u8) = .init(@intFromEnum(Phase.not_loaded)),

    /// Reads readiness with acquire ordering.
    pub fn isReady(self: *const Ready) bool {
        return self.phase.load(.acquire) == @intFromEnum(Phase.ready);
    }

    /// The current state, for the loader's own decisions under its lock.
    pub fn state(self: *const Ready) Phase {
        return @enumFromInt(self.phase.load(.acquire));
    }

    /// Publish or withdraw the table, with release ordering.
    pub fn set(self: *Ready, value: Phase) void {
        self.phase.store(@intFromEnum(value), .release);
    }
};

/// Kind of exported symbol stored in a table field.
pub const SymbolKind = enum {
    /// Function pointer with the translated header's exact type.
    function,
    /// Provider-owned object address, not a copy of its value.
    data,
};

/// One required export: the name to look up and what kind of thing it is.
pub const Symbol = struct {
    /// The exported name, exactly as the C header spells it.
    name: [:0]const u8,
    /// What the table field holds for this symbol.
    kind: SymbolKind,
};

/// Panics in every optimization mode when a routed call precedes successful load.
/// The panic names the library and symbol.
pub fn panicNotReady(library: []const u8, comptime symbol: []const u8) noreturn {
    std.debug.panic(
        "{s}: {s} was called before this module was loaded; call " ++
            "load({{ .path = \"...\" }}) or load({{ .system = \"...\" }}) first",
        .{ library, symbol },
    );
}

/// False on WASI, Emscripten and freestanding targets.
pub const supported_target: bool = switch (builtin.os.tag) {
    .wasi, .emscripten, .freestanding => false,
    else => true,
};

/// Defines a process-global loader for a dispatch config with table, symbols, readiness, sync and validation hooks.
/// Provider constructors run outside the lock; a constructor waiting on another thread blocked in `load` can deadlock.
pub fn Loader(comptime Config: type) type {
    return struct {
        const LoaderType = @This();

        /// The table type this loader fills, for the configuration's own use.
        pub const table_type = Config.table;

        /// Active attempt or completed attempt with waiters still draining.
        attempt: ?Attempt = null,

        /// Fixed-buffer request copy, read under lock until readiness is published.
        request: SourceRecord = .{},

        /// Loads one provider; repeated or concurrent same-request calls share the outcome.
        /// Different requests mismatch; failed attempts can retry after waiters drain.
        pub fn load(self: *LoaderType, source: LoadSource) LoadError!void {
            try validateSource(source);
            // Same-provider repeats return after one acquire load.
            if (Config.ready().isReady()) return self.accept(source);

            Config.sync.lock();
            while (true) {
                switch (Config.ready().state()) {
                    .ready => {
                        Config.sync.unlock();
                        return self.accept(source);
                    },
                    .loading => {
                        const attempt = &self.attempt.?;
                        if (attempt.owner == Config.sync.threadSelf()) {
                            Config.sync.unlock();
                            return error.ReentrantLoad;
                        }
                        if (!eqlSource(self.request.source().?, source)) {
                            Config.sync.unlock();
                            return error.ProviderMismatch;
                        }
                        // Wait on this attempt rather than starting a competitor.
                        attempt.waiters += 1;
                        while (Config.ready().state() == .loading) Config.sync.wait();
                        const result = attempt.result;
                        attempt.waiters -= 1;
                        // Keep the attempt until every attached waiter has read its result.
                        Config.sync.broadcast();
                        Config.sync.unlock();
                        return result;
                    },
                    .not_loaded => {
                        // Wait for the previous attempt's waiters to drain before retrying.
                        if (self.attempt != null) {
                            Config.sync.wait();
                            continue;
                        }
                        break;
                    },
                }
            }

            self.request.set(source);
            self.attempt = .{ .owner = Config.sync.threadSelf() };
            Config.ready().set(.loading);
            Config.sync.unlock();

            // Open outside the lock; waiters track the attempt while provider constructors run.
            const outcome = runAttempt(self.request.source().?);
            const succeeded = if (outcome) |_| true else |_| false;

            Config.sync.lock();
            self.attempt.?.result = outcome;
            Config.ready().set(if (succeeded) .ready else .not_loaded);
            // Wake waiters; the attempt cannot drain until each has read its result.
            Config.sync.broadcast();
            // Keep the record until waiters drain, releasing the lock while they run.
            while (self.attempt.?.waiters > 0) Config.sync.wait();
            self.attempt = null;
            // Wake callers waiting to start a retry.
            Config.sync.broadcast();
            Config.sync.unlock();

            return outcome;
        }

        /// Returns the retained request after success, or null before success.
        pub fn loadedSource(self: *const LoaderType) ?LoadSource {
            if (!Config.ready().isReady()) return null;
            return self.request.source();
        }

        /// The request already in use, checked against a new one.
        fn accept(self: *const LoaderType, source: LoadSource) LoadError!void {
            // The acquire load precedes every call to accept.
            const published = self.request.source() orelse unreachable;
            if (eqlSource(published, source)) return;
            return error.ProviderMismatch;
        }

        /// Opens, resolves and validates outside the lock.
        /// Closes the candidate on failure and never publishes the table.
        fn runAttempt(source: LoadSource) LoadError!void {
            const handle = platform.open(source) catch |err| return err;

            var retain = false;
            defer if (!retain) platform.close(handle);

            if (@hasDecl(Config, "optional_symbols")) {
                inline for (Config.optional_symbols, 0..) |_, index| {
                    Config.assignMissing(index, Config.tablePtr());
                }
            }

            inline for (Config.symbols, 0..) |symbol, index| {
                const address = platform.lookup(handle, symbol.name) orelse
                    return error.MissingSymbol;
                Config.assign(index, Config.tablePtr(), address);
            }

            if (@hasDecl(Config, "optional_symbols")) {
                inline for (Config.optional_symbols, 0..) |symbol, index| {
                    if (platform.lookup(handle, symbol.name)) |address| {
                        Config.assignOptional(index, Config.tablePtr(), address);
                    }
                }
            }

            if (@hasDecl(Config, "validate")) {
                if (Config.validate(Config.tablePtr())) |refusal| {
                    // Print the provider-specific refusal before returning the error.
                    std.debug.print("{s}: refusing this provider: {s}\n", .{
                        Config.library_name,
                        refusal,
                    });
                    return error.ValidationFailed;
                }
            }

            // Retain the handle because table pointers refer to it.
            retain = true;
        }
    };
}

/// One in-flight or undrained load attempt.
const Attempt = struct {
    /// Identity of the thread running the attempt, for the reentrancy check.
    owner: u64,
    /// Result read after readiness leaves `.loading`.
    result: LoadError!void = error.OpenFailed,
    /// Attached callers that have not read the result.
    waiters: usize = 0,
};

/// 32768 UTF-16 units cover Windows' 32767-unit path limit.
const windows_path_units = 32768;

const platform = if (builtin.os.tag == .windows)
    Windows
else if (supported_target)
    Unix
else
    NoLoader;

/// A target with no dynamic loader. Every request is refused by name.
const NoLoader = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget };

    fn open(source: LoadSource) OpenError!*anyopaque {
        _ = source;
        return error.UnsupportedTarget;
    }
    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        _ = handle;
        _ = name;
        return null;
    }
    fn close(handle: *anyopaque) void {
        _ = handle;
    }
};

const Unix = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget };

    fn open(source: LoadSource) OpenError!*anyopaque {
        const text = switch (source) {
            .path => |p| p,
            .system => |s| s,
        };
        var buffer: [max_source_len + 1]u8 = undefined;
        @memcpy(buffer[0..text.len], text);
        buffer[text.len] = 0;
        // `RTLD_NOW` reports missing dependencies at open; `RTLD_LOCAL` keeps provider symbols
        // out of the global namespace used by other SDKs.
        return std.c.dlopen(
            // `dlopen` requires a sentinel-terminated path.
            buffer[0..text.len :0].ptr,
            .{ .NOW = true, .GLOBAL = false },
        ) orelse error.OpenFailed;
    }

    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        return std.c.dlsym(handle, name.ptr);
    }

    fn close(handle: *anyopaque) void {
        _ = std.c.dlclose(handle);
    }
};

const kernel32 = struct {
    extern "kernel32" fn LoadLibraryExW(
        file_name: [*:0]const u16,
        file: ?*anyopaque,
        flags: u32,
    ) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn GetProcAddress(module: *anyopaque, name: [*:0]const u8) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn FreeLibrary(module: *anyopaque) callconv(.winapi) i32;
};

const Windows = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget, SourceTooLong };

    /// Searches standard directories for names; separator-containing paths are used as written.
    const load_library_search_default_dirs: u32 = 0x0000_1000;
    const load_library_search_dll_load_dir: u32 = 0x0000_0100;

    fn open(source: LoadSource) OpenError!*anyopaque {
        const text = switch (source) {
            .path => |p| p,
            .system => |s| s,
        };
        if (text.len > windows_path_units) return error.SourceTooLong;
        var buffer: [windows_path_units + 1]u16 = undefined;
        const units = std.unicode.utf8ToUtf16Le(buffer[0..text.len], text) catch
            return error.OpenFailed;
        buffer[units] = 0;
        return kernel32.LoadLibraryExW(
            buffer[0..units :0],
            null,
            load_library_search_default_dirs | switch (source) {
                .path => load_library_search_dll_load_dir,
                .system => @as(u32, 0),
            },
        ) orelse error.OpenFailed;
    }

    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        return kernel32.GetProcAddress(handle, name.ptr);
    }

    fn close(handle: *anyopaque) void {
        _ = kernel32.FreeLibrary(handle);
    }
};
