const std = @import("std");
const glslang = @import("../glslang.zig");
const c = @cImport(@cInclude("glslang/Include/glslang_c_interface.h"));

const GLSLang = glslang.GLSLang;
const GLSLangShader = glslang.GLSLangShader;
const GLSLangShaderStage = glslang.GLSLangShaderStage;

pub const GLSLangProgram = struct {
    handle: *c.glslang_program_t,

    pub fn new(shader: *const GLSLangShader, stage: GLSLangShaderStage) !GLSLangProgram {
        const program = c.glslang_program_create() orelse return error.CreateProgram;
        c.glslang_program_add_shader(program, @ptrCast(shader.handle));

        if (c.glslang_program_link(program, c.GLSLANG_MSG_DEFAULT_BIT) == 0) {
            return error.LinkProgram;
        }

        c.glslang_program_SPIRV_generate(program, @intFromEnum(stage));

        if (c.glslang_program_SPIRV_get_messages(program) != null) {
            std.debug.print("[GLSLang] Could not compile shader: {s}\n", .{c.glslang_program_SPIRV_get_messages(program)});
            return error.GenerateSPIRV;
        }

        return .{
            .handle = program,
        };
    }

    pub fn getSPIRVSize(self: *const GLSLangProgram) usize {
        return c.glslang_program_SPIRV_get_size(self.handle);
    }

    pub fn getSPIRVPtr(self: *const GLSLangProgram) [*c]c_uint {
        return c.glslang_program_SPIRV_get_ptr(self.handle);
    }

    pub fn destroy(self: *GLSLangProgram) void {
        c.glslang_program_delete(self.handle);
    }
};
