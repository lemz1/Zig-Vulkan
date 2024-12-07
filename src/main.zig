const std = @import("std");

const core = @import("core.zig");
const Application = core.Application;

const glslang = @import("vulkan/glslang/glslang.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    try glslang.load();
    defer glslang.unload();

    var app = try Application.new(.{ .allocator = gpa.allocator() });
    defer app.destroy();
    app.run();
}
