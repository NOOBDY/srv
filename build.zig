const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const srv_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cli_mod = b.createModule(.{
        .root_source_file = b.path("src/client.zig"),
        .target = target,
        .optimize = optimize,
    });

    const srv = b.addExecutable(.{
        .name = "srv",
        .root_module = srv_mod,
    });

    const cli = b.addExecutable(.{
        .name = "cli",
        .root_module = cli_mod,
    });

    b.installArtifact(srv);
    b.installArtifact(cli);

    const run_srv_cmd = b.addRunArtifact(srv);
    run_srv_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_srv_cmd.addArgs(args);
    }

    const run_srv_step = b.step("srv", "Run the server");
    run_srv_step.dependOn(&run_srv_cmd.step);

    const run_cli_cmd = b.addRunArtifact(cli);
    run_cli_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cli_cmd.addArgs(args);
    }

    const run_cli_step = b.step("cli", "Run the server");
    run_cli_step.dependOn(&run_cli_cmd.step);
}
