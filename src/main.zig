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
    var db: DB = try .init("zerver.db");
    defer db.deinit();

    // Initialize Server
    const addr: net.IpAddress = .{ .ip4 = .loopback(8181) };
    var server: Server = .init(io, arena, addr, .empty, .{ .queue_size = 10 });
    try server.runServer();
}
