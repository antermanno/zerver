const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const net = Io.net;
const http = std.http;
const log = std.log;

const zerver = @import("zerver");
const Server = zerver.Server;
const DB = zerver.DB;
const zio = @import("zio");

pub fn main(init: std.process.Init) !void {
    std.debug.print("Arch is {any}\n", .{builtin.target});
    const rt = try zio.Runtime.init(init.gpa, .{});
    defer rt.deinit();
    const io = rt.io();
    // const io = init.io;
    // const arena = init.arena.allocator();

    // Initialize db
    var db: DB = try .init("garden.db");
    defer db.deinit();

    const Bar = struct {
        phone: u8,
        tomatoes_pizza: u8,
        pasta_dish: u8,
        name: []const u8,
    };

    const Trap = struct {
        name: []const u8,
        crime: i64,
    };

    const Flower = struct {
        petals: u8,
        sepal: []const u8,
    };
    _ = try DB.Table(Bar).init(&db);
    var trap: DB.Table(Trap) = try .init(&db);
    var flower: DB.Table(Flower) = try .init(&db);

    try trap.insert(.{
        .name = "Stanberg",
        .crime = -1,
    });

    const flowers = &[_]Flower{
        .{ .petals = 3, .sepal = "nice sepal" },
        .{ .petals = 4, .sepal = "not nice sepal" },
        .{ .petals = 6, .sepal = "test" },
        .{ .petals = 7, .sepal = "mysterious" },
        .{ .petals = 3, .sepal = "candle" },
    };
    for (flowers) |f| {
        try flower.insert(f);
    }

    // Initialize Server
    const addr: net.IpAddress = .{ .ip4 = .loopback(8181) };
    var server: Server = .init(io, init.gpa, addr, .empty, .{ .queue_size = 10 });
    try server.runServer();
}
