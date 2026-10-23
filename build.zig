//! Build libunibreak from its upstream C sources.

const std = @import("std");

/// Runtime-loading build graph and shared public loader types.
const runtime_graph = @import("runtime/graph.zig");

const manifest = @import("build.zig.zon");

const manifest_version = std.SemanticVersion.parse(manifest.version) catch
    @panic("build.zig.zon: .version is not a semantic version");

const module_name = "libunibreak";

const lib_name = "unibreak";

const facade_source = "zig/root.zig";

const exercise_source = "zig/api_exercise.zig";

const translate_header = "zig/translate.h";

const test_source = "tests.zig";

const example_source = "smoke.zig";

/// Upstream's 8.0 release, checked against the manifest.
const upstream_version_text = "8.0";

/// Upstream's shared-library ABI version; static archives have none.
const abi_version: std.SemanticVersion = .{ .major = 8, .minor = 0, .patch = 0 };

/// C99 is required for upstream's `extern inline` definition of `ub_bsearch`.
/// Without it, table-using translation units fail to link.
const c_flags = [_][]const u8{"-std=c99"};

/// Upstream's nine core translation units; generated tables are included, not compiled separately.
const core_sources = [_][]const u8{
    "src/unibreakbase.c",
    "src/unibreakdef.c",
    "src/linebreak.c",
    "src/linebreakdata.c",
    "src/linebreakdef.c",
    "src/eastasianwidthdef.c",
    "src/emojidef.c",
    "src/graphemebreak.c",
    "src/wordbreak.c",
};

/// Upstream's five installed public headers.
const public_headers = [_][]const u8{
    "src/unibreakbase.h",
    "src/unibreakdef.h",
    "src/linebreak.h",
    "src/graphemebreak.h",
    "src/wordbreak.h",
};

const source_dir = "src";

/// Preserve upstream's non-lazy InCB lookup.
const lazy_incb_macro = [_][2][]const u8{
    .{ "UNIBREAK_LAZY_INCB", "0" },
};

const upstream_test_source = "src/tests.c";

/// Upstream's conformance test selectors, in source order.
const upstream_test_selectors = [_][]const u8{ "line", "word", "grapheme" };

/// Compile-only matrix used when no target is selected.
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

/// Artifacts and modules for one target.
const Graph = struct {
    c_lib: *std.Build.Step.Compile,
    module: *std.Build.Module,
    /// Shared module instance; separate translations create incompatible Zig types.
    c_module: *std.Build.Module,
};

/// Licence and provenance files installed under `share/licenses/libunibreak/`.
const licence_records = [_][]const u8{
    "LICENCE",
    "LICENCE-UNICODE.txt",
    "AUTHORS",
    "README.upstream.md",
    "FORK-NOTES.md",
    "UPSTREAM.sha256",
};

fn artifactName(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    public: bool,
) []const u8 {
    if (public) return lib_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}", .{ lib_name, triple });
}

/// Install the package's licence and provenance records.
fn installLicenceRecords(b: *std.Build) void {
    for (licence_records) |record| {
        b.installFile(record, b.fmt("share/licenses/{s}/{s}", .{ module_name, record }));
    }
}

/// Windows uses PE loading without a dynamic-linker path.
fn targetHasDynamicLinker(target: std.Build.ResolvedTarget) bool {
    return target.result.os.tag == .windows or std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

/// Reject unsupported shared linkage instead of falling back to a static archive.
fn unsupportedLinkageMessage(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
) []const u8 {
    return b.fmt(
        "libunibreak: -Dlinkage=dynamic was requested for {s}, whose OS has " ++
            "no dynamic linker, so it cannot carry a shared object. This build " ++
            "does not substitute a static archive for the shared object that " ++
            "was asked for; build this target with -Dlinkage=static, which is " ++
            "this SDK's default.",
        .{@tagName(target.result.os.tag)},
    );
}

/// Compile the core for one target with the requested linkage and C flags.
fn addCoreLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    name: []const u8,
) *std.Build.Step.Compile {
    const c_lib = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        // Use upstream's ABI version only for shared libraries.
        .version = if (linkage == .dynamic) abi_version else null,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            // Shared objects require PIC; leave the static build unchanged.
            .pic = if (linkage == .dynamic) true else null,
        }),
    });
    const c_mod = c_lib.root_module;

    // Upstream's public headers define no export macro; do not invent one.
    c_mod.addIncludePath(b.path(source_dir));
    for (lazy_incb_macro) |macro| {
        c_mod.addCMacro(macro[0], macro[1]);
    }
    for (core_sources) |source| {
        c_mod.addCSourceFile(.{
            .file = b.path(source),
            .flags = &c_flags,
        });
    }

    // Install only upstream's public headers.
    for (public_headers) |header| {
        c_lib.installHeader(b.path(header), std.fs.path.basename(header));
    }

    return c_lib;
}

