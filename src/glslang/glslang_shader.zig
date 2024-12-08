const glslang = @import("../glslang.zig");
const c = @cImport(@cInclude("glslang/Include/glslang_c_interface.h"));

const GLSLang = glslang.GLSLang;

const GLSLangShaderError = error{
    CreateShader,
    PreprocessShader,
    ParseShader,
};

pub const GLSLangShaderStage = enum(c.glslang_stage_t) {
    Vertex = c.GLSLANG_STAGE_VERTEX,
    TessControl = c.GLSLANG_STAGE_TESSCONTROL,
    TessEvaluation = c.GLSLANG_STAGE_TESSEVALUATION,
    Geometry = c.GLSLANG_STAGE_GEOMETRY,
    Fragment = c.GLSLANG_STAGE_FRAGMENT,
    Compute = c.GLSLANG_STAGE_COMPUTE,
    Raygen = c.GLSLANG_STAGE_RAYGEN,
    //RaygenNV = c.GLSLANG_STAGE_RAYGEN_NV,
    Intersect = c.GLSLANG_STAGE_INTERSECT,
    //IntersectNV = c.GLSLANG_STAGE_INTERSECT_NV,
    AnyHit = c.GLSLANG_STAGE_ANYHIT,
    //AnyHitNV = c.GLSLANG_STAGE_ANYHIT_NV,
    ClosestHit = c.GLSLANG_STAGE_CLOSESTHIT,
    //ClosestHitNV = c.GLSLANG_STAGE_CLOSESTHIT_NV,
    Miss = c.GLSLANG_STAGE_MISS,
    //MissNV = c.GLSLANG_STAGE_MISS_NV,
    Callable = c.GLSLANG_STAGE_CALLABLE,
    //CallableNV = c.GLSLANG_STAGE_CALLABLE_NV,
    Task = c.GLSLANG_STAGE_TASK,
    //TaskNV = c.GLSLANG_STAGE_TASK_NV,
    Mesh = c.GLSLANG_STAGE_MESH,
    //MeshNV = c.GLSLANG_STAGE_MESH_NV,
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
        input.resource = @ptrCast(GLSLang.defaultResource());

        const shader = GLSLang.shaderCreate(@ptrCast(&input)) orelse return GLSLangShaderError.CreateShader;

        if (!GLSLang.shaderPreprocess(shader, @ptrCast(&input))) {
            return GLSLangShaderError.PreprocessShader;
        }

        if (!GLSLang.shaderParse(shader, @ptrCast(&input))) {
            return GLSLangShaderError.ParseShader;
        }

        return .{
            .handle = @ptrCast(shader),
        };
    }

    pub fn destroy(self: *GLSLangShader) void {
        GLSLang.shaderDelete(@ptrCast(self.handle));
    }
};
