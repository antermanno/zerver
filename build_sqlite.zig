const std = @import("std");

pub fn buildLibSqlite(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    mod.addCSourceFiles(.{
        .root = b.path("src-c"),
        .files = &.{"sqlite3.c"},
    });

    const lib = b.addLibrary(.{
        .name = "sqlite3",
        .root_module = mod,
    });

    // Install the headers, so that linking this library makes those headers available.
    lib.installHeader(b.path("src-c/sqlite3.h"), "src-c/sqlite3.h");
    return lib;
}
