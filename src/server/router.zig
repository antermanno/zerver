const std = @import("std");
const Server = @import("Server.zig");
const Callback = Server.Callback;
const Context = Server.Context;

const Router = @This();

pub const empty: Router = .{};
// /// Middleware Callbacks that act on all requests
// global_middleware: MiddlewareSet,
// routes: []Route,
//
// // pub fn add(r: *Router, route: Route, middle: MiddlewareSet) RoutingError!void {
// //
// // }
// pub const empty: Router = .{ .global_middleware = .{}, .routes = .{} };
//
// pub fn init(comptime routes: []Route) Router {
//     return .{ .routes = routes };
// }
// pub const Route = struct { path: []const u8, callback: Callback, middlewares: MiddlewareSet };
// pub const MiddlewareSet = []Callback;
//
// const RoutingError = error{Unexpected};
//
// pub fn run(r: *Router, ctx: *Context) !void {
//     for (r.routes) |routes| {
//         try routes.callback(ctx);
//     }
// }
