/*
	Magic ENB
*/

#include "enb_include/Common.hlsl"

  //======//
 //Macros//
//======//

// Controls how each bloom step/texture is distributed.
// 0: Normal, 1: Detailed/Clear, 2: Smooth/Foggy, 3: Gaussian
#define BLOOM_DISTRIBUTION 3

  //=========//
 //Constants//
//=========//

static const int cGaussianSamples = 13;
static const int cBloomSteps = 7;

/*
	Python code for this:

	Normal:
	###############################################
	for i in range(7): print(1 / 7, end=",\n")
	###############################################

	Detailed/Clear:
	###############################################
	weights = [1 << x for x in range(7)][::-1]
	total = sum(weights)
	weights = [x / total for x in weights]
	for w in weights: print(w, end=",\n")
	###############################################

	Smooth/Foggy:
	###############################################
	weights = [1 << x for x in range(7)]
	total = sum(weights)
	weights = [x / total for x in weights]
	for w in weights: print(w, end=",\n")
	###############################################

	Then just remove the last comma.

	For gaussian you can use my gaussian distribution generator 
	(https://github.com/luluco250/gaussian_gen) with the following command line:
	--> "gaussian_gen 7 7"
*/
static const float cBloomWeights[cBloomSteps] = {
	#if BLOOM_DISTRIBUTION == 1 // Detailed
	0.5039370078740157,
	0.25196850393700787,
	0.12598425196850394,
	0.06299212598425197,
	0.031496062992125984,
	0.015748031496062992,
	0.007874015748031496
	#elif BLOOM_DISTRIBUTION == 2 // Smooth
	0.007874015748031496,
	0.015748031496062992,
	0.031496062992125984,
	0.06299212598425197,
	0.12598425196850394,
	0.25196850393700787,
	0.5039370078740157
	#elif BLOOM_DISTRIBUTION == 3 // Gaussian
	0.056992,
	0.056413,
	0.054712,
	0.051991,
	0.048407,
	0.044159,
	0.039471
	#else // Normal
	0.14285714285714285,
	0.14285714285714285,
	0.14285714285714285,
	0.14285714285714285,
	0.14285714285714285,
	0.14285714285714285,
	0.14285714285714285
	#endif
};

  //========//
 //Uniforms//
//========//

float uDistribution <
	string UIName   = "Distribution";
	string UIWidget = "spinner";
	float  UIMin    = 1.0;
	float  UIMax    = 100.0;
> = 1.0;

  //========//
 //Textures//
//========//

Texture2D TextureDownsampled;
Texture2D TextureColor;
Texture2D TextureOriginal;
Texture2D TextureDepth;
Texture2D TextureAperture;
Texture2D RenderTarget1024;
Texture2D RenderTarget512;
Texture2D RenderTarget256;
Texture2D RenderTarget128;
Texture2D RenderTarget64;
Texture2D RenderTarget32;
Texture2D RenderTarget16;
Texture2D RenderTargetRGBA32;
Texture2D RenderTargetRGBA64F;

  //=========//
 //Functions//
//=========//

float3 box_blur(Texture2D tex, float2 uv, float2 ps) {
	return (tex.Sample(sLinear, uv - ps * 0.5).rgb +
			tex.Sample(sLinear, uv + ps * 0.5).rgb +
			tex.Sample(sLinear, uv + float2(-ps.x, ps.y) * 0.5).rgb +
			tex.Sample(sLinear, uv + float2( ps.x,-ps.y) * 0.5).rgb) * 0.25;
}

float get_weight(int i) {
	static const float weights[cGaussianSamples] = {
		0.017997,
		0.033159,
		0.054670,
		0.080657,
		0.106483,
		0.125794,
		0.132981,
		0.125794,
		0.106483,
		0.080657,
		0.054670,
		0.033159,
		0.017997
	};
	return weights[i];
}

float3 gaussian_blur(Texture2D tex, float2 uv, float2 dir) {
	float3 color = 0.0;
	uv -= dir * floor(cGaussianSamples * 0.5);

	[unroll]
	for (int i = 0; i < cGaussianSamples; ++i) {
		color += tex.Sample(sLinear, uv).rgb * get_weight(i);
		uv += dir;
	}

	return color;
}

  //=======//
 //Shaders//
