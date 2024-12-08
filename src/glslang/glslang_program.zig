const std = @import("std");
const glslang = @import("../glslang.zig");
const c = @cImport(@cInclude("glslang/Include/glslang_c_interface.h"));

const GLSLang = glslang.GLSLang;
const GLSLangShader = glslang.GLSLangShader;
const GLSLangShaderStage = glslang.GLSLangShaderStage;

const GLSLangProgramError = error{
    CreateProgram,
    LinkProgram,
    GenerateSPIRV,
};

pub const GLSLangProgram = struct {
    handle: *c.glslang_program_t,

    pub fn new(shader: *const GLSLangShader, stage: GLSLangShaderStage) !GLSLangProgram {
        const program = GLSLang.programCreate() orelse return GLSLangProgramError.CreateProgram;
        GLSLang.programAddShader(program, @ptrCast(shader.handle));

        if (!GLSLang.programLink(program)) {
            return GLSLangProgramError.LinkProgram;
        }

        GLSLang.programSPIRVGenerate(program, @intFromEnum(stage));

        if (GLSLang.programSPIRVGetMessages(program) != null) {
            std.debug.print("[GLSLang] Could not compile shader: {s}\n", .{GLSLang.programSPIRVGetMessages(program)});
            return GLSLangProgramError.GenerateSPIRV;
        }

        return .{
            .handle = @ptrCast(program),
        };
    }

    pub fn getSPIRVSize(self: *const GLSLangProgram) usize {
        return GLSLang.programSPIRVGetSize(@ptrCast(self.handle));
    }

    pub fn getSPIRVPtr(self: *const GLSLangProgram) [*c]u32 {
        return GLSLang.programSPIRVGetPtr(@ptrCast(self.handle));
    }

    pub fn destroy(self: *GLSLangProgram) void {
        GLSLang.programDelete(@ptrCast(self.handle));
    }
};
