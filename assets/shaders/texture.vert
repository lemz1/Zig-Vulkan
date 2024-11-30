#version 450 core

layout(location = 0) in vec2 iPosition;
layout(location = 1) in vec2 iTexCoord;

layout(location = 0) out vec2 oTexCoord;

void main() {
  gl_Position = vec4(iPosition, 0.0, 1.0);
  oTexCoord = iTexCoord;
}
