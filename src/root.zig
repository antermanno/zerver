//! By convention, root.zig is the root source file when making a package.
const std = @import("std");
pub const Server = @import("server/Server.zig");
const Io = std.Io;

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
