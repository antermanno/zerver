const std = @import("std");
const Io = std.Io;
const net = Io.net;
const log = std.log;

const zerver = @import("zerver");

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

    // // Stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    // const stdout_writer = &stdout_file_writer.interface;
    //
    // try zerver.printAnotherMessage(stdout_writer);
    //
    // try stdout_writer.flush(); // Don't forget to flush!
    //

    // Try to start a socket
    const addr = try net.IpAddress.parseIp4("127.0.0.1", 10999);
    const sock = try addr.bind(io, .{ .mode = .dgram, .protocol = .udp });
    defer sock.close(io);

    // Create a buffer for the socket to write
    var buf: [1024]u8 = undefined;

    log.info("Socket listening on port {d}\n", .{addr.getPort()});

    // Let the socket receive the data, it blocks.
    // After receiving the data the program should close
    while (true) {
        const msg = try sock.receive(io, &buf);
        if (std.mem.eql(u8, msg.data, "close\n")) break;
        log.info(
            "received {d} byte(s) from {f};\n    string: {s}\n",
            .{ msg.data.len, msg.from, msg.data },
        );
    }
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
