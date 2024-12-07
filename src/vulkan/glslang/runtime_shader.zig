const std = @import("std");
const glslang = @import("../glslang.zig");

const GLSLangShader = glslang.GLSLangShader;
const GLSLangShaderStage = glslang.GLSLangShaderStage;
const GLSLangProgram = glslang.GLSLangProgram;

pub const RuntimeShader = struct {
    shader: GLSLangShader,
    program: GLSLangProgram,
    size: usize,
    spirv: [*c]u32,

    pub fn new(code: [*c]const u8, stage: GLSLangShaderStage) !RuntimeShader {
        const shader = try GLSLangShader.new(code, stage);
        const program = try GLSLangProgram.new(&shader, stage);

        return .{
            .shader = shader,
            .program = program,
            .size = program.getSPIRVSize() * @sizeOf(u32),
            .spirv = program.getSPIRVPtr(),
        };
    }

    pub fn destroy(self: *RuntimeShader) void {
        self.program.destroy();
        self.shader.destroy();
    }
};
