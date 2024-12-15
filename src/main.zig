const std = @import("std");
const core = @import("core.zig");

const Application = core.Application;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    var app = try Application.new(.{ .allocator = gpa.allocator() });
    defer app.destroy();
    app.run();
}
