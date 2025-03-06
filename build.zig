const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const profiles_data_dir = b.path(b.option(
        []const u8,
        "profiles-data-dir",
        "Directory for profiling data",
    ) orelse "profiling/data");
    const profiling_processes = b.option(
        []const u8,
        "profiling-processes",
        "Comma separated list of processes amount to run profiling on, e.g.: 1,4,8",
    ) orelse "1,2,4,8,16";
    var processes_iter = std.mem.splitScalar(u8, profiling_processes, ',');

    const shell_exe = b.addExecutable(.{
        .name = "shell",
        .root_source_file = b.path("shell/shell.zig"),
        .target = target,
        .optimize = optimize,
    });

    const linreg_mod = b.createModule(.{
        .root_source_file = b.path("algorithms/linreg.zig"),
        .target = target,
        .optimize = optimize,
    });

    const search_name_mod = b.createModule(.{
        .root_source_file = b.path("algorithms/search_name.zig"),
        .target = target,
        .optimize = optimize,
    });

    const linreg_runner_exe = b.addExecutable(.{
        .name = "linreg_runner",
        .root_source_file = b.path("profiling/linreg_runner.zig"),
        .target = target,
        .optimize = optimize,
    });
    linreg_runner_exe.root_module.addImport("linreg", linreg_mod);

    const search_name_runner_exe = b.addExecutable(.{
        .name = "search_name_runner",
        .root_source_file = b.path("profiling/search_name_runner.zig"),
        .target = target,
        .optimize = optimize,
    });
    search_name_runner_exe.root_module.addImport("search_name", search_name_mod);

    const run_shell_step = b.step("run-shell", "Run the shell");
    const run_shell = b.addRunArtifact(shell_exe);
    run_shell_step.dependOn(&run_shell.step);

    const test_step = b.step("test", "Run unit tests");
    const test_files = &.{
        "shell/shell.zig",
        "algorithms/linreg.zig",
        "algorithms/search_name.zig",
    };
    inline for (test_files) |test_file| {
        const tests = b.addTest(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });
        const run_tests = b.addRunArtifact(tests);
        test_step.dependOn(&run_tests.step);
    }

    const profile_step = b.step("profile", "Run algorithms' profiling");
    const linreg_fits = "10000000";
    const linreg_predicts_per_fit = "100";
    const search_name_repeats = "1000";
    while (processes_iter.next()) |processes| {
        const processes_number = try std.fmt.parseInt(usize, processes, 10);
        profile_step.dependOn(addProfiling(
            b,
            profiles_data_dir,
            "linreg",
            processes_number,
            linreg_runner_exe,
            &.{ linreg_fits, linreg_predicts_per_fit },
        ));
        profile_step.dependOn(addProfiling(
            b,
            profiles_data_dir,
            "search-name",
            processes_number,
            search_name_runner_exe,
            &.{search_name_repeats},
        ));
    }
}

fn addProfiling(
    b: *std.Build,
    profiles_data_dir: std.Build.LazyPath,
    profile_name: []const u8,
    processes: usize,
    runner: *std.Build.Step.Compile,
    runner_args: []const []const u8,
) *std.Build.Step {
    const profile_step = b.step(
        b.fmt("profile-{s}-{}", .{ profile_name, processes }),
        b.fmt("Profile {s} in {} processes", .{ profile_name, processes }),
    );

    const profile_dir = profiles_data_dir.path(b, profile_name).path(b, b.fmt("{}-processes", .{processes}));

    const cmd = b.addSystemCommand(&.{"profiling/profile_processes.sh"});
    cmd.addDirectoryArg(profile_dir);
    cmd.addArg(b.fmt("{}", .{processes}));
    cmd.addArtifactArg(runner);
    cmd.addArgs(runner_args);
    profile_step.dependOn(&cmd.step);

    return profile_step;
}
