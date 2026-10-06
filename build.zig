const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zig lib
    const root = b.addModule("permafrost", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // static lib
    const lib = b.addLibrary(.{
        .name = "permafrost",
        .linkage = .static,
        .root_module = root,
    });
    b.installArtifact(lib);

    // tests
    const tests = b.addTest(.{
        .root_module = root,
    });
    const tests_build = b.addInstallArtifact(tests, .{});
    const tests_cmd = b.step("test", "run the tests");
    const tests_run = b.addRunArtifact(tests);
    tests_cmd.dependOn(&tests_run.step);
    tests_run.step.dependOn(&tests_build.step);
}
