const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shell_exe = b.addExecutable(.{
        .name = "shell",
        .root_source_file = b.path("src/shell/shell.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(shell_exe);

    const run_shell = b.addRunArtifact(shell_exe);
    if (b.args) |args| run_shell.addArgs(args);
    const run_shell_step = b.step("run-shell", "Run the shell");
    run_shell_step.dependOn(&run_shell.step);
    
    const test_step = b.step("test", "Run unit tests");
    
    const shell_tests = b.addTest(.{
        .root_source_file = b.path("src/shell/tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_shell_tests = b.addRunArtifact(shell_tests);
    test_step.dependOn(&run_shell_tests.step);
    
    const linreg_tests = b.addTest(.{
        .root_source_file = b.path("src/algorithms/linreg.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_linreg_tests = b.addRunArtifact(linreg_tests);
    test_step.dependOn(&run_linreg_tests.step);
}
