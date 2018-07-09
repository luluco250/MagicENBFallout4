/*
	Magic ENB
*/

// Proper sRGB doesn't work for now unfortunately.
//#include "enb_include/sRGB.hlsl"

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

float fBrightness <
	string UIName   = "Brightness";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 2.0;
> = 1.0;

float fContrast <
	string UIName   = "Contrast";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 2.0;
> = 1.0;

float fSaturation <
	string UIName   = "Saturation";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 2.0;
> = 1.0;

float fTemperature <
	string UIName   = "Temperature";
	string UIWidget = "spinner";
	float  UIMin    = -1.0;
	float  UIMax    =  1.0;
> = 0.0;

float fVignette_Opacity <
	string UIName   = "Vignette Opacity";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 0.5;

float fVignette_Start <
	string UIName   = "Vignette Start";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 0.0;

float fVignette_Stop <
	string UIName   = "Vignette Stop";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 1.0;

float3 f3ChromaticAberration <
	string UIName   = "Chromatic Aberration";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = {1.0, 0.5, 0.0};

float fFilmGrain_Intensity <
	string UIName   = "Film Grain Intensity";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 1.0;

float fFilmGrain_Speed <
	string UIName   = "Film Grain Speed";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 100.0;
> = 1.0;

float fFilmGrain_Mean <
	string UIName   = "Film Grain Mean";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 1.0;
> = 0.0;

float fFilmGrain_Variance <
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

SamplerState sPoint {
	Filter   = MIN_MAG_MIP_POINT;
	AddressU = Clamp;
	AddressV = Clamp;
};
SamplerState sLinear {
	Filter   = MIN_MAG_MIP_LINEAR;
	AddressU = Clamp;
	AddressV = Clamp;
};

  //=========//
 //Functions//
//=========//

float3 get_luma_linear(float3 color) {
	return dot(color, float3(0.2125, 0.7154, 0.0721));
}

float2 scale_uv(float2 uv, float2 scale, float2 center) {
	return mad((uv - center), scale, center); //(uv - center) * scale + center;
}

float2 scale_uv(float2 uv, float2 scale) {
	return scale_uv(uv, scale, 0.5);
}

float gaussian(float z, float u, float o) {
	// 2.506 ~= sqrt(2 * pi)
    return (1.0 / (o * 2.506)) * exp(-(((z - u) * (z - u)) / (2.0 * (o * o))));
}

float get_film_grain(float2 uv) {
	// 16777.216 is the max time * 0.001
	float t = Timer.x * 16777.216 * fFilmGrain_Speed;
	float seed = dot(uv, float2(12.9898, 78.233));
	float noise = frac(sin(seed) * 43758.5453 + t);
	return gaussian(noise, fFilmGrain_Mean, fFilmGrain_Variance * fFilmGrain_Variance);
}

  //=======//
 //Shaders//
//=======//

void VS_Magic(
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
	// Chromatic Aberration
	float3 color = float3(
		TextureColor.Sample(sLinear, scale_uv(uv, 1.0 + f3ChromaticAberration.r * 0.01)).r,
		TextureColor.Sample(sLinear, scale_uv(uv, 1.0 + f3ChromaticAberration.g * 0.01)).g,
		TextureColor.Sample(sLinear, scale_uv(uv, 1.0 + f3ChromaticAberration.b * 0.01)).b
	);

	// Vignette
	color *= 1.0 - smoothstep(fVignette_Start, fVignette_Stop, distance(uv, 0.5)) * fVignette_Opacity;

	// Film Grain
	color += (get_film_grain(uv) * (1.0 - color)) * fFilmGrain_Intensity * 0.01;

	// Brightness
	color *= fBrightness;

	// Contrast
	color = lerp(color, smoothstep(0.0, 1.0, color), fContrast - 1.0);

	// Saturation
	color = lerp(get_luma_linear(color), color, fSaturation);

	// Temperature
	color *= lerp(1.0, float3(1.0, 0.5, 0.0), fTemperature);

	color = pow(color, 1.0 / 2.2); // sRGB approximation
	//color = linear2srgb(color); // True sRGB, doesn't work for now unfortunately.
	return float4(color, 1.0);
}

  //==========//
 //Techniques//
//==========//

technique11 Magic <string UIName = "Magic";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_Magic()));
		SetPixelShader(CompileShader(ps_5_0, PS_Magic()));
	}
}
