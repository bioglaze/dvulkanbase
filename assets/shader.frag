#version 450 core

layout(std140, binding=0) uniform PerDraw
{
    mat4 modelToClip;
};

in vec2 vUV;
out vec4 fragColor;

void main()
{
    fragColor = vec4( 1.0f, 0.0f, 0.0f, 1.0f );
}

