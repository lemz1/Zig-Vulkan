const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub fn Event(comptime T: type) type {
    const Callback = *const fn (T) void;

    return struct {
        callbacks: ArrayList(Callback),

        pub fn new(allocator: Allocator) @This() {
            return .{
                .callbacks = ArrayList(Callback).init(allocator),
            };
        }

        pub fn destroy(self: *@This()) void {
            self.callbacks.deinit();
        }

        pub fn dispatch(self: *const @This(), arg: T) void {
            for (self.callbacks.items) |callback| {
                callback(arg);
            }
        }

        pub fn add(self: *@This(), callback: Callback) !void {
            try self.callbacks.append(callback);
        }

        pub fn remove(self: *@This(), callback: Callback) bool {
            const index = blk: {
                for (0..self.callbacks.items.len) |i| {
                    if (self.callbacks.items[i] == callback) {
                        break :blk i;
                    }
                }

                break :blk null;
            } orelse return false;

            _ = self.callbacks.orderedRemove(index);
            return true;
        }

        pub fn clear(self: *@This()) void {
            self.callbacks.clearAndFree();
        }
    };
}
