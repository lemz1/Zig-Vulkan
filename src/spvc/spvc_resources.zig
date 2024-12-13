const std = @import("std");
const spvc = @import("../spvc.zig");
const c = @cImport(@cInclude("spirv_cross_c.h"));

const SPVCCompiler = spvc.SPVCCompiler;

const spvcCheck = @import("base.zig").spvcCheck;

const SPVCResourcesError = error{
    CreateSPVCResources,
};

pub const SPVCResourceType = enum(c.spvc_resource_type) {
    Unknown = c.SPVC_RESOURCE_TYPE_UNKNOWN,
    UniformBuffer = c.SPVC_RESOURCE_TYPE_UNIFORM_BUFFER,
    StorageBuffer = c.SPVC_RESOURCE_TYPE_STORAGE_BUFFER,
    StageInput = c.SPVC_RESOURCE_TYPE_STAGE_INPUT,
    StageOutput = c.SPVC_RESOURCE_TYPE_STAGE_OUTPUT,
    SubpassInput = c.SPVC_RESOURCE_TYPE_SUBPASS_INPUT,
    StorageImage = c.SPVC_RESOURCE_TYPE_STORAGE_IMAGE,
    SampledImage = c.SPVC_RESOURCE_TYPE_SAMPLED_IMAGE,
    AtomicCounter = c.SPVC_RESOURCE_TYPE_ATOMIC_COUNTER,
    PushConstant = c.SPVC_RESOURCE_TYPE_PUSH_CONSTANT,
    SeperateImage = c.SPVC_RESOURCE_TYPE_SEPARATE_IMAGE,
    SeperateSamplers = c.SPVC_RESOURCE_TYPE_SEPARATE_SAMPLERS,
    AccelerationStructure = c.SPVC_RESOURCE_TYPE_ACCELERATION_STRUCTURE,
    RayQuery = c.SPVC_RESOURCE_TYPE_RAY_QUERY,
    ShaderRecordBuffer = c.SPVC_RESOURCE_TYPE_SHADER_RECORD_BUFFER,
    GLPlainUniform = c.SPVC_RESOURCE_TYPE_GL_PLAIN_UNIFORM,
    IntMax = c.SPVC_RESOURCE_TYPE_INT_MAX,
};

pub const SPVCResourceList = struct {
    resources: [*c]const c.spvc_reflected_resource,
    count: usize,
};

pub const SPVCResources = struct {
    handle: c.spvc_resources,

    pub fn new(compiler: *const SPVCCompiler) !SPVCResources {
        var resources: c.spvc_resources = undefined;
        switch (c.spvc_compiler_create_shader_resources(compiler.handle, &resources)) {
            c.SPVC_SUCCESS => {},
            else => {
                std.debug.print("[SPIRV-Cross] Could not create Resources\n", .{});
                return SPVCResourcesError.CreateSPVCResources;
            },
        }

        return .{
            .handle = resources,
        };
    }

    pub fn getResourceList(self: *const SPVCResources, @"type": SPVCResourceType) SPVCResourceList {
        var list: [*c]const c.spvc_reflected_resource = undefined;
        var size: usize = undefined;
        spvcCheck(c.spvc_resources_get_resource_list_for_type(self.handle, @intFromEnum(@"type"), &list, &size));

        return .{
            .resources = list,
            .count = size,
        };
    }
};
