const c = @import("c");
const std = @import("std");
const log = std.log;

// pub fn Database(comptime T: anytype) !type {
//     return struct {
const DB = @This();

name: []const u8,
connection: *c.sqlite3,
// make use of a tagged union

pub fn Table(comptime T: anytype) type {
    return struct {

        // Create the create table query at comptime
        const CREATE_TABLE = create_table: {

            // Name the table the same as the structure
            const CREATE_TABLE_IF_NOT = blk: {
                var name = @typeName(T);
                if (std.mem.findScalarLast(u8, name, '.')) |idx| {
                    const name_no_dots = name[idx + 1 .. :0];
                    const query = "CREATE TABLE IF NOT EXISTS " ++ name_no_dots;
                    break :blk query;
                }
                const query = "CREATE TABLE IF NOT EXISTS " ++ name;
                break :blk query;
            };

            // mapping zig types to sqltypes
            const TABLE_TYPES = blk: {
                var query: [:0]const u8 = "(";
                const foo_info = @typeInfo(T);
                for (foo_info.@"struct".fields) |value| {
                    const name = value.name;
                    const info = @typeInfo(value.type);

                    switch (info) {
                        .int => {
                            query = query ++ std.fmt.comptimePrint("{s} INTEGER ", .{name});
                        },
                        .pointer => {
                            query = query ++ std.fmt.comptimePrint("{s} VARCHAR ", .{name});
                        },
                        else => {},
                    }
                }
                break :blk query ++ "id PRIMARY KEY )";
            };

            break :create_table CREATE_TABLE_IF_NOT ++ TABLE_TYPES;
        };

        const Self = @This();
        pub fn init(db: DB) !Self {
            var stmt: ?*c.sqlite3_stmt = undefined;

            std.debug.print("{s}\n", .{CREATE_TABLE});
            var rc = c.sqlite3_prepare_v2(db.connection, CREATE_TABLE, CREATE_TABLE.len, @ptrCast(&stmt), 0);
            if (rc != c.SQLITE_OK) {
                const err = c.sqlite3_errmsg(db.connection);
                const errno = c.sqlite3_errcode(db.connection);
                log.err("Prepare Error: {s}({d})\n", .{ err, errno });
                return error.PrepareError;
            }
            defer rc = c.sqlite3_finalize(stmt);

            rc = c.sqlite3_step(stmt);
            if (rc == c.SQLITE_DONE) {
                // log.info("Table in: {any}\n", .{rc});
                const err = c.sqlite3_errmsg(db.connection);
                const errno = c.sqlite3_errcode(db.connection);
                log.info("Table Created with exit code: {s}({d})\n", .{ err, errno });
            }
            return .{};
        }
    };
}

pub fn init(db_name: []const u8) !DB {

    // sqlite3 *db;
    var db: ?*c.sqlite3 = undefined;
    var rc: c_int = undefined;

    rc = c.sqlite3_open(@ptrCast(db_name), @ptrCast(&db));
    // defer _ = c.sqlite3_close(db);
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
