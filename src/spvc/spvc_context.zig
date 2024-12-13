const std = @import("std");
const c = @cImport(@cInclude("spirv_cross_c.h"));

const SPVCContextError = error{
    CreateSPVCContext,
};

pub const SPVCContext = struct {
    handle: c.spvc_context,

    pub fn new() !SPVCContext {
        var context: c.spvc_context = undefined;
        switch (c.spvc_context_create(&context)) {
            c.SPVC_SUCCESS => {},
            else => {
                std.debug.print("[SPIRV-Cross] Could not create Context\n", .{});
                return SPVCContextError.CreateSPVCContext;
            },
        }

        return .{
            .handle = context,
        };
    }

    pub fn destroy(self: *SPVCContext) void {
        c.spvc_context_destroy(self.handle);
    }

    pub fn release(self: *const SPVCContext) void {
        c.spvc_context_release_allocations(self.handle);
    }
};
