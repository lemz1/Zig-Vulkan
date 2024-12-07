const std = @import("std");
const c = @cImport({
    @cInclude("glslang/Include/glslang_c_interface.h");
    @cInclude("glslang/Public/resource_limits_c.h");
});

const GLSLangError = error{
    LoadFunction,
    InitializeProcess,
};

var initialized: bool = false;
var glslangLib: std.DynLib = undefined;
var glslangResourceLimitsLib: std.DynLib = undefined;
pub fn load() !void {
    if (initialized) {
        return;
    }

    glslangLib = try std.DynLib.open("glslang.dll");

    inline for (@typeInfo(@TypeOf(glslangFunctions)).@"struct".fields) |field| {
        @field(glslangFunctions, field.name) = glslangLib.lookup(field.type, field.name) orelse return GLSLangError.LoadFunction;
    }

    glslangResourceLimitsLib = try std.DynLib.open("glslang-default-resource-limits.dll");
    inline for (@typeInfo(@TypeOf(glslangResourceLimitsFunctions)).@"struct".fields) |field| {
        @field(glslangResourceLimitsFunctions, field.name) = glslangResourceLimitsLib.lookup(field.type, field.name) orelse return GLSLangError.LoadFunction;
    }

    if (!initializeProcess()) {
        return GLSLangError.InitializeProcess;
    }

    initialized = true;
}

pub fn unload() void {
    if (!initialized) {
        return;
    }

    finalizeProcess();

    glslangResourceLimitsLib.close();
    glslangResourceLimitsLib = undefined;

    glslangLib.close();
    glslangLib = undefined;

    initialized = false;
}

var glslangFunctions = struct {
    glslang_initialize_process: @TypeOf(&c.glslang_initialize_process) = undefined,
    glslang_finalize_process: @TypeOf(&c.glslang_finalize_process) = undefined,
    glslang_shader_create: @TypeOf(&c.glslang_shader_create) = undefined,
    glslang_shader_delete: @TypeOf(&c.glslang_shader_delete) = undefined,
    glslang_shader_preprocess: @TypeOf(&c.glslang_shader_preprocess) = undefined,
    glslang_shader_parse: @TypeOf(&c.glslang_shader_parse) = undefined,
    glslang_program_create: @TypeOf(&c.glslang_program_create) = undefined,
    glslang_program_delete: @TypeOf(&c.glslang_program_delete) = undefined,
    glslang_program_add_shader: @TypeOf(&c.glslang_program_add_shader) = undefined,
    glslang_program_link: @TypeOf(&c.glslang_program_link) = undefined,
    glslang_program_get_info_log: @TypeOf(&c.glslang_program_get_info_log) = undefined,
    glslang_program_SPIRV_generate: @TypeOf(&c.glslang_program_SPIRV_generate) = undefined,
    glslang_program_SPIRV_get_size: @TypeOf(&c.glslang_program_SPIRV_get_size) = undefined,
    glslang_program_SPIRV_get_ptr: @TypeOf(&c.glslang_program_SPIRV_get_ptr) = undefined,
    glslang_program_SPIRV_get_messages: @TypeOf(&c.glslang_program_SPIRV_get_messages) = undefined,
}{};

pub fn initializeProcess() bool {
    return glslangFunctions.glslang_initialize_process() != 0;
}

pub fn finalizeProcess() void {
    return glslangFunctions.glslang_finalize_process();
}

pub fn shaderCreate(input: *const c.glslang_input_t) ?*c.glslang_shader_t {
    return glslangFunctions.glslang_shader_create(input);
}

pub fn shaderDelete(shader: *c.glslang_shader_t) void {
    return glslangFunctions.glslang_shader_delete(shader);
}

pub fn shaderPreprocess(shader: *c.glslang_shader_t, input: *const c.glslang_input_t) bool {
    return glslangFunctions.glslang_shader_preprocess(shader, input) != 0;
}

pub fn shaderParse(shader: *c.glslang_shader_t, input: *const c.glslang_input_t) bool {
    return glslangFunctions.glslang_shader_parse(shader, input) != 0;
}

pub fn programCreate() ?*c.glslang_program_t {
    return glslangFunctions.glslang_program_create();
}

pub fn programDelete(program: *c.glslang_program_t) void {
    return glslangFunctions.glslang_program_delete(program);
}

pub fn programAddShader(program: *c.glslang_program_t, shader: *c.glslang_shader_t) void {
    return glslangFunctions.glslang_program_add_shader(program, shader);
}

pub fn programLink(program: *c.glslang_program_t) bool {
    return glslangFunctions.glslang_program_link(program, c.GLSLANG_MSG_DEFAULT_BIT) != 0;
}

pub fn programGetInfoLog(program: *c.glslang_program_t) [*c]const u8 {
    return glslangFunctions.glslang_program_get_info_log(program);
}

pub fn programSPIRVGenerate(program: *c.glslang_program_t, stage: c.glslang_stage_t) void {
    return glslangFunctions.glslang_program_SPIRV_generate(program, stage);
}

pub fn programSPIRVGetSize(program: *c.glslang_program_t) usize {
    return glslangFunctions.glslang_program_SPIRV_get_size(program);
}

pub fn programSPIRVGetPtr(program: *c.glslang_program_t) [*c]c_uint {
    return glslangFunctions.glslang_program_SPIRV_get_ptr(program);
}

pub fn programSPIRVGetMessages(program: *c.glslang_program_t) [*c]const u8 {
    return glslangFunctions.glslang_program_SPIRV_get_messages(program);
}

var glslangResourceLimitsFunctions = struct {
    glslang_default_resource: @TypeOf(&c.glslang_default_resource) = undefined,
}{};

pub fn defaultResource() *const c.glslang_resource_t {
    return glslangResourceLimitsFunctions.glslang_default_resource();
}
