/*
	Magic ENB
*/

#include "enb_include/Macros.hlsl"

  //========//
 //Uniforms//
//========//

float4 Timer;
float4 ScreenSize;
float AdaptiveQuality;
float4 Weather;
float4 TimeOfDay1;
float4 TimeOfDay2;
float ENightDayFactor;
float EInteriorFactor;

float4 tempF1;
float4 tempF2;
float4 tempF3;
float4 tempInfo1;
float4 tempInfo2;

float4 DofParameters;

static const float2 resolution = float2(ScreenSize.x, ScreenSize.x * ScreenSize.w);
static const float2 pixelsize = float2(ScreenSize.y, ScreenSize.y * ScreenSize.z);

  //========//
 //Textures//
//========//

Texture2D TextureCurrent;
Texture2D TexturePrevious;

Texture2D TextureOriginal;
Texture2D TextureColor;
Texture2D TextureDepth;
Texture2D TextureFocus;
Texture2D TextureAperture;
Texture2D TextureAdaptation;

Texture2D RenderTargetRGBA32;
Texture2D RenderTargetRGBA64;
Texture2D RenderTargetRGBA64F;
Texture2D RenderTargetR16F;
Texture2D RenderTargetR32F;
Texture2D RenderTargetRGB32F;

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

  //==========//
 //SMAA Setup//
//==========//

Texture2D areaTex <string ResourceName = "enb_textures/AreaTex.dds";>;
Texture2D searchTex <string ResourceName = "enb_textures/SearchTex.dds";>;

#define colorTexGamma TextureColor
#define colorTex RenderTargetRGBA64F
#define depthTex TextureDepth
#define edgesTex RenderTargetRGB32F
#define blendTex RenderTargetRGBA32

#define SMAA_RT_METRICS float4(pixelsize, resolution)
#define SMAA_HLSL_4_1
#define SMAA_PRESET_ULTRA
#define SMAA_PREDICATION 1
#include "enb_include/SMAA.hlsl"

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

void VS_SMAA_EdgeDetection(
	float3 vertex			: POSITION,
	out float4 pos			: SV_POSITION,
	inout float2 uv			: TEXCOORD0,
	out float4 offset[3]	: TEXCOORD1
) {
	VS_PostProcess(vertex, pos, uv);
	SMAAEdgeDetectionVS(uv, offset);
}

float2 PS_SMAA_EdgeDetection(
	float4 pos			: SV_POSITION,
	float2 uv			: TEXCOORD0,
	float4 offset[3]	: TEXCOORD1
) : SV_Target {
	return SMAAColorEdgeDetectionPS(uv, offset, colorTexGamma, depthTex);
}

void VS_SMAA_BlendingWeightCalculation(
	float3 vertex			: POSITION,
	out float4 pos			: SV_POSITION,
	inout float2 uv			: TEXCOORD0,
	out float2 pixuv		: TEXCOORD1,
	out float4 offset[3]	: TEXCOORD2
) {
	VS_PostProcess(vertex, pos, uv);
	SMAABlendingWeightCalculationVS(uv, pixuv, offset);
}

float4 PS_SMAA_BlendingWeightCalculation(
	float4 pos			: SV_POSITION,
	float2 uv			: TEXCOORD0,
	float2 pixuv		: TEXCOORD1,
	float4 offset[3]	: TEXCOORD2
) : SV_Target {
	return SMAABlendingWeightCalculationPS(uv, pixuv, offset, edgesTex, areaTex, searchTex, 0);
}

void VS_SMAA_NeighborhoodBlending(
	float3 vertex		: POSITION,
	out float4 pos		: SV_POSITION,
	inout float2 uv		: TEXCOORD0,
	out float4 offset	: TEXCOORD1
) {
	VS_PostProcess(vertex, pos, uv);
	SMAANeighborhoodBlendingVS(uv, offset);
}

float4 PS_SMAA_NeighborhoodBlending(
	float4 pos		: SV_POSITION,
	float2 uv		: TEXCOORD0,
	float4 offset	: TEXCOORD1
) : SV_Target {
	return SMAANeighborhoodBlendingPS(uv, offset, colorTex, blendTex);
}

float4 PS_GammaToLinear(
	float4 pos	: SV_POSITION,
	float2 uv	: TEXCOORD,
	uniform Texture2D input
) : SV_Target {
	float4 col = input.Sample(sPoint, uv);
	col.rgb = pow(col.rgb, 2.2);
	return col;
}

float4 PS_LinearToGamma(
	float4 pos	: SV_POSITION,
	float2 uv	: TEXCOORD,
	uniform Texture2D input
) : SV_Target {
	float4 col = input.Sample(sPoint, uv);
	col.rgb = pow(col.rgb, 1.0 / 2.2);
	return col;
}

float4 PS_Aperture(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return float4(0.0, 0.0, 0.0, 1.0);
}

float4 PS_ReadFocus(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return float4(0.0, 0.0, 0.0, 1.0);
}

float4 PS_Focus(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return float4(0.0, 0.0, 0.0, 1.0);
}

float4 PS_Magic(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = TextureColor.Sample(sLinear, uv).rgb;
	return float4(color, 1.0);
}

  //==========//
 //Techniques//
//==========//

DepthStencilState DisableDepthStencil {
	DepthEnable = FALSE;
	StencilEnable = FALSE;
};

DepthStencilState DisableDepthReplaceStencil {
	DepthEnable = FALSE;
	StencilEnable = TRUE;
	FrontFaceStencilPass = REPLACE;
};

DepthStencilState DisableDepthUseStencil {
	DepthEnable = FALSE;
	StencilEnable = TRUE;
	FrontFaceStencilFunc = EQUAL;
};

BlendState Blend {
	AlphaToCoverageEnable = FALSE;
	BlendEnable[0] = TRUE;
	SrcBlend = BLEND_FACTOR;
	DestBlend = INV_BLEND_FACTOR;
	BlendOp = ADD;
};

BlendState NoBlending {
	AlphaToCoverageEnable = FALSE;
	BlendEnable[0] = FALSE;
};

technique11 Aperture {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_Aperture()));
	}
}

technique11 ReadFocus {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_ReadFocus()));
	}
}

technique11 Focus {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_Focus()));
	}
}

technique11 Magic <string UIName = "Magic"; string RenderTarget = TOSTRING(colorTex);> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_GammaToLinear(colorTexGamma)));
	}
}

//SMAA EdgeDetection
technique11 Magic1 <
	string RenderTarget = TOSTRING(edgesTex);
> {
    pass {
        SetVertexShader(CompileShader(vs_5_0, VS_SMAA_EdgeDetection()));
        SetPixelShader(CompileShader(ps_5_0, PS_SMAA_EdgeDetection()));
    }
}

//SMAA BlendingWeightCalculation
technique11 Magic2 <
	string RenderTarget = TOSTRING(blendTex);
> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_SMAA_BlendingWeightCalculation()));
		SetPixelShader(CompileShader(ps_5_0, PS_SMAA_BlendingWeightCalculation()));
	}
}

//SMAA NeighborhoodBlending
technique11 Magic3 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_SMAA_NeighborhoodBlending()));
		SetPixelShader(CompileShader(ps_5_0, PS_SMAA_NeighborhoodBlending()));
	}
}

technique11 Magic4 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_LinearToGamma(TextureColor)));
	}
}

technique11 Magic5 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_Magic()));
	}
}
