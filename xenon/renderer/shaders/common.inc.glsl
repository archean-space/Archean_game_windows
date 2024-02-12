#include "xenon/graphics/interface.inc.glsl"
#ifdef __cplusplus
	#pragma once
	using namespace glm;
#endif

// up to 32 render options
#define RENDER_OPTION_TONE_MAPPING (1u<< 0)
#define RENDER_OPTION_TAA (1u<< 1)
#define RENDER_OPTION_TEMPORAL_UPSCALING (1u<< 2)
#define RENDER_OPTION_GROUND_TRUTH (1u<< 3)
#define RENDER_OPTION_DITHERING (1u<< 4)

// Debug view modes
#define RENDER_DEBUG_VIEWMODE_NONE 0

struct XenonRendererConfig {
	aligned_f32mat4 projectionMatrix;
	aligned_f32mat4 projectionMatrixWithTAA;
	aligned_float32_t renderScale;
	aligned_float32_t zNear;
	aligned_float32_t zFar;
	aligned_float32_t cameraFov;
	aligned_float32_t smoothFov;
	aligned_uint32_t debugViewMode;
	aligned_float32_t debugViewScale;
	aligned_uint32_t options;
	aligned_float32_t brightness;
	aligned_float32_t contrast;
	aligned_float32_t gamma;
	// Tone Mapping
	aligned_float32_t minExposure;
	aligned_float32_t maxExposure;
	
	aligned_float32_t _unused1;
	aligned_float32_t _unused2;
	aligned_float32_t _unused3;
	
	#ifdef __cplusplus
		XenonRendererConfig()
		: renderScale(1.0f)
		, zNear(0.001f) // 1 mm
		, zFar(1e13f) // 10 billion km
		, cameraFov(80)
		, smoothFov(80)
		, debugViewMode(RENDER_DEBUG_VIEWMODE_NONE)
		, debugViewScale(1.0f)
		, options(0)
		, brightness(1.0f)
		, contrast(1.0f)
		, gamma(1.0f)
		, minExposure(0.0001f)
		, maxExposure(1.0f)
		{}
	#endif
};
STATIC_ASSERT_ALIGNED16_SIZE(XenonRendererConfig, 64*2 + 16*4)

BUFFER_REFERENCE_STRUCT(16) HistogramTotalLuminance {
	aligned_float32_t r;
	aligned_float32_t g;
	aligned_float32_t b;
	aligned_float32_t a;
};

struct XenonRendererData {
	aligned_f32vec4 histogram_avg_luminance;
	BUFFER_REFERENCE_ADDR(HistogramTotalLuminance) histogram_total_luminance;
	aligned_uint64_t frameIndex;
	aligned_float64_t time;
	aligned_float64_t deltaTime;
	XenonRendererConfig config;
};
STATIC_ASSERT_ALIGNED16_SIZE(XenonRendererData, 16 + 8*4 + sizeof(XenonRendererConfig))

struct FSRPushConstant {
	aligned_u32vec4 Const0;
	aligned_u32vec4 Const1;
	aligned_u32vec4 Const2;
	aligned_u32vec4 Const3;
	aligned_u32vec4 Sample;
};
STATIC_ASSERT_SIZE(FSRPushConstant, 80)

#define XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X 8
#define XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y 8
#define XENON_RENDERER_HISTOGRAM_DIVIDER 2

#define XENON_RENDERER_TEXTURE_INDEX_T uint16_t
#define XENON_RENDERER_MAX_TEXTURES 65536
#define XENON_RENDERER_TAA_SAMPLES 16
#define XENON_RENDERER_THUMBNAIL_SCALE 16

