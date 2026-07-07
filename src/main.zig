const std = @import("std");
const Io = std.Io;
const net = Io.net;
const http = std.http;
const log = std.log;

const zerver = @import("zerver");
const Server = zerver.Server;
const DB = zerver.DB;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

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
    _ = try DB.Table(Bar).init(db);
    _ = try DB.Table(Trap).init(db);
    _ = try DB.Table(Flower).init(db);

    // Initialize Server
    const addr: net.IpAddress = .{ .ip4 = .loopback(8181) };
    var server: Server = .init(io, arena, addr, .empty, .{ .queue_size = 10 });
    try server.runServer();
}
