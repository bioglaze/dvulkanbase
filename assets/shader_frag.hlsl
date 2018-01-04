#if !VULKAN
#define layout(a,b)  
#else
#define register(a) blank
#endif

struct VSOutput
{
    float4 pos : SV_Position;
    float2 uv : TEXCOORD;
    float4 color : COLOR;
};

layout(set=0, binding=0) cbuffer Scene
{
    float4x4 localToClip;
    float4 tintColor;
    int textureIndex;
};

layout(set=0, binding=1) Texture2D<float4> tex[ 3 ] : register(t0);
layout(set=0, binding=2) SamplerState sLinear : register(s0);

float4 main( VSOutput vsOut ) : SV_Target
{
    return tex[ textureIndex ].SampleLevel( sLinear, vsOut.uv, 0 );
};
