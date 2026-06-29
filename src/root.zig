//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
pub const Server = @import("server/Server.zig");
pub const DB = @import("database/Database.zig");
