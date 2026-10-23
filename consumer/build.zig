const std = @import("std");

/// External consumer using only `dep.module("libunibreak")` and package linkage/runtime options.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(
        std.lang.LinkMode,
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
    // Forward program arguments after `--`.
    run_exe.addPassthruArgs();
    const run_step = b.step("run", "Build and run the consumer program");
    run_step.dependOn(&run_exe.step);
}
