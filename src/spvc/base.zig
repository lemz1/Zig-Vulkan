const std = @import("std");
const c = @cImport(@cInclude("spirv_cross_c.h"));

pub fn spvcCheck(res: c.spvc_result) void {
    switch (res) {
        c.SPVC_SUCCESS => {},
        else => {
            std.debug.print("[SPIRV-Cross] Error: {}", .{res});
        },
    }
}
