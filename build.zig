const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const run_shell_step = b.step("run-shell", "Run the shell");
    {
        const shell_exe = b.addExecutable(.{
            .name = "shell",
            .root_source_file = b.path("shell/shell.zig"),
            .target = target,
            .optimize = optimize,
        });
        b.installArtifact(shell_exe);

        const run_shell = b.addRunArtifact(shell_exe);
        if (b.args) |args| run_shell.addArgs(args);
        run_shell_step.dependOn(&run_shell.step);
    }

    const test_step = b.step("test", "Run unit tests");
    {
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
    }

    try addProfiling(b, target);
}

fn addProfiling(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
) !void {
    const profiling_step = b.step("profile", "Profile all algorithms");

    const runners_option = b.option(usize, "runners", "Number of runners to use for profiling") orelse 4;
    const fits_option = b.option([]const u8, "fits", "Number of fits to run for linreg profiling") orelse "10000000";
    const predicts_option = b.option([]const u8, "predicts", "Number of predicts per fit for linreg profiling") orelse "100";
    const search_repeats_options = b.option([]const u8, "search_repeats", "Number of search repeats for search-name profiling") orelse "1000";

    const profiling_data_dir = b.path("profiling/data-release");

    const profile_linreg_step = b.step("profile-linreg", "Profile linreg");
    profiling_step.dependOn(profile_linreg_step);
    {
        const linreg_runner_exe = b.addExecutable(.{
            .name = "linreg_runner",
            .root_source_file = b.path("profiling/linreg_runner.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        });
        linreg_runner_exe.root_module.addImport("linreg", b.createModule(.{
            .root_source_file = b.path("algorithms/linreg.zig"),
        }));
        b.installArtifact(linreg_runner_exe);

        const linreg_profiling_data_dir = profiling_data_dir.path(b, "linreg");
        const mk_profiling_data_dir_cmd = b.addSystemCommand(&.{ "mkdir", "-p" });
        mk_profiling_data_dir_cmd.addDirectoryArg(linreg_profiling_data_dir);
        profile_linreg_step.dependOn(&mk_profiling_data_dir_cmd.step);

        const runners_arg = try std.fmt.allocPrint(b.allocator, "{}", .{runners_option});
        const profile_linreg_cmd = b.addSystemCommand(&.{"profiling/profile_many.sh"});
        profile_linreg_cmd.addDirectoryArg(linreg_profiling_data_dir.path(b, runners_arg));
        profile_linreg_cmd.addArg(runners_arg);
        profile_linreg_cmd.addArtifactArg(linreg_runner_exe);
        profile_linreg_cmd.addArg(fits_option); // fits
        profile_linreg_cmd.addArg(predicts_option); // predicts per fit
        profile_linreg_step.dependOn(&profile_linreg_cmd.step);
    }

    const profile_search_name_step = b.step("profile-search-name", "Profile search-name");
    profiling_step.dependOn(profile_search_name_step);
    {
        const search_name_runner_exe = b.addExecutable(.{
            .name = "search_name_runner",
            .root_source_file = b.path("profiling/search_name_runner.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        });
        search_name_runner_exe.root_module.addImport("search_name", b.createModule(.{
            .root_source_file = b.path("algorithms/search_name.zig"),
        }));
        b.installArtifact(search_name_runner_exe);

        const search_name_profiling_data_dir = profiling_data_dir.path(b, "search_name");
        const mk_profiling_data_dir_cmd = b.addSystemCommand(&.{ "mkdir", "-p" });
        mk_profiling_data_dir_cmd.addDirectoryArg(search_name_profiling_data_dir);
        profile_search_name_step.dependOn(&mk_profiling_data_dir_cmd.step);

        const runners_arg = try std.fmt.allocPrint(b.allocator, "{}", .{runners_option});
        const profile_search_name_cmd = b.addSystemCommand(&.{"profiling/profile_many.sh"});
        profile_search_name_cmd.addDirectoryArg(search_name_profiling_data_dir.path(b, runners_arg));
        profile_search_name_cmd.addArg(runners_arg);
        profile_search_name_cmd.addArtifactArg(search_name_runner_exe);
        profile_search_name_cmd.addArg(search_repeats_options); // repeats
        profile_search_name_step.dependOn(&profile_search_name_cmd.step);
    }

    const profile_combined_step = b.step("profile-combined", "Profile both algorithms");
    profiling_step.dependOn(profile_combined_step);
    {
        const combined_runner_exe = b.addExecutable(.{
            .name = "combined_runner",
            .root_source_file = b.path("profiling/combined_runner.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        });
        combined_runner_exe.root_module.addImport("linreg", b.createModule(.{
            .root_source_file = b.path("algorithms/linreg.zig"),
        }));
        combined_runner_exe.root_module.addImport("search_name", b.createModule(.{
            .root_source_file = b.path("algorithms/search_name.zig"),
        }));
        b.installArtifact(combined_runner_exe);

        const combined_profiling_data_dir = profiling_data_dir.path(b, "combined");
        const mk_profiling_data_dir_cmd = b.addSystemCommand(&.{ "mkdir", "-p" });
        mk_profiling_data_dir_cmd.addDirectoryArg(combined_profiling_data_dir);
        profile_combined_step.dependOn(&mk_profiling_data_dir_cmd.step);

        const runners_arg = try std.fmt.allocPrint(b.allocator, "{}", .{runners_option});
        const profile_combined_cmd = b.addSystemCommand(&.{"profiling/profile_many.sh"});
        profile_combined_cmd.addDirectoryArg(combined_profiling_data_dir.path(b, runners_arg));
        profile_combined_cmd.addArg(runners_arg);
        profile_combined_cmd.addArtifactArg(combined_runner_exe);
        profile_combined_cmd.addArg(fits_option); // fits
        profile_combined_cmd.addArg(predicts_option); // predicts per fit
        profile_combined_cmd.addArg(search_repeats_options); // search-repeats
        profile_combined_step.dependOn(&profile_combined_cmd.step);
    }
}
