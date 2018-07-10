#ifndef COMMON_HLSL
#define COMMON_HLSL

/*
	Magic ENB

	This file contains common utilities used in all shaders.
*/

  //========//
 //Uniforms//
//========//

// ENB Parameters

/*
	x: Generic timer in range 0.0<->1.0, period of 16777216ms (4.6 hours).
	y: Average FPS.
	z: Unused?
	w: Frame time elapsed (in seconds).
*/
float4 Timer;

/*
	x: Width.
	y: 1.0 / Width.
	z: Aspect Ratio (Width / Height).
	w: 1.0 / Aspect Ratio.
*/
float4 ScreenSize;

/*
	Changes in range 0.0<->1.0. 0.0 means full quality, 1.0 lowest dynamic
	quality (0.33, 0.66 are limits for quality levels).
*/
float  AdaptiveQuality;

/*
	x: Current weather index.
	y: Outgoing weather index.
	z: Weather transition.
	w: Time of day in 24 standard hours.

	Weather index is value from weather ini file, for example WEATHER002 means
	index == 2, but index == 0 means that the weather was not captured.
*/
float4 Weather;

/*
	x: Dawn.
	y: Sunrise.
	z: Day.
	w: Sunset.

	Interpolators ranging 0.0<->1.0.
*/
float4 TimeOfDay1;

/*
	x: Dusk.
	y: Night.
	z: Unused.
	w: Unused.

	Interpolators ranging 0.0<->1.0.
*/
float4 TimeOfDay2;

//Changes in range 0.0<->1.0, 0.0 means night time, 1.0 day time.
float  ENightDayFactor;

// Changes to 0 or 1, 0 means exterior, 1 interior.
float  EInteriorFactor;

// ENB Debugging Parameters

/*
	Keyboard-controlled temporary variables.
	Press and hold key 1, 2, 3...8 together with PageUp or PageDown to modify.
	All are set to 1.0 by default.
*/

// 0, 1, 2, 3 -- Maybe 4 goes here?
float4 tempF1;

// 5, 6, 7, 8
float4 tempF2;

// 9, 0 -- Might be wrong? Where's 4?
float4 tempF3;

/*
	x: Mouse horizontal position ranging 0.0<->1.0.
	y: Mouse vertical position ranging 0.0<->1.0.
	z: Is shader editor window active? -- (0.0 or 1.0 maybe)
	w: Mouse buttons with values 0<->7 as follows:
		0: None.
		1: Left.
		2: Right.
		3: Left + Right.
		4: Middle.
		5: Left + Middle.
		6: Right + Midle.
		7: Left + Right + Middle.
*/
float4 tempInfo1;

/*
	x: Mouse horizontal position at the last left click. -- (0.0<->1.0)
	y: Mouse vertical position at the last left click. -- (0.0<->1.0)
	z: Mouse horizontal position at the last right click. -- (0.0<->1.0)
	w: Mouse vertical position at the last right click. -- (0.0<->1.0)
*/
float4 tempInfo2;

// """static const"""
static const float2 uResolution = float2(ScreenSize.x, ScreenSize.x * ScreenSize.w);
static const float2 uPixelSize = float2(ScreenSize.y, ScreenSize.y * ScreenSize.z);

/*
	Common textures are omitted because they
	vary a lot and don't always behave the same way.
*/

  //========//
 //Samplers//
//========//

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

float2 scale_uv(float2 uv, float2 scale, float2 center = 0.5) {
	return mad((uv - center), scale, center);
}

/*float2 scale_uv(float2 uv, float2 scale) {
	return scale_uv(uv, scale, 0.5);
}*/

float3 get_luma_linear(float3 color) {
	return dot(color, float3(0.2125, 0.7154, 0.0721));
}

  //=======//
 //Shaders//
//=======//

// Basic vertex shader that renders fullscreen effects.
void VS_PostProcess(
	float3 vertex         : POSITION,
	out float4 position   : SV_POSITION,
	inout float2 texcoord : TEXCOORD
) {
	position = float4(vertex, 1.0);
}

// Displays a texture, mostly for debugging purposes.
float4 PS_ShowTexture(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD,
	uniform Texture2D tex,
	uniform SamplerState sp
) : SV_TARGET {
	float4 color = tex.Sample(sp, uv);

	float2 checker_uv = (uv * uResolution) / 8;
	checker_uv = fmod(floor(checker_uv), 2.0);
	float pattern = fmod(checker_uv.x + checker_uv.y, 2.0) * 0.5 + 0.25;

	color.rgb = lerp(pattern, color.rgb, color.a);
	return float4(color.rgb, 1.0);
}

#endif