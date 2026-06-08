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
    n_workers: usize = 10,

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

    for (0..self.options.n_workers) |_| {
        _ = try g.concurrent(io, consumer, .{ io, &queue });
    }
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

        // TODO: Connection timeout logic

        // if we cannot put the connection to the queue close the connection and stop the loop
        // manage the canceling errors
        q.putOne(io, conn) catch {
            conn.close(io);
            break;
        };
    }
}

// each worker assign buffer to be used by the internal handler in its stack
fn consumer(io: Io, q: *Io.Queue(net.Stream)) error{Canceled}!void {

    // Reader and Writer buffer to pass to the http handler
    // Maybe make their size an option
    var rbuf: [4 * 1024]u8 = undefined;
    var wbuf: [4 * 1024]u8 = undefined;
    while (true) {
        // DO something with queue cancelation errors
        const conn = q.getOne(io) catch continue;
        // defer conn.close(io);

        handler(io, conn, &rbuf, &wbuf) catch {
            conn.close(io);
            continue;
        };
    }
}

fn handler(io: Io, conn: net.Stream, rbuf: []u8, wbuf: []u8) !void {
    // close the connection after handling. The whole server will block when all threads are busy.
    // find a way to make it more "fiber like" and yield a connection
    defer conn.close(io);
    //
    // Make an allocator, maybe make it passable around
    const gpa: std.mem.Allocator = std.heap.page_allocator;

    // We pass the addresses of the buffers to coerce them into slices
    var reader = conn.reader(io, rbuf);
    var writer = conn.writer(io, wbuf);

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
        log.debug("Responding to {s}\n", .{request.head_buffer});

        var ctx: Context = .{ .allocator = gpa, .io = io, .request = &request };
        // serve a static file
        try static_server(&ctx);

        // const html_headers = [_]http.Header{
        //     // .{ .name = "Cache-Control", .value = "public, max-age=3600" },
        //     .{ .name = "Content-Type", .value = "text/html" },
        // };

        // Make a static file server, first single file, later by sub dir
        // Use the router to match queries and patterns

        //TODO: something along the line of
        // router.process(request);

        // try request.respond(HTML_STATIC, .{ .keep_alive = true, .status = .ok, .extra_headers = &html_headers });
        // try request.respond(CSS, .{ .keep_alive = true, .status = .ok, .extra_headers = &css_headers });
    }
}

pub fn static_server(ctx: *Context) ServerError!void {
    const io = ctx.io;
    // read from file
    //
    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    // const stdout = &stdout_writer.interface;

    var rbuf: [1024 * 4]u8 = undefined;
    var index = std.Io.Dir.cwd().openFile(ctx.io, "index.html", .{ .mode = .read_only }) catch return ServerError.Unexpected;
    defer index.close(io);
    // TODO: the directory handle is not found by the executable?
    // create a reader buffer
    // dump all the content in the body
    var file_reader = index.reader(io, &rbuf);
    const freader_inteface = &file_reader.interface;

    // get file lenght to allocate enough bytes
    const file_length = index.length(io) catch return ServerError.Unexpected;

    // alloc a buffer to return as body
    const body = ctx.allocator.alloc(u8, file_length) catch return ServerError.Unexpected;
    defer ctx.allocator.free(body);

    freader_inteface.readSliceAll(body) catch return ServerError.Unexpected;

    ctx.request.respond(body, .{ .keep_alive = true, .status = .ok }) catch return ServerError.Unexpected;
}

const ServerError = error{Unexpected};

pub const Callback: type = *const fn (*Context) ServerError!void;

/// For the moment the context is the same as a simple request, add elements to this api if needed
pub const Context = struct { request: *Request, io: Io, allocator: std.mem.Allocator };
// pub const Context = struct {
//     connection: net.Stream,
//     request: Request,
//
//     pub fn init(conn: net.Stream, r: Request) !Context {
//         return .{ .connection = conn, .request = r };
//     }
// };

const HTML_STATIC =
    \\ <html>
    \\ <head>    
    \\     <link href="https://cdnjs.cloudflare.com/ajax/libs/tailwindcss/2.0.2/tailwind.min.css" rel="stylesheet">
    \\     <script src="https://cdn.tailwindcss.com"></script>
    \\ </head>
    \\ <title> My Cute Website </title>
    \\   <body>
    \\ <div class="bg-blue-500 text-white text-center">
    \\ <p >Hi Theeeeeeee!!!!!! <3<3<3<3<3<3<3<3</p>
    \\ <p class="border-purple-200 text-purple-600 hover:border-transparent hover:bg-purple-600 hover:text-white active:bg-purple-700">(^_^*)</p>
    \\ </div>
    \\     <p><a href="/">homepage</a></p>
    \\   </body>
    \\ </html>
;
