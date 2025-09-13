const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "UnityCNBurst",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    const build_all_step = b.step("build-all", "Build for all target platforms");

    const cross_targets = [_]std.Target.Query{
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
        .{ .cpu_arch = .x86, .os_tag = .windows },
        .{ .cpu_arch = .aarch64, .os_tag = .windows },

        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .macos },

        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .x86, .os_tag = .linux },
        .{ .cpu_arch = .arm, .os_tag = .linux },
    };

    for (cross_targets) |cross_target| {
        const exe_name = b.fmt("UnityCNBurst-{s}-{s}", .{
            @tagName(cross_target.os_tag orelse .windows),
            @tagName(cross_target.cpu_arch orelse .x86_64),
        });

        const exe_opt = b.addExecutable(.{
            .name = exe_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = b.resolveTargetQuery(.{
                    .cpu_arch = cross_target.cpu_arch,
                    .os_tag = cross_target.os_tag,
                }),
                .optimize = .ReleaseFast,
            }),
        });

        const install_step = b.addInstallArtifact(exe_opt, .{});

        build_all_step.dependOn(&install_step.step);
    }
}