//=======//

float4 PS_DownSample(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD,
	uniform Texture2D tex,
	uniform float size
) : SV_TARGET {
	float2 ps = uPixelSize * size;
	return float4(box_blur(tex, uv, ps), 1.0);
}

float4 PS_BlurX(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD,
	uniform Texture2D tex,
	uniform float size
) : SV_TARGET {
	float2 dir = float2(ScreenSize.y * size, 0.0);
	return float4(gaussian_blur(tex, uv, dir), 1.0);
}

float4 PS_BlurY(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD,
	uniform Texture2D tex,
	uniform float size
) : SV_TARGET {
	float2 dir = float2(0.0, ScreenSize.y * ScreenSize.z * size);
	return float4(gaussian_blur(tex, uv, dir), 1.0);
}

float4 PS_Blend(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 blooms[cBloomSteps] = {
		RenderTarget1024.Sample(sLinear, uv).rgb,
		RenderTarget512.Sample(sLinear, uv).rgb,
		RenderTarget256.Sample(sLinear, uv).rgb,
		RenderTarget128.Sample(sLinear, uv).rgb,
		RenderTarget64.Sample(sLinear, uv).rgb,
		RenderTarget32.Sample(sLinear, uv).rgb,
		RenderTarget16.Sample(sLinear, uv).rgb
	};

	float3 bloom = blooms[0] * gaussian(0, uDistribution); //cBloomWeights[0];
	[unroll]
	for (int i = 1; i < cBloomSteps; ++i)
		bloom += blooms[i] * gaussian(i, uDistribution); //* cBloomWeights[i];

	return float4(bloom, 1.0);
}

  //==========//
 //Techniques//
//==========//

technique11 Magic <string UIName = "Magic";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_DownSample(
			TextureDownsampled, 2.0
		)));
	}
}

technique11 Magic1 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurX(
			TextureColor, 2.0
		)));
	}
}

technique11 Magic2 <string RenderTarget = "RenderTarget1024";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurY(
			TextureColor, 2.0
		)));
	}
}

technique11 Magic3 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_DownSample(
			RenderTarget1024, 4.0
		)));
	}
}

technique11 Magic4 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurX(
			TextureColor, 4.0
		)));
	}
}

technique11 Magic5 <string RenderTarget = "RenderTarget512";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurY(
			TextureColor, 4.0
		)));
	}
}

technique11 Magic6 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_DownSample(
			RenderTarget512, 8.0
		)));
	}
}

technique11 Magic7 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurX(
			TextureColor, 8.0
		)));
	}
}

technique11 Magic8 <string RenderTarget = "RenderTarget256";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurY(
			TextureColor, 8.0
		)));
	}
}

technique11 Magic9 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_DownSample(
			RenderTarget256, 16.0
		)));
	}
}

technique11 Magic10 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurX(
			TextureColor, 16.0
		)));
	}
}

technique11 Magic11 <string RenderTarget = "RenderTarget128";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurY(
			TextureColor, 16.0
		)));
	}
}

technique11 Magic12 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_DownSample(
			RenderTarget128, 32.0
		)));
	}
}

technique11 Magic13 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurX(
			TextureColor, 32.0
		)));
	}
}

technique11 Magic14 <string RenderTarget = "RenderTarget64";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurY(
			TextureColor, 32.0
		)));
	}
}

technique11 Magic15 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_DownSample(
			RenderTarget64, 64.0
		)));
	}
}

technique11 Magic16 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurX(
			TextureColor, 64.0
		)));
	}
}

technique11 Magic17 <string RenderTarget = "RenderTarget32";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurY(
			TextureColor, 64.0
		)));
	}
}

technique11 Magic18 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_DownSample(
			RenderTarget32, 128.0
		)));
	}
}

technique11 Magic19 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurX(
			TextureColor, 128.0
		)));
	}
}

technique11 Magic20 <string RenderTarget = "RenderTarget16";> {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_BlurY(
			TextureColor, 128.0
		)));
	}
}

technique11 Magic21 {
	pass {
		SetVertexShader(CompileShader(vs_5_0, VS_PostProcess()));
		SetPixelShader(CompileShader(ps_5_0, PS_Blend()));
	}
}
