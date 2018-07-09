#ifndef SRGB_HLSL
#define SRGB_HLSL

/*
	Magic ENB

	Provides proper gamma correction, I don't know if ENB already uses sRGB
	textures in the backend (probably doesn't, given it uses pow(x, 1.0 / 2.2)
	in some shaders).

	Instead of using the pow() approximation, this uses the REAL sRGB conversion
	algorithms.
*/

float3 linear2srgb(float3 color) {
	return lerp(
		color * 12.92,
		pow(color, 1.0 / 2.4) * 1.055 - 0.055,
		step(color, 0.00031308)
	);
}

float3 srgb2linear(float3 color) {
	return lerp(
		color / 12.92,
		pow((color + 0.055) / 1.055, 2.4),
		step(color, 0.04045)
	);
}

#endif