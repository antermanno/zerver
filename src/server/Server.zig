/// This is a server
const Server = @This();

const std = @import("std");
const Io = std.Io;
const net = std.Io.net;
const Request = std.http.Server.Request;
const log = std.log;
const http = std.http;

routes: []Route,
address: net.IpAddress,
io: Io,
allocator: std.mem.Allocator,
queue: *std.Io.Queue(net.Stream),

pub const Callback: type = *const fn (*Context) ServerError!void;

pub const Context = struct {
    connection: net.Stream,
    request: Request,

    pub fn init(conn: net.Stream, r: Request) !Context {
        return .{ .connection = conn, .request = r };
    }
};

pub const Route = struct {
    path: []const u8,
    method: Method,
    handler: Callback,

    const Method = enum {
        GET,
        POST,
        UKNOWN,
    };
};

pub const ServerError = error{
    ConnectionError,
    UnknownError,
};

pub fn init(io: Io, alloc: std.mem.Allocator, addr: net.IpAddress) !Server {
    const buffer = try alloc.alloc(net.Stream, 10);
    var queue = Io.Queue(net.Stream).init(buffer);
    return .{ .address = addr, .io = io, .routes = &routes_hard_coded, .allocator = alloc, .queue = &queue };
}

// Let's hard code some routes
var routes_hard_coded: [2]Route = .{
    .{ .handler = defaultHandler, .method = .GET, .path = "/" },
    .{ .handler = badHandler, .method = .GET, .path = "/hello" },
};

fn defaultHandler(c: *Context) ServerError!void {
    c.request.respond("<b>Hello World<b>", .{ .status = .ok }) catch {};
}

fn badHandler(c: *Context) ServerError!void {
    c.request.respond("<b>Hello non world<b>", .{ .status = .bad_request }) catch {};
}

pub fn listen(self: *Server, io: Io) !void {
    var tcp_server = try self.address.listen(io, .{ .reuse_address = true, .protocol = .tcp });
    defer tcp_server.deinit(io); // Release resources with the server
    defer tcp_server.socket.close(io); // Close the socket

    // initialize the queue

    log.info("Now listening on port {d}\n", .{self.address.ip4.port});

    while (true) {
        // accept a connection
        const conn = try tcp_server.accept(io);

        // // Here we access the reader and writer streaming
        // var rbuf: [4 * 1024]u8 = undefined;
        // var wbuf: [1024]u8 = undefined;
        //
        // // We pass the addresses of the buffers to coerce them into slices
        // var reader = conn.reader(io, &rbuf);
        // var writer = conn.writer(io, &wbuf);
        //
        // var s = http.Server.init(&reader.interface, &writer.interface);
        // try self.queue.put(self.allocator, &s);
        try self.queue.putOne(io, conn);
    }
}
