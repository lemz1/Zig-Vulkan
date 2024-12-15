const glslang = @import("../glslang.zig");
const c = @cImport({
    @cInclude("glslang/Include/glslang_c_interface.h");
    @cInclude("glslang/Public/resource_limits_c.h");
});

const GLSLang = glslang.GLSLang;

pub const GLSLangShaderStage = enum(c.glslang_stage_t) {
    Vertex = c.GLSLANG_STAGE_VERTEX,
    TessControl = c.GLSLANG_STAGE_TESSCONTROL,
    TessEvaluation = c.GLSLANG_STAGE_TESSEVALUATION,
    Geometry = c.GLSLANG_STAGE_GEOMETRY,
    Fragment = c.GLSLANG_STAGE_FRAGMENT,
    Compute = c.GLSLANG_STAGE_COMPUTE,
    Raygen = c.GLSLANG_STAGE_RAYGEN,
    Intersect = c.GLSLANG_STAGE_INTERSECT,
    AnyHit = c.GLSLANG_STAGE_ANYHIT,
    ClosestHit = c.GLSLANG_STAGE_CLOSESTHIT,
    Miss = c.GLSLANG_STAGE_MISS,
    Callable = c.GLSLANG_STAGE_CALLABLE,
    Task = c.GLSLANG_STAGE_TASK,
    Mesh = c.GLSLANG_STAGE_MESH,
    Count = c.GLSLANG_STAGE_COUNT,
};

pub const GLSLangShader = struct {
    handle: *c.glslang_shader_t,

    pub fn new(code: [*c]const u8, stage: GLSLangShaderStage) !GLSLangShader {
        var input = c.glslang_input_t{};
        input.language = c.GLSLANG_SOURCE_GLSL;
        input.stage = @intFromEnum(stage);
        input.client = c.GLSLANG_CLIENT_VULKAN;
        input.client_version = c.GLSLANG_TARGET_VULKAN_1_3;
        input.target_language = c.GLSLANG_TARGET_SPV;
        input.target_language_version = c.GLSLANG_TARGET_SPV_1_6;
        input.code = code;
        input.default_version = 450;
        input.default_profile = c.GLSLANG_CORE_PROFILE;
        input.force_default_version_and_profile = 0;
        input.forward_compatible = 0;
        input.messages = c.GLSLANG_MSG_DEFAULT_BIT;
        input.resource = c.glslang_default_resource();

        const shader = c.glslang_shader_create(&input) orelse return error.CreateShader;

        if (c.glslang_shader_preprocess(shader, &input) == 0) {
            return error.PreprocessShader;
        }

        if (c.glslang_shader_parse(shader, &input) == 0) {
            return error.ParseShader;
        }

        return .{
            .handle = shader,
        };
    }

    pub fn destroy(self: *GLSLangShader) void {
        c.glslang_shader_delete(self.handle);
    }
};