/// Build the facade and translated C module for one target.
fn addGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
    public: bool,
) Graph {
    const c_lib = addCoreLibrary(b, target, optimize, linkage, artifactName(b, target, public));

    const translate = b.addTranslateC(.{
        .root_source_file = b.path(translate_header),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    // Resolve the wrapper's public headers from this source tree.
    translate.addIncludePath(b.path(source_dir));

    const module = if (public)
        b.addModule(module_name, .{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

    // Reuse the translated module in runtime dispatch; separate translations
    // create nominally distinct Zig types.
    const c_module: *std.Build.Module = if (runtime_loaded)
        // Runtime dispatch resolves symbols from the caller's provider.
        runtime_graph.createModule(b, translate, target, optimize)
    else blk: {
        const translated = translate.createModule();
        module.addImport("rt", runtime_graph.createCoreModule(b, target, optimize));
        module.linkLibrary(c_lib);
        break :blk translated;
    };

    // Expose translated declarations through the facade, not a separate module.
    module.addImport("c", c_module);
    // Match the core module's include path for dependent C compilations.
    module.addIncludePath(b.path(source_dir));

    return .{ .c_lib = c_lib, .module = module, .c_module = c_module };
}

/// Create a program module that imports the facade and optional C declarations.
fn programModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    source: []const u8,
    with_c: bool,
) *std.Build.Module {
    const mod = b.createModule(.{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport(module_name, graph.module);
    if (with_c) mod.addImport("c", graph.c_module);
    return mod;
}

/// Build upstream's conformance harness against the selected core library.
fn addUpstreamTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    graph: Graph,
    name: []const u8,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addIncludePath(b.path(source_dir));
    mod.addCSourceFile(.{
        .file = b.path(upstream_test_source),
        .flags = &c_flags,
    });
    mod.linkLibrary(graph.c_lib);
    return b.addExecutable(.{ .name = name, .root_module = mod });
}

/// Add compile-only checks for every matrix target.
fn addTargetCheck(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
) void {
    const cross_target = b.resolveTargetQuery(query);
    // Distinguish matrix steps by target in the build summary.
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // Keep unsupported linkage visible as a failed matrix cell.
    if (linkage == .dynamic and !targetHasDynamicLinker(cross_target)) {
        const refusal = std.Build.Step.Fail.create(
            b,
            b.fmt("{s}\n  target: {s}", .{
                unsupportedLinkageMessage(b, cross_target),
                triple,
            }),
        );
        refusal.step.name = b.fmt("check {s}: unsupported -Dlinkage=dynamic", .{triple});
        step.dependOn(&refusal.step);
        return;
    }

    const graph = addGraph(b, cross_target, optimize, linkage, runtime_loaded, false);

    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("libunibreak-exercise-{s}", .{triple}),
        .root_module = programModule(b, cross_target, optimize, graph, exercise_source, true),
    }).step);

    step.dependOn(&b.addTest(.{
        .name = b.fmt("libunibreak-tests-{s}", .{triple}),
        .root_module = programModule(b, cross_target, optimize, graph, test_source, false),
    }).step);

    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("libunibreak-smoke-{s}", .{triple}),
        .root_module = programModule(b, cross_target, optimize, graph, example_source, false),
    }).step);

    step.dependOn(&addUpstreamTest(
        b,
        cross_target,
        optimize,
        graph,
        b.fmt("libunibreak-upstream-tests-{s}", .{triple}),
    ).step);
}

