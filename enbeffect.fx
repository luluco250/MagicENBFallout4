/*
	Magic ENB
*/

#include "enb_include/Common.hlsl"
#include "enb_include/ACES.hlsl"

  //========//
 //Uniforms//
//========//

float4 Params01[6];
float4 ENBParams01;

float uExposure <
	string UIName   = "Exposure";
	string UIWidget = "spinner";
	float  UIMin     = 0.01;
	float  UIMax     = 3.0;
> = 0.5;

float uBloom_Intensity <
	string UIName   = "Bloom Intensity";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 10.0;
> = 1.0;

float uDirt_Intensity <
	string UIName   = "Dirt Intensity";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 10.0;
> = 0.0;

  //========//
 //Textures//
//========//

Texture2D TextureColor;
Texture2D TextureBloom;
Texture2D TextureLens;
Texture2D TextureDepth;
Texture2D TextureAdaptation;
Texture2D TextureAperture;

Texture2D tDirt <string ResourceName = "enb_textures/Dirt.png";>;

  //=======//
 //Shaders//
//=======//

float4 PS_Magic(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = TextureColor.Sample(sPoint, uv).rgb;
	float3 bloom = TextureBloom.Sample(sLinear, uv).rgb;

	float3 dirt = tDirt.Sample(sLinear, uv).rgb;
	bloom += bloom * dirt * uDirt_Intensity;

	color += bloom * uBloom_Intensity;

	float adapt = TextureAdaptation.Sample(sPoint, uv).x;
	float exposure = uExposure / (adapt + 0.001);

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
