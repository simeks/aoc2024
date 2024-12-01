const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const days = .{
        "day1",
    };

    inline for (days) |day| {
        const day_exe = b.addExecutable(.{
            .name = day,
            .root_source_file = b.path("src/" ++ day ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });

        const day_test = b.addTest(.{
            .root_source_file = b.path("src/" ++ day ++ ".zig"),
            .target = target,
            .optimize = optimize,
        });

        const run_cmd = b.addRunArtifact(day_exe);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run_" ++ day, "Run " ++ day);
        run_step.dependOn(&run_cmd.step);

        const test_cmd = b.addRunArtifact(day_test);

        const test_step = b.step("test_" ++ day, "Test " ++ day);
        test_step.dependOn(&test_cmd.step);
    }
}
