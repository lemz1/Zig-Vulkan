const std = @import("std");
const glslang = @import("../glslang.zig");

const Allocator = std.mem.Allocator;
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

    pub fn fromFile(path: []const u8, stage: GLSLangShaderStage, allocator: Allocator) !RuntimeShader {
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
        defer file.close();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        const code = try std.fmt.allocPrintZ(allocator, "{s}", .{content});
        defer allocator.free(code);

        return RuntimeShader.new(code.ptr, stage);
    }

    pub fn destroy(self: *RuntimeShader) void {
        self.program.destroy();
        self.shader.destroy();
    }
};
