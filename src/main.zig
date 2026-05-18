const std = @import("std");
const Io = std.Io;
const net = Io.net;
const http = std.http;
const log = std.log;

const zerver = @import("zerver");

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

// print function for debugging reasons
const print = std.debug.print;

pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    print("All your {s} are belong to us.\n", .{"codebase"});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    // Try to start a server
    const addr = try net.IpAddress.parseIp4("0.0.0.0", 9999);

    var server = try addr.listen(io, .{ .reuse_address = true, .protocol = .tcp });
    defer server.deinit(io); // Release resources with the server
    defer server.socket.close(io); // Close the socket

    print("This is a {any} and it looks like this: {any}\n", .{ @TypeOf(server), server });

    log.info("Now listening on port {}\n", .{addr.ip4.port});

    // Main loop
    while (true) {

        // Accept a connection
        const conn: net.Stream = try server.accept(io);
        // defer conn.close(io);

        log.info("Oops! Someone connected, better to say HI\n", .{});

        // Do something with the connection
        // Concurrently
        _ = try io.concurrent(handler, .{ io, conn });
    }
}

fn handler(io: Io, conn: net.Stream) !void {

    // close the connection
    defer conn.close(io);

    // Start the server with the appropriate reader and writer
    //
    // I suppose a server is an API on top of a Stream (which is indeed a "tcp-like" socket
    // that provides reader and writer interfaces
    var rbuf: [4 * 1024]u8 = undefined;
    var wbuf: [1024]u8 = undefined;

    // We pass the addresses of the buffers to coerce them into slices
    var reader = conn.reader(io, &rbuf);
    var writer = conn.writer(io, &wbuf);

    var server = http.Server.init(&reader.interface, &writer.interface);

    // Server loop
    while (server.reader.state == .ready) {
        // We handle the request for a specific conecction close connection if there are errors
        var request = server.receiveHead() catch |err| switch (err) {
            error.HttpConnectionClosing => return,
            error.HttpHeadersOversize => {
                log.warn("Headers too big", .{});
                return;
            },
            else => {
                log.warn("Error with the request: {any}\n", .{err});
                return err;
            },
        };
        log.info("Responding to {any}\n", .{request.head.method});
        log.info("Responding to {s}\n", .{request.head.target});

        if (request.head.method != .GET and request.head.method != .POST) {
            request.respond("403", .{ .reason = "Unauthorized" }) catch break;
            break;
        }
        // for now we only authorize get method on the first two routes

        // let us switch on the path
        const Route = enum { home, static, htmx, content, invalid };

        // Possibly make it authomatic
        var API_ENDPOINT: Route = .invalid;

        if (std.mem.eql(u8, request.head.target, "/")) API_ENDPOINT = .home;
        if (std.mem.eql(u8, request.head.target, "/static")) API_ENDPOINT = .static;
        if (std.mem.eql(u8, request.head.target, "/htmx")) API_ENDPOINT = .htmx;
        if (std.mem.eql(u8, request.head.target, "/content")) API_ENDPOINT = .content;

        switch (API_ENDPOINT) {
            .home => request.respond(HTML_TEMPLATE, .{ .status = .ok, .extra_headers = &.{
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
