/*
	Magic ENB
*/

#include "enb_include/Common.hlsl"

// Proper sRGB doesn't work for now unfortunately.
//#include "enb_include/sRGB.hlsl"

  //========//
 //Uniforms//
//========//

float uBrightness <
	string UIName   = "Brightness";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 2.0;
> = 1.0;

float uContrast <
	string UIName   = "Contrast";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 2.0;
> = 1.0;

float uSaturation <
	string UIName   = "Saturation";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 2.0;
> = 1.0;

float uTemperature <
	string UIName   = "Temperature";
	string UIWidget = "spinner";
	float  UIMin    = -1.0;
	float  UIMax    =  1.0;
> = 0.0;

float uVignette_Opacity <
	string UIName   = "Vignette Opacity";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 0.5;

float uVignette_Start <
	string UIName   = "Vignette Start";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 0.0;

float uVignette_Stop <
	string UIName   = "Vignette Stop";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 1.0;

float3 uChromaticAberration <
	string UIName   = "Chromatic Aberration";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = {1.0, 0.5, 0.0};

float uFilmGrain_Intensity <
	string UIName   = "Film Grain Intensity";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 3.0;
> = 1.0;

float uFilmGrain_Speed <
	string UIName   = "Film Grain Speed";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 100.0;
> = 1.0;

float uFilmGrain_Mean <
	string UIName   = "Film Grain Mean";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 0.0;

float uFilmGrain_Variance <
	string UIName   = "Film Grain Variance";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 0.5;

  //========//
 //Textures//
//========//

Texture2D TextureOriginal;
Texture2D TextureColor;
Texture2D TextureDepth;
Texture2D RenderTargetRGBA32;
Texture2D RenderTargetRGBA64;
Texture2D RenderTargetRGBA64F;
Texture2D RenderTargetR16F;
Texture2D RenderTargetR32F;
Texture2D RenderTargetRGB32F;

  //=========//
 //Functions//
//=========//

float gaussian(float z, float u, float o) {
	// 2.506 ~= sqrt(2 * pi)
    return (1.0 / (o * 2.506)) * exp(-(((z - u) * (z - u)) / (2.0 * (o * o))));
}

float get_film_grain(float2 uv) {
	// 16777.216 is the max time * 0.001
	float t = Timer.x * 16777.216 * uFilmGrain_Speed;
	float seed = dot(uv, float2(12.9898, 78.233));
	float noise = frac(sin(seed) * 43758.5453 + t);
	//return gaussian(noise, uFilmGrain_Mean, uFilmGrain_Variance * uFilmGrain_Variance);
	return normal_distribution(noise, uFilmGrain_Mean, uFilmGrain_Variance);
}

  //=======//
 //Shaders//
//=======//

float4 PS_Magic(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	// Chromatic Aberration
	float3 color = float3(
		TextureColor.Sample(sLinear, scale_uv(uv, 1.0 + uChromaticAberration.r * 0.01)).r,
		TextureColor.Sample(sLinear, scale_uv(uv, 1.0 + uChromaticAberration.g * 0.01)).g,
		TextureColor.Sample(sLinear, scale_uv(uv, 1.0 + uChromaticAberration.b * 0.01)).b
	);

	// Vignette
	color *= 1.0 - smoothstep(uVignette_Start, uVignette_Stop, distance(uv, 0.5)) * uVignette_Opacity;

	// Film Grain
	color += (get_film_grain(uv) * (1.0 - color)) * uFilmGrain_Intensity * 0.01;

	// Brightness
	color *= uBrightness;

	// Contrast
	color = lerp(color, smoothstep(0.0, 1.0, color), uContrast - 1.0);

	// Saturation
	color = lerp(get_luma_linear(color), color, uSaturation);

	// Temperature
	color *= lerp(1.0, float3(1.0, 0.5, 0.0), uTemperature);

	color = pow(color, 1.0 / 2.2); // sRGB approximation
	//color = linear2srgb(color); // True sRGB, doesn't work for now unfortunately.
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
