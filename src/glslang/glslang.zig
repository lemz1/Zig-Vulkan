const std = @import("std");
const c = @cImport({
    @cInclude("glslang/Include/glslang_c_interface.h");
    @cInclude("glslang/Public/resource_limits_c.h");
});

const GLSLangError = error{
    InitializeProcess,
};

var initialized: bool = false;
pub const GLSLang = struct {
    pub fn init() !void {
        if (initialized) {
            return;
        }

        if (c.glslang_initialize_process() == 0) {
            return GLSLangError.InitializeProcess;
        }

        initialized = true;
    }

    pub fn deinit() void {
        if (!initialized) {
            return;
        }

        c.glslang_finalize_process();

        initialized = false;
    }

    pub fn wasInit() bool {
        return initialized;
    }
};
