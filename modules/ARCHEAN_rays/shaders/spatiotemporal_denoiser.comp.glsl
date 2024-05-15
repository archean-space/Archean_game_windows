#include "common.inc.glsl"

vec4 CompositeImageBlurred(in ivec2 coord, int kernelSize) {
	const ivec2 size = imageSize(img_post).xy;
	float accumulation = 0;
	vec4 color = vec4(0);
	for (int x = -kernelSize/2; x <= +kernelSize/2; ++x) {
		for (int y = -kernelSize/2; y <= +kernelSize/2; ++y) {
			ivec2 xy = coord + ivec2(x,y);
			if (xy.x < 0 || xy.y < 0 || xy.x >= size.x || xy.y >= size.y) continue;
			color += imageLoad(img_post, xy);
			++accumulation;
		}
	}
	return color / accumulation;
	// vec4 color = imageLoad(img_post, coord);
	// color += imageLoad(img_post, coord + ivec2(0,+1));
	// color += imageLoad(img_post, coord + ivec2(0,-1));
	// color += imageLoad(img_post, coord + ivec2(+1,0));
	// color += imageLoad(img_post, coord + ivec2(-1,0));
	// return color / 5;
}

vec4 GetVariance5(in sampler2D tex, in vec2 uv) {
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
	return sqrt(m2 - m1*m1);
}

vec4 GetNormalVariance5(in ivec2 coords) {
	vec4 nearColor0 = imageLoad(img_normal_or_debug, coords);
	vec4 nearColor1 = imageLoad(img_normal_or_debug, coords + ivec2( 1,  0));
	vec4 nearColor2 = imageLoad(img_normal_or_debug, coords + ivec2( 0,  1));
	vec4 nearColor3 = imageLoad(img_normal_or_debug, coords + ivec2(-1,  0));
	vec4 nearColor4 = imageLoad(img_normal_or_debug, coords + ivec2( 0, -1));
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
	return sqrt(m2 - m1*m1);
}

vec4 GetNormalVariance9(in ivec2 coords) {
	vec4 nearColor0 = imageLoad(img_normal_or_debug, coords);
	vec4 nearColor1 = imageLoad(img_normal_or_debug, coords + ivec2(+1,  0));
	vec4 nearColor2 = imageLoad(img_normal_or_debug, coords + ivec2( 0, +1));
	vec4 nearColor3 = imageLoad(img_normal_or_debug, coords + ivec2(-1,  0));
	vec4 nearColor4 = imageLoad(img_normal_or_debug, coords + ivec2( 0, -1));
	vec4 nearColor5 = imageLoad(img_normal_or_debug, coords + ivec2(-1, -1));
	vec4 nearColor6 = imageLoad(img_normal_or_debug, coords + ivec2(+1, -1));
	vec4 nearColor7 = imageLoad(img_normal_or_debug, coords + ivec2(-1, +1));
	vec4 nearColor8 = imageLoad(img_normal_or_debug, coords + ivec2(+1, +1));
	vec4 m1 = nearColor0
			+ nearColor1
			+ nearColor2
			+ nearColor3
			+ nearColor4
			+ nearColor5
			+ nearColor6
			+ nearColor7
			+ nearColor8
	; m1 /= 9;
	vec4 m2 = nearColor0*nearColor0
			+ nearColor1*nearColor1
			+ nearColor2*nearColor2
			+ nearColor3*nearColor3
			+ nearColor4*nearColor4
			+ nearColor5*nearColor5
			+ nearColor6*nearColor6
			+ nearColor7*nearColor7
			+ nearColor8*nearColor8
	; m2 /= 9;
	return sqrt(m2 - m1*m1);
}

vec4 GetColorVariance5(in ivec2 coords) {
	vec4 nearColor0 = imageLoad(img_primary_albedo_roughness, coords);
	vec4 nearColor1 = imageLoad(img_primary_albedo_roughness, coords + ivec2( 1,  0));
	vec4 nearColor2 = imageLoad(img_primary_albedo_roughness, coords + ivec2( 0,  1));
	vec4 nearColor3 = imageLoad(img_primary_albedo_roughness, coords + ivec2(-1,  0));
	vec4 nearColor4 = imageLoad(img_primary_albedo_roughness, coords + ivec2( 0, -1));
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
	return sqrt(m2 - m1*m1);
}

