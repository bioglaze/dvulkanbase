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
    int textureIndex;
};

VSOutput main( float3 pos : POSITION, float2 uv : TEXCOORD, float4 color : COLOR, float3 instancedPos : POSITION2, float2 instancedUV : TEXCOORD2, float4 instancedColor : COLOR2 )
{
    VSOutput vsOut;
    vsOut.pos = mul( localToClip, float4( pos + instancedPos, 1.0 ) );
    vsOut.uv = uv + instancedUV;
    vsOut.color = color + instancedColor;
    return vsOut;
}
