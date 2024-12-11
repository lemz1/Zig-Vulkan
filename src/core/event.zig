const std = @import("std");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const EventArgument = union(enum) {
    none,
    type: type,
};

pub fn Event(@"type": ?type) type {
    const Callback = if (@"type") |v| *const fn (v) void else *const fn () void;

    return if (@"type") |v| struct {
        callbacks: ArrayList(Callback),

        pub fn new(allocator: Allocator) @This() {
            return .{
                .callbacks = ArrayList(Callback).init(allocator),
            };
        }

        pub fn destroy(self: *@This()) void {
            self.callbacks.deinit();
        }

        pub fn dispatch(self: *const @This(), arg: v) void {
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
    } else struct {
        callbacks: ArrayList(Callback),

        pub fn new(allocator: Allocator) @This() {
            return .{
                .callbacks = ArrayList(Callback).init(allocator),
            };
        }

        pub fn destroy(self: *@This()) void {
            self.callbacks.deinit();
        }

        pub fn dispatch(self: *const @This()) void {
            for (self.callbacks.items) |callback| {
                callback();
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
