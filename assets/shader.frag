#version 450 core

layout(std140, binding=0) uniform PerDraw
{
    mat4 modelToClip;
    vec4 tintColor;
};

layout (location = 0) in vec2 vUV;
layout (location = 0) out vec4 fragColor;

void main()
{
    //fragColor = vec4( 1.0f, 0.0f, 0.0f, 1.0f );
    fragColor = tintColor;
}

