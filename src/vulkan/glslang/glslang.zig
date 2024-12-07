const std = @import("std");
const c = @cImport(@cInclude("glslang/Include/glslang_c_interface.h"));

const GLSLangError = error{
    LoadFunction,
};

var lib: std.DynLib = undefined;
pub fn load() !void {
    lib = try std.DynLib.open("glslang.dll");

    inline for (@typeInfo(@TypeOf(glslangFunctions)).@"struct".fields) |field| {
        @field(glslangFunctions, field.name) = lib.lookup(field.type, field.name) orelse return GLSLangError.LoadFunction;
    }
}

pub fn unload() void {
    lib.close();
}

pub fn initializeProcess() i32 {
    return glslangFunctions.glslang_initialize_process();
}

var glslangFunctions = struct {
    glslang_initialize_process: @TypeOf(&c.glslang_initialize_process) = undefined,
}{};
