const std = @import("std");
const spvc = @import("../spvc.zig");
const c = @cImport(@cInclude("spirv_cross_c.h"));

const SPVCContext = spvc.SPVCContext;
const SPVCParsedIR = spvc.SPVCParsedIR;

const SPVCCompilerError = error{
    CreateSPVCCompiler,
};

pub const SPVCCompiler = struct {
    handle: c.spvc_compiler,

    pub fn new(context: *const SPVCContext, parsedIR: *const SPVCParsedIR) !SPVCCompiler {
        var compiler: c.spvc_compiler = undefined;
        switch (c.spvc_context_create_compiler(context.handle, c.SPVC_BACKEND_NONE, parsedIR.handle, c.SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &compiler)) {
            c.SPVC_SUCCESS => {},
            else => {
                std.debug.print("[SPIRV-Cross] Could not create Compiler\n", .{});
                return SPVCCompilerError.CreateSPVCCompiler;
            },
        }

        return .{
            .handle = compiler,
        };
    }
};
