const std = @import("std");
const Io = std.Io;
const net = Io.net;
const http = std.http;
const log = std.log;
// print function for debugging reasons
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    const io = init.io;

    // Try to start a server
    //
    // A SERVER has an address and contains a socket to listening to the outside word,
    // listening on the specified port.
    const addr = try net.IpAddress.parseIp4("0.0.0.0", 9999);

    var server = try addr.listen(io, .{ .reuse_address = true, .protocol = .tcp });
    defer server.deinit(io); // Release resources with the server
    defer server.socket.close(io); // Close the socket

    log.info("Now listening on port {}\n", .{addr.ip4.port});

    var g: Io.Group = .init;

    var q_buff: [10]net.Stream = undefined;
    var queue: Io.Queue(net.Stream) = .init(&q_buff);

    _ = try g.concurrent(io, producer, .{ io, &server, &queue });
    _ = try g.concurrent(io, consumer, .{ io, &queue });
    _ = try g.concurrent(io, consumer, .{ io, &queue });
    _ = try g.concurrent(io, consumer, .{ io, &queue });

    try g.await(io);
}

fn producer(io: Io, server: *net.Server, q: *Io.Queue(net.Stream)) error{Canceled}!void {

    // Accept a connection
    // A server blocks with the accept function,
    // i supposed till it receives some kind of request for a tcp connection
    // It contains a Socket object (a FILE DESCRIPTOR)
    // and a read-write interface to interact with the socket
    while (true) {
        const conn: net.Stream = server.accept(io) catch {
            continue;
        };
        // If it fails to put into queue close connection and break
        q.putOne(io, conn) catch {
            conn.close(io);
            continue;
        };
    }
}

// log.info("Oops! Someone connected, better to say HI\n", .{});
//
// // Do something with the connection
// // Concurrently
// _ = try io.concurrent(handler, .{ io, &queue });
fn consumer(io: Io, q: *Io.Queue(net.Stream)) error{Canceled}!void {
    while (true) {
        const conn = q.getOne(io) catch continue;
        // defer conn.close(io);

        handler(io, conn) catch {
            conn.close(io);
            continue;
        };
    }
}

fn handler(io: Io, conn: net.Stream) !void {
    // close the connection
    defer conn.close(io);

    // Here we access the reader and writer streaming
    var rbuf: [4 * 1024]u8 = undefined;
    var wbuf: [1024]u8 = undefined;

    // We pass the addresses of the buffers to coerce them into slices
    var reader = conn.reader(io, &rbuf);
    var writer = conn.writer(io, &wbuf);

    // Wrapper around the connection (just a reader and a writer)
    // It upgrade the reader to an HTTP READER interface.
    // That is just a reader with functionalities to parse http
    var server = http.Server.init(&reader.interface, &writer.interface);

    // Server loop
    while (server.reader.state == .ready) {
        // We handle the request for a specific conecction close connection if there are errors
        // A request has a pointer to the http server (a CONNECTION WITH HTTP reader methods)
        // The headers and other properties are parsed.
        // Maybe we can pass process the request elsewhere?
        // So that the connection doesn't get troubled?
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            error.HttpHeadersOversize => {
                log.warn("Headers too big", .{});
                return;
            },
            else => {
                log.warn("Error with the request: {any}\n", .{err});
                return;
            },
        };
        log.info("Responding to {s}\n", .{request.head_buffer});

        if (request.head.method != .GET and request.head.method != .POST) {
            // .extra_headers is a vector of headers that get's written into the
            // response (which contains the same headers as the request a presume
            request.respond("403", .{ .reason = "Unauthorized" }) catch break;
            break;
        }
        // for now we only authorize get method on the first two routes

        // let us switch on the path
        // Here a route is just an ENUM
        const Route = enum { home, static, htmx, content, invalid };

        // Possibly make it authomatic
        var API_ENDPOINT: Route = .invalid;

        if (std.mem.eql(u8, request.head.target, "/")) API_ENDPOINT = .home;
        if (std.mem.eql(u8, request.head.target, "/static")) API_ENDPOINT = .static;
        if (std.mem.eql(u8, request.head.target, "/htmx")) API_ENDPOINT = .htmx;
        if (std.mem.eql(u8, request.head.target, "/content")) API_ENDPOINT = .content;

        switch (API_ENDPOINT) {
            .home => request.respond("Bob", .{ .status = .ok, .extra_headers = &.{
                .{ .name = "Fake Header", .value = "Fake Value" },
            } }) catch |err| {
                log.warn("Error for the response: {any}\n", .{err});
                break;
            },
            .static => request.respond(HTML_STATIC, .{ .status = .ok, .extra_headers = &.{
                .{ .name = "Fake Header", .value = "Fake Value" },
            } }) catch |err| {
                log.warn("Error for the response: {any}\n", .{err});
                break;
            },
            .htmx => request.respond(HTMX, .{ .status = .ok, .extra_headers = &.{
                .{ .name = "Fake Header", .value = "Fake Value" },
            } }) catch |err| {
                log.warn("Error for the response: {any}\n", .{err});
                break;
            },
            .content => request.respond("U are my cutie! <3", .{ .status = .ok, .extra_headers = &.{
                .{ .name = "Fake Header", .value = "Fake Value" },
            } }) catch |err| {
                log.warn("Error for the response: {any}\n", .{err});
                break;
            },
            .invalid => {
                request.respond("404", .{ .reason = "Bad URI" }) catch break;
                break;
            },
        }
    }
}

test "simple test" {}

const HTML_TEMPLATE =
    \\ <html>
    \\ <title> My Cute Website </title>
    \\  <p><b>This is a serious Website</b></p>
    \\   <body>
    \\      Long long ago there was some text
    \\     <p><a href="/static">for my cutie</a></p>
    \\     <p><a href="/htmx">surprises</a></p>
    \\   </body>
    \\ </html>
;

const HTML_STATIC =
    \\ <html>
    \\ <title> My Cute Website </title>
    \\   <body>
    \\ <p>Hi Theeeeeeee!!!!!! <3<3<3<3<3<3<3<3</p>
    \\ <p>(^_^*)</p>
    \\     <p><a href="/">homepage</a></p>
    \\   </body>
    \\ </html>
;

const HTMX =
    \\  <script src="https://cdn.jsdelivr.net/npm/htmx.org@2.0.10/dist/htmx.min.js" crossorigin="anonymous"></script>
    \\ <div id="response-div"></div>
    \\  <!-- have a button POST a click via AJAX -->
    \\ <button hx-post="/content" hx-target="#response-div" hx-swap="innerHTML">
    \\ Click Me For A Surprise
    \\  </button>
;
