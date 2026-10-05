const std = @import("std");

/// A package that consumes `libunibreak` from outside.
///
/// This exists to prove one thing: that a dependent needs nothing but
/// `dep.module("libunibreak")` and gets a working, correctly linked library
/// whose line, word and grapheme breaking agrees with what the same input
/// produces here. If the published module stopped carrying the compiled C core,
/// or if the translated headers stopped matching the C the module was built
/// from, this would stop building or stop producing the same break positions,
/// and nothing inside the library would notice.
///
/// There is deliberately no `dep.artifact` here. The library reaches this
/// program through the module, so a second link would be a redundancy that
/// proves nothing; what is being proved is that one import is enough.
///
/// `-Dlinkage` and `-Druntime` are forwarded to the library's own options of
/// the same name. They exist here so that `zig build run -Dlinkage=dynamic`
/// and `zig build run -Druntime=true` are real consumers of the shared and the
/// runtime configurations rather than of the default one only: a consumer that
/// could only ever see a static linked module would be no evidence for either.
/// `build.zig`'s `consumer` step passes both explicitly, so a run through that
/// step never depends on these defaults agreeing with the library's; the
/// defaults below are stated only for a caller who runs `zig build run` in this
/// directory directly, and they are the library's own defaults - `static`, and
/// runtime loading off. The library's build graph owns both meanings; this file
/// only repeats the names.
///
/// Run it with `zig build run`.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Forwarded to the libunibreak dependency: which native delivery its " ++
            "module dispatches through. static (the default) or dynamic.",
    ) orelse .static;
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Forwarded to the libunibreak dependency: build it so its native " ++
            "entry points are resolved by an explicit load at run time instead " ++
            "of linked into the module. Default off.",
    ) orelse false;

    const dep = b.dependency("libunibreak", .{
        .target = target,
        .optimize = optimize,
        .linkage = linkage,
        .runtime = runtime_loaded,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("libunibreak", dep.module("libunibreak"));

    const exe = b.addExecutable(.{
        .name = "libunibreak-consumer",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);
    // `src/main.zig` names the provider with `--provider <path>` on argv
    // (`:55-77`), and `b.args` is where those arrive. `Step.Run` never forwards
    // them itself, so without this line `zig build run -- --provider <path>`
    // drops the flag, the program finds no `LIBUNIBREAK_TEST_PROVIDER`, and
    // exits telling the caller to pass the flag they just passed.
    if (b.args) |args| run_exe.addArgs(args);
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}
