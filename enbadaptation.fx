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

float4 AdaptationParameters;

float fSensitivity <
	string UIName   = "Sensitivity";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 100.0;
> = 1.0;

float fCenterBias <
	string UIName   = "Center Bias";
	string UIWidget = "spinner";
	float  UIMin    = 0.0;
	float  UIMax    = 10.0;
> = 0.0;

Texture2D TextureCurrent;
Texture2D TexturePrevious;

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

float get_luma_linear(float3 color) {
	return dot(color, float3(0.2125, 0.7154, 0.0721));
}

float2 get_pixel_size(float width) {
	float rcp_width = 1.0 / width;
	return float2(rcp_width, rcp_width * ScreenSize.z);
}

void VS_PostProcess(
	float3 vertex         : POSITION,
	out float4 position   : SV_POSITION,
	inout float2 texcoord : TEXCOORD
) {
	position = float4(vertex, 1.0);
}

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
	color *= fSensitivity;

	float luma = get_luma_linear(color);
	luma *= saturate(lerp(1.0, 1.0 - distance(uv, 0.5), fCenterBias));

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
	luma = clamp(luma, AdaptationParameters.x, AdaptationParameters.y);
	
	return float4(luma.xxx, 1.0);
}

technique11 Downsample {
	pass {
		SetVertexShader(
			CompileShader(
				vs_5_0, VS_PostProcess()
			)
		);
		SetPixelShader(
			CompileShader(
				ps_5_0, PS_Downsample()
			)
		);
	}
}

technique11 Draw {
	pass {
		SetVertexShader(
			CompileShader(
				vs_5_0, VS_PostProcess()
			)
		);
		SetPixelShader(
			CompileShader(
				ps_5_0, PS_Adaptation()
			)
		);
	}
}
