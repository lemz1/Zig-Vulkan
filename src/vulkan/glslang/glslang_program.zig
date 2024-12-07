const std = @import("std");
const glslang = @import("glslang.zig");
const c = @cImport(@cInclude("glslang/Include/glslang_c_interface.h"));

const GLSLangShader = @import("glslang_shader.zig").GLSLangShader;
const GLSLangShaderStage = @import("glslang_shader.zig").GLSLangShaderStage;

const GLSLangProgramError = error{
    CreateProgram,
    LinkProgram,
    GenerateSPIRV,
};

pub const GLSLangProgram = struct {
    handle: *c.glslang_program_t,

    pub fn new(shader: *const GLSLangShader, stage: GLSLangShaderStage) !GLSLangProgram {
        const program = glslang.programCreate() orelse return GLSLangProgramError.CreateProgram;
        glslang.programAddShader(program, @ptrCast(shader.handle));

        if (!glslang.programLink(program)) {
            return GLSLangProgramError.LinkProgram;
        }

        glslang.programSPIRVGenerate(program, @intFromEnum(stage));

        if (glslang.programSPIRVGetMessages(program) != null) {
            std.debug.print("[GLSLang] Could not compile shader: {s}\n", .{glslang.programSPIRVGetMessages(program)});
            return GLSLangProgramError.GenerateSPIRV;
        }

        return .{
            .handle = @ptrCast(program),
        };
    }

    pub fn getSPIRVSize(self: *const GLSLangProgram) usize {
        return glslang.programSPIRVGetSize(@ptrCast(self.handle));
    }

    pub fn getSPIRVPtr(self: *const GLSLangProgram) [*c]u32 {
        return glslang.programSPIRVGetPtr(@ptrCast(self.handle));
    }

    pub fn destroy(self: *GLSLangProgram) void {
        glslang.programDelete(@ptrCast(self.handle));
    }
};
