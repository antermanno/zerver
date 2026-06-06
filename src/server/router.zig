const std = @import("std");
const Server = @import("Server.zig");
const Callback = Server.Callback;
const Context = Server.Context;

const Router = @This();

/// Middleware Callbacks that act on all requests
global_middleware: MiddlewareSet,
routes: []Route,

pub fn add(r: *Router, route: Route, middle: MiddlewareSet) RoutingError!void {}

pub const Route = struct { path: []const u8, callback: Callback };
pub const MiddlewareSet = []Callback;

const RoutingError = error{Unexpected};