/// Generate pkg-config metadata from upstream's template.
/// Keep the prefix relocatable and use the validated manifest version.
/// Preserve upstream's `Libs` and `Cflags`; libc is the only dependency.
fn addPkgConfig(b: *std.Build) void {
    const files = b.addWriteFiles();
    const pc = b.addInstallFileWithDir(
        files.add("libunibreak.pc", b.fmt(
            \\# Generated by build.zig from upstream's libunibreak.pc.in.
            \\# Field names and order are upstream's; build.zig's addPkgConfig
            \\# says which two values differ from an autotools-configured file
            \\# and why.
            \\libunibreak:
            \\prefix=${{pcfiledir}}/../..
            \\exec_prefix=${{prefix}}
            \\libdir=${{prefix}}/lib
            \\includedir=${{prefix}}/include
            \\
            \\Name: libunibreak
            \\Description: Library to implement Unicode algorithms for line and word breaking
            \\Version: {f}
            \\Libs: -L"${{libdir}}" -lunibreak
            \\Cflags: -I"${{includedir}}"
            \\
        , .{manifest_version})),
        .lib,
        "pkgconfig/libunibreak.pc",
    );
    // addInstallFileWithDir creates a step but does not attach it to install.
    // Add the dependency so generated metadata reaches the prefix.
    b.getInstallStep().dependOn(&pc.step);
}

/// Run the separate consumer build with this graph's target and options.
/// Install only when the host cannot execute the target binary.
fn runConsumer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
) *std.Build.Step.Run {
    const query = target.query;
    // addArg copies arguments, so free temporary strings after appending.
    const triple = query.zigTriple(b.allocator) catch @panic("OOM");
    defer b.allocator.free(triple);
    const cpu = query.serializeCpuAlloc(b.allocator) catch @panic("OOM");
    defer b.allocator.free(cpu);

    // Use the Zig executable running this build script.
    const run = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
    run.setName("consumer package");
    run.setCwd(b.path("consumer"));
    run.addArg(if (hostCanExecute(b, target)) "run" else "install");
    run.addArg(b.fmt("-Dtarget={s}", .{triple}));
    // Forward CPU model and features; the target triple does not include them.
    run.addArg(b.fmt("-Dcpu={s}", .{cpu}));
    run.addArg(b.fmt("-Doptimize={s}", .{@tagName(optimize)}));
    run.addArg(b.fmt("-Dlinkage={s}", .{@tagName(linkage)}));
    run.addArg(b.fmt("-Druntime={}", .{runtime_loaded}));
    // Forward enabled executor flags.
    if (b.enable_darling) run.addArg("-fdarling");
    if (b.enable_qemu) run.addArg("-fqemu");
    if (b.enable_rosetta) run.addArg("-frosetta");
    if (b.enable_wasmtime) run.addArg("-fwasmtime");
    if (b.enable_wine) run.addArg("-fwine");
    if (b.libc_runtimes_dir) |runtimes| run.addArgs(&.{ "--libc-runtimes", runtimes });
    // Keep nested builds at the workspace's job count.
    run.addArg("-j8");
    // Show every nested build step in the task output.
    run.addArgs(&.{ "--summary", "all" });
    // Use the build runner's two-argument `--cache-dir` syntax.
    if (b.cache_root.path) |cache| {
        run.addArg("--cache-dir");
        run.addArg(b.fmt("{s}/consumer", .{cache}));
    }
    // Share the content-addressed global cache, not the per-build local cache.
    if (b.graph.global_cache_root.path) |global_cache| {
        run.addArg("--global-cache-dir");
        run.addArg(global_cache);
    }
    // Forward only a caller-selected prefix, resolving relative paths here.
    const default_prefix = b.build_root.join(b.allocator, &.{"zig-out"}) catch @panic("OOM");
    if (!std.mem.eql(u8, b.install_prefix, default_prefix)) {
        const prefix = if (std.fs.path.isAbsolute(b.install_prefix))
            b.install_prefix
        else
            b.pathJoin(&.{ b.graph.cache.cwd, b.install_prefix });
        run.addArg("--prefix");
        run.addArg(prefix);
    }
    // Forward consumer arguments after `--` as program arguments.
    if (b.args) |args| {
        run.addArg("--");
        run.addArgs(args);
    }
    run.has_side_effects = true;
    return run;
}

