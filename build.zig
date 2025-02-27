const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const shell_exe = b.addExecutable(.{
        .name = "shell",
        .root_source_file = b.path("shell/shell.zig"),
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
        .root_source_file = b.path("shell/shell.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_shell_tests = b.addRunArtifact(shell_tests);
    test_step.dependOn(&run_shell_tests.step);
    
    const linreg_tests = b.addTest(.{
        .root_source_file = b.path("algorithms/linreg.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_linreg_tests = b.addRunArtifact(linreg_tests);
    test_step.dependOn(&run_linreg_tests.step);
    
    const search_name_tests = b.addTest(.{
        .root_source_file = b.path("algorithms/search_name.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_search_name_tests = b.addRunArtifact(search_name_tests);
    test_step.dependOn(&run_search_name_tests.step);
    
    
    const linreg_runner_exe = b.addExecutable(.{
        .name = "linreg_runner",
        .root_source_file = b.path("profiling/linreg_runner.zig"),
        .target = target,
        .optimize = optimize,
    });
    linreg_runner_exe.root_module.addImport("linreg", b.createModule(.{
        .root_source_file = b.path("algorithms/linreg.zig"),
    }));
    linreg_runner_exe.root_module.addImport("search_name_module", b.createModule(.{
        .root_source_file = b.path("algorithms/search_name.zig"),
    }));
    b.installArtifact(linreg_runner_exe);
}
