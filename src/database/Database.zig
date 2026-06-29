const c = @import("c");
const std = @import("std");
const log = std.log;

const DB = @This();

name: []const u8,
connection: *c.sqlite3,

pub fn init(db_name: []const u8) !DB {

    // sqlite3 *db;
    var db: ?*c.sqlite3 = undefined;
    var rc: c_int = undefined;

    rc = c.sqlite3_open(@ptrCast(db_name), @ptrCast(&db));
    defer _ = c.sqlite3_close(db);
    if (rc != c.SQLITE_OK) {
        log.err("Can't open database: {d}\n", .{c.sqlite3_errcode(db)});
        return error.OpenDatabaseError;
    }

    return .{
        .name = db_name,
        .connection = db.?,
    };
}

pub fn deinit(db: *DB) void {
    _ = c.sqlite3_close(db.connection);
}

// Design the database schema for zerver
