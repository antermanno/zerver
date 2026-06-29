const std = @import("std");
const buildSQL = @import("build_sqlite.zig").buildLibSqlite;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("src-c/sqlite3.h"),
        .target = target,
        .optimize = optimize,
    });

    const zql = b.addModule("zql", .{
        .root_source_file = b.path("src/database/Database.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "c", .module = translate_c.createModule() },
        },
    });

    const mod = b.addModule("zerver", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,

        .imports = &.{
            .{ .name = "zql", .module = zql },
            .{ .name = "c", .module = translate_c.createModule() },
        },
    });

    const sqlite_lib = buildSQL(b, target, optimize);

    b.installArtifact(sqlite_lib);

    const exe = b.addExecutable(.{
        .name = "zerver",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zerver", .module = mod },
            },
        }),
    });
    exe.root_module.linkLibrary(sqlite_lib);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
}
