/*
	Magic ENB
*/

#include "enb_include/ACES.hlsl"

  //========//
 //Uniforms//
//========//

float4 Timer;
float4 ScreenSize;
float4 AdaptiveQuality;
float4 Weather;
float4 TimeOfDay1;
float4 TimeOfDay2;
float  ENightDayFactor;
float  EInteriorFactor;

float4 tempF1;
float4 tempF2;
float4 tempF3;
float4 tempInfo1;
float4 tempInfo2;

float4 Params01[6];
float4 ENBParams01;

float fExposure <
	string UIName   = "Exposure";
	string UIWidget = "spinner";
	float UIMin     = 0.01;
	float UIMax     = 3.0;
> = 0.5;

float fBloom_Intensity <
	string UIName   = "Bloom Intensity";
	string UIWidget = "spinner";
	float UIMin     = 0.0;
	float UIMax     = 10.0;
> = 1.0;

  //========//
 //Textures//
//========//

Texture2D TextureColor;
Texture2D TextureBloom;
Texture2D TextureLens;
Texture2D TextureDepth;
Texture2D TextureAdaptation;
Texture2D TextureAperture;

SamplerState sPoint {
	Filter = MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
SamplerState sLinear {
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

  //=======//
 //Shaders//
//=======//

void VS_PostProcess(
	float3 vertex         : POSITION,
	out float4 position   : SV_POSITION,
	inout float2 texcoord : TEXCOORD
) {
	position = float4(vertex, 1.0);
}

float4 PS_Magic(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = TextureColor.Sample(sPoint, uv).rgb;
	float3 bloom = TextureBloom.Sample(sLinear, uv).rgb;
	color += bloom * fBloom_Intensity;

	float adapt = TextureAdaptation.Sample(sPoint, uv).x;
	float exposure = fExposure / (adapt + 0.001);

	color *= exposure;
	color  = ACESFitted(color);

	// Conditional filter, like night scope
	// It doesn't actually seem to work, however, I'll have to look into it.
	color = lerp(color, Params01[5].xyz, Params01[5].w);

	color = saturate(color);

	return float4(color, 1.0);
}

  //==========//
 //Techniques//
//==========//

technique11 Magic <string UIName = "Magic";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_Magic()));
	}
}