/// Whether this host can execute a binary for the resolved target.
fn hostCanExecute(b: *std.Build, target: std.Build.ResolvedTarget) bool {
    const host = &b.graph.host.result;
    const candidate = &target.result;
    const options: std.zig.system.GetExternalExecutorOptions = .{
        .allow_darling = b.enable_darling,
        .allow_qemu = b.enable_qemu,
        .allow_wasmtime = b.enable_wasmtime,
        .allow_wine = b.enable_wine,
        // QEMU needs libc runtimes to launch foreign GNU libc binaries.
        .qemu_fixes_dl = candidate.isGnuLibC() and b.libc_runtimes_dir != null,
        .link_libc = true,
    };
    return switch (std.zig.system.getExternalExecutor(b.graph.io, host, candidate, options)) {
        .native, .rosetta => true,
        .qemu => !candidate.isGnuLibC() or b.libc_runtimes_dir != null,
        .wine, .wasmtime, .darling => true,
        .bad_dl, .bad_os_or_cpu => false,
    };
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Preserve requested linkage; refuse unsupported targets instead of falling back.
    const linkage_option = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default, and " ++
            "what this package has always produced) or as a real shared object " ++
            "with upstream's own soname libunibreak.so.8, from its libtool " ++
            "-version-info 8:0:0. This selects the delivery and never the " ++
            "dispatch: the same C is compiled either way, and -Druntime is " ++
            "independent of it. Requesting a shared object for a target whose " ++
            "OS has no dynamic linker is refused, not answered with an archive.",
    );
    const linkage: std.builtin.LinkMode = linkage_option orelse .static;
    if (linkage == .dynamic and !targetHasDynamicLinker(target)) {
        @panic(unsupportedLinkageMessage(b, target));
    }

    // Runtime loading changes dispatch, not which artifact the build produces.
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Resolve the native entry points at run time instead of linking them. " ++
            "The facade keeps the same translated header and the same public " ++
            "types; each selected native function becomes a dispatch through " ++
            "one process-lifetime table that an explicit load(source) fills, " ++
            "and the module links no archive. Independent of -Dlinkage, which " ++
            "still decides which artifact this build delivers and installs. " ++
            "Default off, and a linked build is unchanged in every respect.",
    ) orelse false;

    // Reject a manifest version that no longer matches the pinned upstream source.
    const manifest_major_minor = b.fmt("{d}.{d}", .{ manifest_version.major, manifest_version.minor });
    if (!std.mem.eql(u8, manifest_major_minor, upstream_version_text)) {
        @panic("build.zig.zon .version no longer matches the version read out " ++
            "of configure.ac and src/unibreakbase.h; see UPSTREAM.md");
    }

    const graph = addGraph(b, target, optimize, linkage, runtime_loaded, true);

    // Install the selected library and pkg-config metadata for C consumers.
    b.installArtifact(graph.c_lib);
    addPkgConfig(b);
    // Preserve upstream's licence texts and README at the prefix root.
    b.installFile("LICENCE", "LICENCE");
    b.installFile("LICENCE-UNICODE.txt", "LICENCE-UNICODE.txt");
    b.installFile("README.upstream.md", "README.upstream.md");
    b.installFile("NOTICE.md", "share/licenses/libunibreak/NOTICE.md");
    b.installFile("FORK-LICENSE.md", "share/licenses/libunibreak/FORK-LICENSE.md");
    b.installFile("UPSTREAM.md", "share/licenses/libunibreak/UPSTREAM.md");
    b.installFile("src/LineBreakTest.txt", "share/libunibreak/LineBreakTest.txt");
    b.installFile("src/WordBreakTest.txt", "share/libunibreak/WordBreakTest.txt");
    b.installFile("src/GraphemeBreakTest.txt", "share/libunibreak/GraphemeBreakTest.txt");
    b.installFile("tools/test.txt", "share/libunibreak/test.txt");

    // Install attribution and provenance records under share/licenses/libunibreak/.
    installLicenceRecords(b);

    // Compile the example as a smoke check; do not install it.
    const example = b.addExecutable(.{
        .name = "libunibreak-smoke",
        .root_module = programModule(b, target, optimize, graph, example_source, false),
    });
    b.getInstallStep().dependOn(&example.step);

    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    if (b.args) |args| run_example.addArgs(args);
    b.step("smoke", "Run the deterministic example program").dependOn(&run_example.step);

    const unit_tests = b.addTest(.{
        .name = "libunibreak-tests",
        .root_module = programModule(b, target, optimize, graph, test_source, false),
    });
    const run_tests = b.addRunArtifact(unit_tests);
    run_tests.has_side_effects = true;
    const test_step = b.step("test", "Run the facade tests and every API operation");
    test_step.dependOn(&run_tests.step);

    // Instantiate every facade method for native and cross-target builds.
    const exercise = b.addExecutable(.{
        .name = "libunibreak-exercise",
        .root_module = programModule(b, target, optimize, graph, exercise_source, true),
    });
    const run_exercise = b.addRunArtifact(exercise);
    run_exercise.has_side_effects = true;
    b.getInstallStep().dependOn(&exercise.step);
    test_step.dependOn(&run_exercise.step);
    b.step("exercise", "Run the API exercise: every public facade method once").dependOn(&run_exercise.step);

    // Run upstream's harness from src/ so it reads fixtures at their recorded paths.
    const upstream_step = b.step(
        "upstream-test",
        "Build and run upstream's own unmodified src/tests.c against the three " ++
            "Unicode fixtures in src/",
    );
    const upstream_tests = addUpstreamTest(b, target, optimize, graph, "libunibreak-upstream-tests");
    for (upstream_test_selectors) |selector| {
        const run = b.addRunArtifact(upstream_tests);
        run.setName(b.fmt("src/tests.c {s}", .{selector}));
        run.addArg(selector);
        run.setCwd(b.path(source_dir));
        // Always rerun the upstream harness against the complete fixtures.
        run.has_side_effects = true;
        upstream_step.dependOn(&run.step);
    }

    // Build the consumer for every target; run it only where this host can execute it.
    b.step("consumer", "Build the consumer/ package for the selected target, and run it when this host can execute it").dependOn(&runConsumer(b, target, optimize, linkage, runtime_loaded).step);

    // Compile every graph component; this matrix does not run binaries.
    const check_step = b.step(
        "check",
        "Compile the C core, the facade, the API exercise, the tests, the " ++
            "example and upstream's own C harness for the six-target matrix " ++
            "without running any of them",
    );
    if (!target.query.isNative()) {
        addTargetCheck(b, check_step, target.query, optimize, linkage, runtime_loaded);
    } else {
        for (check_targets) |query| {
            addTargetCheck(b, check_step, query, optimize, linkage, runtime_loaded);
        }
    }

    // Report configuration only; these lines are not test results.
    std.debug.print(
        "libunibreak: {d} core translation units from {s}/, C99, UNIBREAK_LAZY_INCB={s}, {d} public headers, {s}\n",
        .{
            core_sources.len,
            source_dir,
            lazy_incb_macro[0][1],
            public_headers.len,
            switch (linkage) {
                .static => "static archive (default)",
                .dynamic => b.fmt("shared object, soname libunibreak.so.{d}", .{abi_version.major}),
            },
        },
    );
    if (runtime_loaded) {
        // Distinguish runtime dispatch from artifact delivery in the build report.
        std.debug.print(
            "libunibreak: runtime-loaded dispatch (-Druntime=true); no library " ++
                "is linked into the module, and a provider is named by an " ++
                "explicit load(source)\n",
            .{},
        );
    }
}
