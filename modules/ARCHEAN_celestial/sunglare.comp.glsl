#include "sunglare.common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;

float GetAlpha(vec2 uv) {
	return clamp((
		+ step(0.9999, texture(sampler_resolved, uv).a)
		+ step(0.9999, textureLodOffset(sampler_resolved, uv, 0.0, ivec2( 1,  0)).a)
		+ step(0.9999, textureLodOffset(sampler_resolved, uv, 0.0, ivec2(-1,  0)).a)
		+ step(0.9999, textureLodOffset(sampler_resolved, uv, 0.0, ivec2( 0,  1)).a)
		+ step(0.9999, textureLodOffset(sampler_resolved, uv, 0.0, ivec2( 0, -1)).a)
		+ step(0.9999, textureLodOffset(sampler_resolved, uv, 0.0, ivec2( 1,  1)).a)
		+ step(0.9999, textureLodOffset(sampler_resolved, uv, 0.0, ivec2(-1, -1)).a)
		+ step(0.9999, textureLodOffset(sampler_resolved, uv, 0.0, ivec2( 1, -1)).a)
		+ step(0.9999, textureLodOffset(sampler_resolved, uv, 0.0, ivec2(-1,  1)).a)
	) / 9, 0, 1);
}

vec3 GetScreenCoord(in vec3 worldPosition) {
	vec4 clipSpace = xenonRendererData.config.projectionMatrix * viewMatrix * vec4(worldPosition, 1);
	clipSpace /= clipSpace.w;
	return vec3((clipSpace.xy * 0.5 + 0.5), clipSpace.z);
}

void main() {
	ivec2 compute_coord = ivec2(gl_GlobalInvocationID);
	ivec2 compute_size = ivec2(gl_WorkGroupSize * gl_NumWorkGroups);
	vec2 uv = vec2(compute_coord) / vec2(compute_size);
	
	vec3 sunDir = normalize(sunData.position);
	vec3 tangent = normalize(cross(sunDir, normalize(vec3(0.6514501,1.12695789,0.10847498))));
	vec3 bitangent = normalize(cross(sunDir, tangent));
	
	vec3 sunCenterScreenCoord = GetScreenCoord(sunData.position - sunDir * sunData.radius * 2);
	
	float alpha = 1 - pow(GetAlpha(sunCenterScreenCoord.xy), 8);
	if (sunCenterScreenCoord.x < 0 || sunCenterScreenCoord.x >= 1.0 || sunCenterScreenCoord.y < 0 || sunCenterScreenCoord.y >= 1.0 || sunCenterScreenCoord.z < 0 || alpha == 0) return;
	
	float lookingTowardsSun = 1 - pow(clamp(distance(vec2(0.5), sunCenterScreenCoord.xy)*2, 0, 1), 0.125);
	float nearCenterOfSun = 1 - clamp(distance(uv, sunCenterScreenCoord.xy), 0, 1);
	float glare = 1 - pow(clamp(distance(uv, sunCenterScreenCoord.xy), 0.005, 1), mix(0.1, 1, lookingTowardsSun));
	float flares = pow((
		+Simplex(vec3(vec2(normalize(uv - sunCenterScreenCoord.xy)*4),0))*0.5
		+Simplex(vec3(vec2(normalize(uv - sunCenterScreenCoord.xy)*16),0))*0.15
		+Simplex(vec3(vec2(normalize(uv - sunCenterScreenCoord.xy)*64),0))*0.15
	) * 0.5 + 0.5, 1 - pow(nearCenterOfSun, 0.25));
	
	vec3 sunColor = GetEmissionColor(sunData.temperature);
	ApplyToneMapping(sunColor);
	
	vec4 color = imageLoad(img_post, compute_coord);
	imageStore(img_post, compute_coord, vec4(mix(color.rgb, sunColor * alpha, glare * flares * alpha * smoothstep(0, 5, float(xenonRendererData.time))), color.a));
}
