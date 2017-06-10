#version 450 core

layout(location = 0) in vec3 inPosition;
layout(location = 1) in vec2 inUV;
layout(location = 2) in vec4 inColor;

out gl_PerVertex { vec4 gl_Position; };

layout(std140, binding=0) uniform PerDraw
{
    mat4 modelToClip;
    vec4 tintColor;
};

out vec2 vUV;

void main()
{
    gl_Position = modelToClip * vec4( inPosition, 1.0 );

    vUV = inUV;
}

