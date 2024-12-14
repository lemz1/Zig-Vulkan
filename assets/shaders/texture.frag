#version 450 core

layout(location = 0) out vec4 fragColor;

layout(location = 0) in vec2 oTexCoord;

layout(set = 0, binding = 1) uniform sampler2D uTexture;

void main() {
  vec4 texSample = texture(uTexture, oTexCoord);
  fragColor = texSample;
}
