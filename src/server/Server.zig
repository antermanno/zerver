/// This is a server
const Server = @This();

const std = @import("std");
const Io = std.Io;
const net = std.Io.net;
const AcceptError = net.Server.AcceptError;
const Request = std.http.Server.Request;
const log = std.log;
const http = std.http;

// What does a basic server need?
address: net.IpAddress,
io: Io,
allocator: std.mem.Allocator,
options: ServerOptions,
/// The queue is nullable because it get's initialized later based on the options
queue: ?Io.Queue(net.Stream) = null,

/// init function, it takes an io, an allocator, an address and port + server options.
pub fn init(io: Io, alloc: std.mem.Allocator, addr: net.IpAddress, opt: ServerOptions) Server {
    return .{
        .io = io,
        .allocator = alloc,
        .address = addr,
        .options = opt,
    };
}

/// Server options, WIP
const ServerOptions = struct {
    is_local: Local = .loopback,
    queue_size: usize = 10,

    const Local = enum {
        loopback,
        unspecified,
        specified,
    };
};

/// TODO
pub fn deinit() void {}

/// Blocking call, it start running the server
pub fn runServer(self: *Server) !void {
    const addr = self.address;
    const io = self.io;

    // Bind and listen in the specified port
    var tcp_socket = try addr.listen(self.io, .{ .reuse_address = true, .protocol = .tcp });
    defer tcp_socket.deinit(self.io); // Release resources with the server
    // defer tcp_socket.socket.close(self.io); // Close the socket

    log.info("Now listening on http://{d}.{d}.{d}.{d}:{}\n", .{ addr.ip4.bytes[0], addr.ip4.bytes[1], addr.ip4.bytes[2], addr.ip4.bytes[3], addr.ip4.port });

    // initialize wait group
    var g: Io.Group = .init;
    defer g.cancel(self.io);

    //Allocate buffer on the heap???
    //let's try just to see how it looks
    const q_buf = try self.allocator.alloc(net.Stream, self.options.queue_size);
    defer self.allocator.free(q_buf);

    self.queue = .init(q_buf);
    var queue = self.queue.?;

    _ = try g.concurrent(io, producer, .{ io, &tcp_socket, &queue });
    // _ = try g.concurrent(io, consumer, .{ io, &queue });
    // _ = try g.concurrent(io, consumer, .{ io, &queue });
    // _ = try g.concurrent(io, consumer, .{ io, &queue });

    try g.await(self.io);
}

/// Receives connections
fn producer(io: Io, tcp_server: *net.Server, q: *Io.Queue(net.Stream)) error{Canceled}!void {

    // Accept a connection
    // A server blocks with the accept function,
    // i supposed till it receives some kind of request for a tcp connection
    // It contains a Socket object (a FILE DESCRIPTOR)
    // and a read-write interface to interact with the socket
    while (true) {
        var conn = tcp_server.accept(io) catch |err| switch (err) {
            net.Server.AcceptError.NetworkDown => {
                log.err("Network Down", .{});
                return error.Canceled;
            },
            else => continue,
        };

        // if we cannot put the connection to the queue close the connection and stop the loop
        // manage the canceling errors
        q.putOne(io, conn) catch {
            conn.close(io);
            break;
        };
    }
}

// routes: []Route,
// address: net.IpAddress,
// io: Io,
// allocator: std.mem.Allocator,
// queue: *std.Io.Queue(net.Stream),
//
// pub const Callback: type = *const fn (*Context) ServerError!void;
//
// pub const Context = struct {
//     connection: net.Stream,
//     request: Request,
//
//     pub fn init(conn: net.Stream, r: Request) !Context {
//         return .{ .connection = conn, .request = r };
//     }
// };
//
// pub const Route = struct {
//     path: []const u8,
//     method: Method,
//     handler: Callback,
//
//     const Method = enum {
//         GET,
//         POST,
//         UKNOWN,
//     };
// };
//
// pub const ServerError = error{
//     ConnectionError,
//     UnknownError,
// };
//
// pub fn init(io: Io, alloc: std.mem.Allocator, addr: net.IpAddress) !Server {
//     const buffer = try alloc.alloc(net.Stream, 10);
//     var queue = Io.Queue(net.Stream).init(buffer);
//     return .{ .address = addr, .io = io, .routes = &routes_hard_coded, .allocator = alloc, .queue = &queue };
// }
//
// // Let's hard code some routes
// var routes_hard_coded: [2]Route = .{
//     .{ .handler = defaultHandler, .method = .GET, .path = "/" },
//     .{ .handler = badHandler, .method = .GET, .path = "/hello" },
// };
//
// fn defaultHandler(c: *Context) ServerError!void {
//     c.request.respond("<b>Hello World<b>", .{ .status = .ok }) catch {};
// }
//
// fn badHandler(c: *Context) ServerError!void {
//     c.request.respond("<b>Hello non world<b>", .{ .status = .bad_request }) catch {};
// }
//
// pub fn listen(self: *Server, io: Io) !void {
//     var tcp_server = try self.address.listen(io, .{ .reuse_address = true, .protocol = .tcp });
//     defer tcp_server.deinit(io); // Release resources with the server
//     defer tcp_server.socket.close(io); // Close the socket
//
//     // initialize the queue
//
//     log.info("Now listening on port {d}\n", .{self.address.ip4.port});
//
//     while (true) {
//         // accept a connection
//         const conn = try tcp_server.accept(io);
//
//         // // Here we access the reader and writer streaming
//         // var rbuf: [4 * 1024]u8 = undefined;
//         // var wbuf: [1024]u8 = undefined;
//         //
//         // // We pass the addresses of the buffers to coerce them into slices
//         // var reader = conn.reader(io, &rbuf);
//         // var writer = conn.writer(io, &wbuf);
//         //
//         // var s = http.Server.init(&reader.interface, &writer.interface);
//         // try self.queue.put(self.allocator, &s);
//         try self.queue.putOne(io, conn);
//     }
// }