vec4 GetColorVariance9(in ivec2 coords) {
	vec4 nearColor0 = imageLoad(img_primary_albedo_roughness, coords);
	vec4 nearColor1 = imageLoad(img_primary_albedo_roughness, coords + ivec2(+1,  0));
	vec4 nearColor2 = imageLoad(img_primary_albedo_roughness, coords + ivec2( 0, +1));
	vec4 nearColor3 = imageLoad(img_primary_albedo_roughness, coords + ivec2(-1,  0));
	vec4 nearColor4 = imageLoad(img_primary_albedo_roughness, coords + ivec2( 0, -1));
	vec4 nearColor5 = imageLoad(img_primary_albedo_roughness, coords + ivec2(-1, -1));
	vec4 nearColor6 = imageLoad(img_primary_albedo_roughness, coords + ivec2(+1, -1));
	vec4 nearColor7 = imageLoad(img_primary_albedo_roughness, coords + ivec2(-1, +1));
	vec4 nearColor8 = imageLoad(img_primary_albedo_roughness, coords + ivec2(+1, +1));
	vec4 m1 = nearColor0
			+ nearColor1
			+ nearColor2
			+ nearColor3
			+ nearColor4
			+ nearColor5
			+ nearColor6
			+ nearColor7
			+ nearColor8
	; m1 /= 9;
	vec4 m2 = nearColor0*nearColor0
			+ nearColor1*nearColor1
			+ nearColor2*nearColor2
			+ nearColor3*nearColor3
			+ nearColor4*nearColor4
			+ nearColor5*nearColor5
			+ nearColor6*nearColor6
			+ nearColor7*nearColor7
			+ nearColor8*nearColor8
	; m2 /= 9;
	return sqrt(m2 - m1*m1);
}

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X + 1, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y + 1) in;

// bool ReprojectHistoryCoord(inout ivec2 coord) {
// 	coord = ivec2(round(vec2(coord) + imageLoad(img_motion, coord).rg * vec2(imageSize) * 0.5));
// 	return coord.x >= 0 && coord.x < imageSize.x && coord.y >= 0 && coord.y < imageSize.y;
// }

bool ReprojectHistoryUV(inout vec2 uv) {
	uv += texture(sampler_motion, uv).rg * 0.5;
	return uv.x > 0 && uv.x < 1 && uv.y > 0 && uv.y < 1;
}

vec3 VarianceClampPostImage(in vec3 color, in ivec2 coord) {
	vec3 nearColor0 = imageLoad(img_post, coord).rgb;
	vec3 nearColor1 = imageLoad(img_post, coord + ivec2( 1,  0)).rgb;
	vec3 nearColor2 = imageLoad(img_post, coord + ivec2( 0,  1)).rgb;
	vec3 nearColor3 = imageLoad(img_post, coord + ivec2(-1,  0)).rgb;
	vec3 nearColor4 = imageLoad(img_post, coord + ivec2( 0, -1)).rgb;
	vec3 m1 = nearColor0
			+ nearColor1
			+ nearColor2
			+ nearColor3
			+ nearColor4
	; m1 /= 5;
	vec3 m2 = nearColor0*nearColor0
			+ nearColor1*nearColor1
			+ nearColor2*nearColor2
			+ nearColor3*nearColor3
			+ nearColor4*nearColor4
	; m2 /= 5;
	vec3 sigma = sqrt(m2 - m1*m1);
	const float sigmaNoVarianceThreshold = 0.0001;
	if (abs(sigma.r) < sigmaNoVarianceThreshold || abs(sigma.g) < sigmaNoVarianceThreshold || abs(sigma.b) < sigmaNoVarianceThreshold) {
		return nearColor0;
	}
	vec3 boxMin = m1 - sigma;
	vec3 boxMax = m1 + sigma;
	return clamp(color, boxMin, boxMax);
}

// good values = 2-16 (1 = off)
#define TEMPORAL_ACCUMULATION 16
#define SPATIAL_ACCUMULATION 16

void main() {
	const ivec2 coords = ivec2(gl_GlobalInvocationID);
	const vec2 uv = vec2(coords) / imageSize(img_post);
	const ivec2 renderCoords = ivec2(round(uv*imageSize(img_normal_or_debug)));
	
	vec4 post = imageLoad(img_post, coords);
	float denoisingFactor = 0;
	
	if (post.a > 0.95) {
		float normalVariance = clamp(length(GetNormalVariance9(renderCoords).xyz)*4, 0, 1);
		float colorVariance = clamp(length(GetColorVariance9(renderCoords).rgb), 0, 1);
		float roughness = imageLoad(img_primary_albedo_roughness, renderCoords).a;
		denoisingFactor = 1.0 - clamp(normalVariance + colorVariance + (0.5-roughness), 0, 1);
		
		#if SPATIAL_ACCUMULATION > 1
			post.rgb = mix(post.rgb, CompositeImageBlurred(coords, SPATIAL_ACCUMULATION).rgb, denoisingFactor);
		#endif
		
		#if SPATIAL_ACCUMULATION > 1
			vec2 uvHistory = uv;
			if (ReprojectHistoryUV(uvHistory)) {
				vec3 history = imageLoad(img_post_history, ivec2(round(uvHistory * (vec2(imageSize(img_post_history)) + 0.5)))).rgb;
				history = VarianceClampPostImage(history, coords);
				post.rgb = mix(history, post.rgb, 1.0/TEMPORAL_ACCUMULATION);
			}
		#endif
	}

	// Debug
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_DENOISING_FACTOR) {
		imageStore(img_swapchain, coords, vec4(vec3(denoisingFactor), 1));
	} else {
		imageStore(img_swapchain, coords, vec4(post.rgb, post.a));
	}
}
