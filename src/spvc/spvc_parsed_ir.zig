const std = @import("std");
const spvc = @import("../spvc.zig");
const c = @cImport(@cInclude("spirv_cross_c.h"));

const SPVCContext = spvc.SPVCContext;

pub const SPVCParsedIR = struct {
    handle: c.spvc_parsed_ir,

    pub fn new(context: *const SPVCContext, spirvCode: [*c]const u32, spirvWords: usize) !SPVCParsedIR {
        var parsedIR: c.spvc_parsed_ir = undefined;
        switch (c.spvc_context_parse_spirv(context.handle, spirvCode, spirvWords, &parsedIR)) {
            c.SPVC_SUCCESS => {},
            else => {
                std.debug.print("[SPIRV-Cross] Could not create ParsedIR\n", .{});
                return error.CreateSPVCParsedIR;
            },
        }

        return .{
            .handle = parsedIR,
        };
    }
};
