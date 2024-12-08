const std = @import("std");

const core = @import("core.zig");
const Application = core.Application;

fn SharedAsset(comptime T: type) type {
    return struct {
        refCount: usize = 1,
        asset: T,
        destroy: *const fn (*T) void,

        pub fn new(asset: T, destroy: *const fn (*T) void) @This() {
            return .{
                .asset = asset,
                .destroy = destroy,
            };
        }

        pub fn release(self: *@This()) void {
            self.refCount -= 1;
            if (self.refCount == 0) {
                self.destroy(&self.asset);
            }
        }
    };
}

const TestStruct = struct {
    pub fn destroy(_: *TestStruct) void {
        std.debug.print("DESTROYED\n", .{});
    }
};

pub fn main() !void {
    const t = TestStruct{};
    var lol = SharedAsset(TestStruct).new(t, &TestStruct.destroy);
    lol.release();

    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    var app = try Application.new(.{ .allocator = gpa.allocator() });
    defer app.destroy();
    app.run();
}
