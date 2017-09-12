#if !VULKAN
#define layout(a,b)  
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
};

VSOutput main( float3 pos : POSITION, float2 uv : TEXCOORD, float4 color : COLOR )
{
    VSOutput vsOut;
    vsOut.pos = mul( localToClip, float4( pos, 1.0 ) );
    vsOut.uv = uv;
    vsOut.color = color;
    return vsOut;
}
