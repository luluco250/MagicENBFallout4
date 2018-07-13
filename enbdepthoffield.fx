/*
	Magic ENB
*/

#include "enb_include/Common.hlsl"
#include "enb_include/Macros.hlsl"

  //======//
 //Macros//
//======//

// Use color + depth for edge detection if 1
#define SMAA_FX_USE_PREDICATION 1

  //========//
 //Uniforms//
//========//

float4 DofParameters;

float uSMAA_Threshold <
	string UIName = "<SMAA> Threshold";
	string UIWidget = "spinner";
	float UIMin = 0.0;
	float UIMax = 0.5;
> = 0.1;

int uSMAA_MaxSearchSteps <
	string UIName = "<SMAA> Max Search Steps";
	string UIWidget = "spinner";
	int UIMin = 0;
	int UIMax = 112;
> = 16;

int uSMAA_MaxDiagonalSearchSteps <
	string UIName = "<SMAA> Max Diagonal Search Steps";
	string UIWidget = "spinner";
	int UIMin = 0;
	int UIMax = 20;
> = 8;

int uSMAA_CornerRounding <
	string UIName = "<SMAA> Corner Rounding";
	string UIWidget = "spinner";
	int UIMin = 0;
	int UIMax = 100;
> = 25;

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

  //======//
 //States//
//======//

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

  //==========//
 //SMAA Setup//
//==========//

#define SMAA_RT_METRICS float4(uPixelSize, uResolution)

#define SMAA_HLSL_4_1
#define SMAA_PRESET_CUSTOM

#define SMAA_THRESHOLD uSMAA_Threshold
#define SMAA_MAX_SEARCH_STEPS uSMAA_MaxSearchSteps
#define SMAA_MAX_SEARCH_STEPS_DIAG uSMAA_MaxDiagonalSearchSteps
#define SMAA_CORNER_ROUNDING uSMAA_CornerRounding
#define SMAA_PREDICATION SMAA_FX_USE_PREDICATION

Texture2D tArea <string ResourceName = "enb_textures/AreaTex.dds";>;
Texture2D tSearch <string ResourceName = "enb_textures/SearchTex.dds";>;

//#define tEdges RenderTargetRGB32F
#define tBlend RenderTargetRGBA64F

#include "enb_include/SMAA.hlsl"

  //=======//
 //Shaders//
//=======//

void VS_SMAA_EdgeDetection(
	float3 vertex        : POSITION,
	out float4 position  : SV_POSITION,
	inout float2 uv      : TEXCOORD0,
	out float4 offset[3] : TEXCOORD1
) {
	position = float4(vertex, 1.0);
	SMAAEdgeDetectionVS(uv, offset);
}

float4 PS_SMAA_EdgeDetection(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD0,
	float4 offset[3] : TEXCOORD1
) : SV_TARGET {
	#if SMAA_FX_USE_PREDICATION
	float2 ret = SMAAColorEdgeDetectionPS(uv, offset, TextureOriginal, TextureDepth);
	#else
	float2 ret = SMAAColorEdgeDetectionPS(uv, offset, TextureOriginal);
	#endif
	return float4(ret, 0.0, 1.0);
}

void VS_SMAA_BlendingWeightCalculation(
	float3 vertex        : POSITION,
	out float4 position  : SV_POSITION,
	inout float2 uv      : TEXCOORD0,
	out float2 pix_uv    : TEXCOORD1,
	out float4 offset[3] : TEXCOORD2
) {
	position = float4(vertex, 1.0);
	SMAABlendingWeightCalculationVS(uv, pix_uv, offset);
}

float4 PS_SMAA_BlendingWeightCalculation(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD0,
	float2 pix_uv    : TEXCOORD1,
	float4 offset[3] : TEXCOORD2
) : SV_TARGET {
	return SMAABlendingWeightCalculationPS(
		uv,
		pix_uv,
		offset,
		TextureColor, // last pass/edges tex
		tArea,
		tSearch,
		0.0
	);
}

void VS_SMAA_NeighborhoodBlending(
	float3 vertex       : POSITION,
	out float4 position : SV_POSITION,
	inout float2 uv     : TEXCOORD0,
	out float4 offset   : TEXCOORD1
) {
	position = float4(vertex, 1.0);
	SMAANeighborhoodBlendingVS(uv, offset);
}

float4 PS_SMAA_NeighborhoodBlending(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD0,
	float4 offset   : TEXCOORD1
) : SV_TARGET {
	return SMAANeighborhoodBlendingPS(uv, offset, TextureOriginal, tBlend);
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

  //==========//
 //Techniques//
//==========//

// SMAA Edge Detection
technique11 Magic <string UIName = "Magic";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_SMAA_EdgeDetection()));
		SetPixelShader(CompileShader(ps_5_0, PS_SMAA_EdgeDetection()));

		SetDepthStencilState(DisableDepthReplaceStencil, 1);
		SetBlendState(NoBlending, float4(0.0, 0.0, 0.0, 0.0), 0xFFFFFFFF);
	}
}

// SMAA Blending Weight Calculation
technique11 Magic1 <string RenderTarget = TOSTRING(tBlend);> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_SMAA_BlendingWeightCalculation()));
		SetPixelShader(CompileShader(ps_5_0, PS_SMAA_BlendingWeightCalculation()));

		SetDepthStencilState(DisableDepthUseStencil, 1);
		SetBlendState(NoBlending, float4(0.0, 0.0, 0.0, 0.0), 0xFFFFFFFF);
	}
}

// SMAA Neighborhood Blending
technique11 Magic2 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_SMAA_NeighborhoodBlending()));
		SetPixelShader(CompileShader(ps_5_0, PS_SMAA_NeighborhoodBlending()));

		SetDepthStencilState(DisableDepthStencil, 0);
		SetBlendState(NoBlending, float4(0.0, 0.0, 0.0, 0.0), 0xFFFFFFFF);
	}
}

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
