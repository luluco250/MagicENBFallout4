/*
	Magic ENB
*/

#include "enb_include/Common.hlsl"

  //========//
 //Uniforms//
//========//

/*
	x: AdaptationMin.
	y: AdaptationMax.
	z: AdaptationSensitivity.
	w: AdaptationTime multiplied by time elapsed.
*/
float4 AdaptationParameters;

float uSensitivity <
	string UIName   = "Sensitivity";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 100.0;
> = 1.0;

float uCenterBias <
	string UIName   = "Center Bias";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 10.0;
> = 0.0;

bool uOnlyClampInExterior <
	string UIName = "Only Clamp in Exteriors";
> = true;

  //========//
 //Textures//
//========//

Texture2D TextureCurrent;
Texture2D TexturePrevious;

  //=========//
 //Functions//
//=========//

float2 get_pixel_size(float width) {
	float rcp_width = 1.0 / width;
	return float2(rcp_width, rcp_width * ScreenSize.z);
}

  //=======//
 //Shaders//
//=======//

float4 PS_Downsample(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	const float2 ps = get_pixel_size(256.0);
	float3 color = 0.0;
	
	[unroll]
	for (int x = -8; x <= 8; ++x) {
		[unroll]
		for (int y = -8; y <= 8; ++y) {
			color += TextureCurrent.Sample(sLinear, uv + ps * float2(x, y)).rgb;
		}
	}
	color /= 16 * 16;

	color *= uSensitivity;

	float luma = get_luma_linear(color);
	luma *= saturate(lerp(1.0, 1.0 - distance(uv, 0.5), uCenterBias));

	return float4(luma.xxx, 1.0);
}

float4 PS_Adaptation(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	const float2 ps = get_pixel_size(16.0);
	float luma = 0.0;
	float luma_max = 0.0;
	
	[unroll]
	for (int x = -8; x <= 8; ++x) {
		[unroll]
		for (int y = -8; y <= 8; ++y) {
			float pixel = TextureCurrent.Sample(sLinear, uv + ps * float2(x, y)).x;
			luma += pixel;
			luma_max = max(luma_max, pixel);
		}
	}
	luma /= 16 * 16;

	// Sensitivity
	luma = lerp(luma, luma_max, AdaptationParameters.z);
	
	// Time
	float last = TexturePrevious.Sample(sPoint, uv).x;
	luma = lerp(last, luma, AdaptationParameters.w);

	// Min/Max
	if (!uOnlyClampInExterior || EInteriorFactor == 0)
		luma = clamp(luma, AdaptationParameters.x, AdaptationParameters.y);
	
	return float4(luma.xxx, 1.0);
}

  //==========//
 //Techniques//
//==========//

technique11 Downsample {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_Downsample()));
	}
}

technique11 Draw {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_Adaptation()));
	}
}
