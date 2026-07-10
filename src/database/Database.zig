const c = @import("c");
const std = @import("std");
const log = std.log;

// pub fn Database(comptime T: anytype) !type {
//     return struct {
/// Database structure. Wrapper around sqlite3 db connection type.
const DB = @This();

name: []const u8,
connection: *c.sqlite3,
// make use of a tagged union

/// Creates a connection to the database with name db_name.
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

/// Closes the connection to the database.
pub fn deinit(db: *DB) void {
    _ = c.sqlite3_close(db.connection);
}

/// Creates a Table in the datbase with entries corresponding to the fields of struct.
pub fn Table(comptime T: anytype) type {
    return struct {
        const Self = @This();
        // Create the create table query at comptime
        const CREATE_TABLE = create_table: {

            // Name the table the same as the structure
            //

            const CREATE_TABLE_IF_NOT = blk: {
                const name = name: {
                    const name_t = @typeName(T);
                    if (std.mem.findScalarLast(u8, name_t, '.')) |idx| {
                        const name_no_dots = name_t[idx + 1 .. :0];
                        break :name name_no_dots;
                    }
                    break :name name_t;
                };
                break :blk "CREATE TABLE IF NOT EXISTS " ++ name;
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
                            query = query ++ std.fmt.comptimePrint("{s} INTEGER, ", .{name});
                        },
                        .pointer => {
                            query = query ++ std.fmt.comptimePrint("{s} TEXT, ", .{name});
                        },
                        else => {},
                    }
                }
                break :blk query ++ "id INTEGER PRIMARY KEY )";
            };

            break :create_table CREATE_TABLE_IF_NOT ++ TABLE_TYPES;
        };

        // break :insert "INSERT INTO table (column1,column2 ,..) VALUES( value1 value2 );";
        const INSERT_ELEMENT = insert: {
            const name = name: {
                const name_t = @typeName(T);
                if (std.mem.findScalarLast(u8, name_t, '.')) |idx| {
                    const name_no_dots = name_t[idx + 1 .. :0];
                    break :name name_no_dots;
                }
                break :name name_t;
            };

            // get the table name
            const insert = "INSERT INTO " ++ name;

            const types_names = blk: {
                var query: [:0]const u8 = " ( ";
                const foo_info = @typeInfo(T);
                for (foo_info.@"struct".fields) |value| {
                    const name_t = value.name;
                    query = query ++ std.fmt.comptimePrint("{s} ", .{name_t});
                }
                query = query ++ " ) VALUES ( ";

                for (foo_info.@"struct".fields, 0..) |_, i| {
                    query = query ++ std.fmt.comptimePrint(" ?{d} ,", .{i + 1});
                }
                break :blk query ++ " )";
            };
            // TODO: add the values in a sqlite parameter bind compatible notation
            break :insert insert ++ types_names;
        };

        /// Initialize the table and creates it into the database if it doesn't exist.
        pub fn init(db: *DB) !Self {
            // Wrapper around sqlite_prepare_statement
            std.debug.print("{s}\n", .{CREATE_TABLE});
            std.debug.print("{s}\n", .{INSERT_ELEMENT});
            var stmt: Statement = try .init(db, CREATE_TABLE);
            defer stmt.deinit();

            // Wrapper around sqlite step
            _ = try stmt.step(db);

            return .{};
        }

        // pub fn insert(db : DB , item : T)  {
        //     // INSERT_ELEMENT
        // }

    };
}

/// Wrapper around sqlite statements
const Statement = struct {
    stmt: ?*c.sqlite3_stmt = undefined,

    /// Returns a sqlite statement
    pub fn init(db: *DB, zSQL: [:0]const u8) !Statement {
        var stmt: ?*c.sqlite3_stmt = undefined;

        const rc = c.sqlite3_prepare_v2(db.connection, zSQL, @intCast(zSQL.len), @ptrCast(&stmt), 0);
        if (rc != c.SQLITE_OK) {
            db.logDatabase("Prepare Error: ");
            return error.PrepareError;
        }

        return .{ .stmt = stmt };
    }

    /// deallocates an sqlite statement
    pub fn deinit(stmt: *Statement) void {
        defer _ = c.sqlite3_finalize(stmt.stmt);
    }

    const StepStatus = enum(u64) {
        default,
        done = c.SQLITE_DONE,
        row = c.SQLITE_ROW,
    };

    /// wrapper around sqlite3_step
    pub fn step(stmt: *Statement, db: *DB) !StepStatus {
        const rc = c.sqlite3_step(stmt.stmt);
        switch (rc) {
            c.SQLITE_DONE => {
                db.logDatabase("Table created with exist code");
                return .done;
            },
            c.SQLITE_MISUSE => {
                return error.SqliteMisuse;
            },
            c.SQLITE_ROW => {
                return .row;
            },
            else => return error.UnimplementedError,
        }
    }

    // pub fn bind(stmt: *Statement, idx : usize) !void {
    //
    // }
};

pub fn logDatabase(db: DB, comptime log_msg: []const u8) void {
    const err = c.sqlite3_errmsg(db.connection);
    const errno = c.sqlite3_errcode(db.connection);
    log.info("{s}\nErrMsg:{s}({d})\n", .{ log_msg, err, errno });
}

// int (*callback)(void*,int,char**,char**),  /* Callback function */
//   void *,                                    /* 1st argument to callback */
// pub fn exec(db: *DB, sql_statement : [:0]const u8, callback : *const fn callback() ())  {}