#define XENON_RENDERER_SET0_IMG_SWAPCHAIN 0
#define XENON_RENDERER_SET0_IMG_POST 1
#define XENON_RENDERER_SET0_IMG_RESOLVED 2
#define XENON_RENDERER_SET0_IMG_HISTORY 3
#define XENON_RENDERER_SET0_IMG_THUMBNAIL 4
#define XENON_RENDERER_SET0_IMG_COMPOSITE 5
#define XENON_RENDERER_SET0_IMG_DEPTH 6
#define XENON_RENDERER_SET0_IMG_MOTION 7
#define XENON_RENDERER_SET0_IMG_NORMAL_OR_DEBUG 8
#define XENON_RENDERER_SET0_SAMPLER_HISTORY 9
#define XENON_RENDERER_SET0_SAMPLER_COMPOSITE 10
#define XENON_RENDERER_SET0_SAMPLER_DEPTH 11
#define XENON_RENDERER_SET0_SAMPLER_MOTION 12
#define XENON_RENDERER_SET0_SAMPLER_RESOLVED 13
#define XENON_RENDERER_SET0_RENDERER_DATA 14
#define XENON_RENDERER_SET0_TEXTURES 15

#ifdef GLSL
	
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_SWAPCHAIN, rgba8) uniform image2D img_swapchain;
	
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_POST, rgba8) uniform image2D img_post;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_RESOLVED, rgba32f) uniform image2D img_resolved;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_HISTORY, rgba32f) uniform image2D img_history;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_THUMBNAIL, rgba32f) uniform image2D img_thumbnail;
	
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_COMPOSITE, rgba32f) uniform image2D img_composite;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_DEPTH, r32f) uniform image2D img_depth;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_MOTION, rgba32f) uniform image2D img_motion;
	layout(set = 0, binding = XENON_RENDERER_SET0_IMG_NORMAL_OR_DEBUG, rgba32f) uniform image2D img_normal_or_debug;
	
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_HISTORY) uniform sampler2D sampler_history;
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_COMPOSITE) uniform sampler2D sampler_composite;
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_DEPTH) uniform sampler2D sampler_depth;
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_MOTION) uniform sampler2D sampler_motion;
	layout(set = 0, binding = XENON_RENDERER_SET0_SAMPLER_RESOLVED) uniform sampler2D sampler_resolved;
	
	layout(set = 0, binding = XENON_RENDERER_SET0_RENDERER_DATA, std430) uniform XenonRendererDataStorageBuffer {
		XenonRendererData xenonRendererData;
	};
	
	layout(set = 0, binding = XENON_RENDERER_SET0_TEXTURES) uniform sampler2D textures[];
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////
	// Helper Functions
	
	vec3 ApplyGamma(in vec3 color, in float gamma) {
		return pow(color, vec3(1.0 / gamma));
	}
	
	vec3 ApplyGamma(in vec3 color) {
		return ApplyGamma(color, xenonRendererData.config.gamma);
	}
	
	vec3 ReverseGamma(in vec3 color, in float gamma) {
		return pow(color, vec3(gamma));
	}
	
	vec3 ReverseGamma(in vec3 color) {
		return ReverseGamma(color, xenonRendererData.config.gamma);
	}
	
	void ApplyToneMapping(inout vec3 color) {
		// HDR ToneMapping (Reinhard)
		if ((xenonRendererData.config.options & RENDER_OPTION_TONE_MAPPING) != 0) {
			float lumRgbTotal = xenonRendererData.histogram_avg_luminance.r + xenonRendererData.histogram_avg_luminance.g + xenonRendererData.histogram_avg_luminance.b;
			float exposure = lumRgbTotal > 0 ? xenonRendererData.histogram_avg_luminance.a / lumRgbTotal : 1;
			color.rgb = vec3(1.0) - exp(-color.rgb * clamp(exposure, xenonRendererData.config.minExposure, xenonRendererData.config.maxExposure));
		}
		
		// Contrast / Brightness
		if (xenonRendererData.config.contrast != 1.0 || xenonRendererData.config.brightness != 1.0) {
			color.rgb = mix(vec3(0.5), color.rgb, xenonRendererData.config.contrast) * xenonRendererData.config.brightness;
		}
		
		// Gamma correction
		color.rgb = ApplyGamma(color.rgb);
	}

	float Fresnel(const vec3 incident, const vec3 normal, const float indexOfRefraction) {
		float cosi = clamp(dot(incident, normal), -1, 1);
		float etai;
		float etat;
		if (cosi > 0) {
			etat = 1;
			etai = indexOfRefraction;
		} else {
			etai = 1;
			etat = indexOfRefraction;
		}
		// Compute sini using Snell's law
		float sint = etai / etat * sqrt(max(0.0, 1.0 - cosi * cosi));
		if (sint >= 1) {
			// Total internal reflection
			return 1.0;
		} else {
			float cost = sqrt(max(0.0, 1.0 - sint * sint));
			cosi = abs(cosi);
			float Rs = ((etat * cosi) - (etai * cost)) / ((etat * cosi) + (etai * cost));
			float Rp = ((etai * cosi) - (etat * cost)) / ((etai * cosi) + (etat * cost));
			return (Rs * Rs + Rp * Rp) / 2;
		}
	}

	bool Refract(inout vec3 rayDirection, in vec3 surfaceNormal, in float iOR) {
		const float vDotN = dot(rayDirection, surfaceNormal);
		const float niOverNt = vDotN > 0 ? iOR : 1.0 / iOR;
		vec3 dir = rayDirection;
		rayDirection = refract(rayDirection, -sign(vDotN) * surfaceNormal, niOverNt);
		if (dot(rayDirection,rayDirection) > 0) {
			rayDirection = normalize(rayDirection);
			return true;
		} else {
			rayDirection = normalize(reflect(dir, -sign(vDotN) * surfaceNormal));
		}
		return false;
	}

	vec3 Heatmap(float t) {
		if (t < 0) return vec3(0);
		if (t > 1) return vec3(1);
		const vec3 c[10] = {
			vec3(0.0f / 255.0f,   2.0f / 255.0f,  91.0f / 255.0f),
			vec3(0.0f / 255.0f, 108.0f / 255.0f, 251.0f / 255.0f),
			vec3(0.0f / 255.0f, 221.0f / 255.0f, 221.0f / 255.0f),
			vec3(51.0f / 255.0f, 221.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 252.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 180.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 104.0f / 255.0f,   0.0f / 255.0f),
			vec3(226.0f / 255.0f,  22.0f / 255.0f,   0.0f / 255.0f),
			vec3(191.0f / 255.0f,   0.0f / 255.0f,  83.0f / 255.0f),
			vec3(145.0f / 255.0f,   0.0f / 255.0f,  65.0f / 255.0f)
		};

		const float s = t * 10.0f;

		const int cur = int(s) <= 9 ? int(s) : 9;
		const int prv = cur >= 1 ? cur - 1 : 0;
		const int nxt = cur < 9 ? cur + 1 : 9;

		const float blur = 0.8f;

		const float wc = smoothstep(float(cur) - blur, float(cur) + blur, s) * (1.0f - smoothstep(float(cur + 1) - blur, float(cur + 1) + blur, s));
		const float wp = 1.0f - smoothstep(float(cur) - blur, float(cur) + blur, s);
		const float wn = smoothstep(float(cur + 1) - blur, float(cur + 1) + blur, s);

		const vec3 r = wc * c[cur] + wp * c[prv] + wn * c[nxt];
		return vec3(clamp(r.x, 0.0f, 1.0f), clamp(r.y, 0.0f, 1.0f), clamp(r.z, 0.0f, 1.0f));
	}

	vec3 HeatmapClamped(float t) {
		if (t <= 0) return vec3(0);
		if (t >= 1) return vec3(1);
		const vec3 c[10] = {
			vec3(0.0f / 255.0f,   2.0f / 255.0f,  91.0f / 255.0f),
			vec3(0.0f / 255.0f, 108.0f / 255.0f, 251.0f / 255.0f),
			vec3(0.0f / 255.0f, 221.0f / 255.0f, 221.0f / 255.0f),
			vec3(51.0f / 255.0f, 221.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 252.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 180.0f / 255.0f,   0.0f / 255.0f),
			vec3(255.0f / 255.0f, 104.0f / 255.0f,   0.0f / 255.0f),
			vec3(226.0f / 255.0f,  22.0f / 255.0f,   0.0f / 255.0f),
			vec3(191.0f / 255.0f,   0.0f / 255.0f,  83.0f / 255.0f),
			vec3(145.0f / 255.0f,   0.0f / 255.0f,  65.0f / 255.0f)
		};

		const float s = t * 10.0f;

		const int cur = int(s) <= 9 ? int(s) : 9;
		const int prv = cur >= 1 ? cur - 1 : 0;
		const int nxt = cur < 9 ? cur + 1 : 9;

		const float blur = 0.8f;

		const float wc = smoothstep(float(cur) - blur, float(cur) + blur, s) * (1.0f - smoothstep(float(cur + 1) - blur, float(cur + 1) + blur, s));
		const float wp = 1.0f - smoothstep(float(cur) - blur, float(cur) + blur, s);
		const float wn = smoothstep(float(cur + 1) - blur, float(cur + 1) + blur, s);

		const vec3 r = wc * c[cur] + wp * c[prv] + wn * c[nxt];
		return vec3(clamp(r.x, 0.0f, 1.0f), clamp(r.y, 0.0f, 1.0f), clamp(r.z, 0.0f, 1.0f));
	}
	
	#define PI 3.141592654

	float gaussian(float x, float sigma) {
		return exp(-(x * x) / (2 * sigma * sigma)) / (sqrt(2 * PI) * sigma);
	}

	vec4 VarianceClamp5(in vec4 color, in sampler2D tex, in vec2 uv) {
		vec4 nearColor0 = texture(tex, uv);
		vec4 nearColor1 = textureLodOffset(tex, uv, 0.0, ivec2( 1,  0));
		vec4 nearColor2 = textureLodOffset(tex, uv, 0.0, ivec2( 0,  1));
		vec4 nearColor3 = textureLodOffset(tex, uv, 0.0, ivec2(-1,  0));
		vec4 nearColor4 = textureLodOffset(tex, uv, 0.0, ivec2( 0, -1));
		vec4 m1 = nearColor0
				+ nearColor1
				+ nearColor2
				+ nearColor3
				+ nearColor4
		; m1 /= 5;
		vec4 m2 = nearColor0*nearColor0
				+ nearColor1*nearColor1
				+ nearColor2*nearColor2
				+ nearColor3*nearColor3
				+ nearColor4*nearColor4
		; m2 /= 5;
		vec4 sigma = sqrt(m2 - m1*m1);
		vec4 boxMin = m1 - sigma;
		vec4 boxMax = m1 + sigma;
		return clamp(color, boxMin, boxMax);
	}

	//////////////////////////////////////
	// Random

	#extension GL_EXT_control_flow_attributes : require
	// Generates a seed for a random number generator from 2 inputs plus a backoff
	// https://github.com/nvpro-samples/optix_prime_baking/blob/332a886f1ac46c0b3eea9e89a59593470c755a0e/random.h
	// https://github.com/nvpro-samples/vk_raytracing_tutorial_KHR/tree/master/ray_tracing_jitter_cam
	// https://en.wikipedia.org/wiki/Tiny_Encryption_Algorithm
	uint InitRandomSeed(uint val0, uint val1) {
		uint v0 = val0, v1 = val1, s0 = 0;
		[[unroll]]
		for (uint n = 0; n < 16; n++) {
			s0 += 0x9e3779b9;
			v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
			v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
		}
		return v0;
	}
	uint RandomInt(inout uint seed) {
		return (seed = 1664525 * seed + 1013904223);
	}
	float RandomFloat(inout uint seed) {
		return (float(RandomInt(seed) & 0x00FFFFFF) / float(0x01000000));
	}
	vec2 RandomInUnitDisk(inout uint seed) {
		for (;;) {
			const vec2 p = 2 * vec2(RandomFloat(seed), RandomFloat(seed)) - 1;
			if (dot(p, p) < 1) {
				return p;
			}
		}
	}
	vec3 RandomInUnitSphere(inout uint seed) {
		for (;;) {
			const vec3 p = 2 * vec3(RandomFloat(seed), RandomFloat(seed), RandomFloat(seed)) - 1;
			if (dot(p, p) < 1) {
				return p;
			}
		}
	}
	vec3 RandomInUnitHemiSphere(inout uint seed, in vec3 normal) {
		for (;;) {
			const vec3 p = 2 * vec3(RandomFloat(seed), RandomFloat(seed), RandomFloat(seed)) - 1;
			if (dot(p, p) < 1 && dot(p, normal) > 0) {
				return p;
			}
		}
	}
	
	///////////////////////////////////////////////////////////////////////////////////////////////////////
	// Simplex Noise
	
	vec4 _permute(vec4 x){return mod(((x*34.0)+1.0)*x, 289.0);} // used for Simplex
	dvec4 _permute(dvec4 x){return mod(((x*34.0)+1.0)*x, 289.0);} // used for Simplex
	// simple-precision Simplex noise, suitable for pos range (-1M, +1M) with a step of 0.001 and gradient of 1.0
	// Returns a float value between -1.000 and +1.000 with a distribution that strongly tends towards the center (0.5)
	float Simplex(vec3 pos){
		const vec2 C = vec2(1.0/6.0, 1.0/3.0);
		const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

		vec3 i = floor(pos + dot(pos, C.yyy));
		vec3 x0 = pos - i + dot(i, C.xxx);

		vec3 g = step(x0.yzx, x0.xyz);
		vec3 l = 1.0 - g;
		vec3 i1 = min( g.xyz, l.zxy);
		vec3 i2 = max( g.xyz, l.zxy);

		vec3 x1 = x0 - i1 + 1.0 * C.xxx;
		vec3 x2 = x0 - i2 + 2.0 * C.xxx;
		vec3 x3 = x0 - 1. + 3.0 * C.xxx;

		i = mod(i, 289.0); 
		vec4 p = _permute(_permute(_permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));

		float n_ = 1.0/7.0;
		vec3  ns = n_ * D.wyz - D.xzx;

		vec4 j = p - 49.0 * floor(p * ns.z *ns.z);

		vec4 x_ = floor(j * ns.z);
		vec4 y_ = floor(j - 7.0 * x_);

		vec4 x = x_ *ns.x + ns.yyyy;
		vec4 y = y_ *ns.x + ns.yyyy;
		vec4 h = 1.0 - abs(x) - abs(y);

		vec4 b0 = vec4(x.xy, y.xy);
		vec4 b1 = vec4(x.zw, y.zw);

		vec4 s0 = floor(b0)*2.0 + 1.0;
		vec4 s1 = floor(b1)*2.0 + 1.0;
		vec4 sh = -step(h, vec4(0.0));

		vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy;
		vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;

		vec3 p0 = vec3(a0.xy,h.x);
		vec3 p1 = vec3(a0.zw,h.y);
		vec3 p2 = vec3(a1.xy,h.z);
		vec3 p3 = vec3(a1.zw,h.w);

		vec4 norm = 1.79284291400159 - 0.85373472095314 * vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3));
		p0 *= norm.x;
		p1 *= norm.y;
		p2 *= norm.z;
		p3 *= norm.w;

		vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
		return 42.0 * dot(m*m*m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
	}
	float SimplexFractal(vec3 pos, int octaves) {
		float amplitude = 0.533333333333333;
		float frequency = 1.0;
		float f = Simplex(pos * frequency);
		for (int i = 1; i < octaves; ++i) {
			amplitude /= 2.0;
			frequency *= 2.0;
			f += amplitude * Simplex(pos * frequency);
		}
		return f;
	}

	#define APPLY_NORMAL_BUMP_NOISE(_noiseFunc, _position, _normal, _waveHeight) {\
		vec3 _tangentX = normalize(cross(normalize(vec3(0.356,1.2145,0.24537))/* fixed arbitrary vector in object space */, _normal));\
		vec3 _tangentY = normalize(cross(_normal, _tangentX));\
		mat3 _TBN = mat3(_tangentX, _tangentY, _normal);\
		float _altitudeTop = _noiseFunc(_position + _tangentY*_waveHeight);\
		float _altitudeBottom = _noiseFunc(_position - _tangentY*_waveHeight);\
		float _altitudeRight = _noiseFunc(_position + _tangentX*_waveHeight);\
		float _altitudeLeft = _noiseFunc(_position - _tangentX*_waveHeight);\
		vec3 _bump = normalize(vec3((_altitudeRight-_altitudeLeft), (_altitudeBottom-_altitudeTop), 2));\
		_normal = normalize(_TBN * _bump);\
	}

#endif
