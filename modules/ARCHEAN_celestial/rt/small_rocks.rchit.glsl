#define SHADER_RCHIT
#include "small_rocks.common.inc.glsl"

void main() {
	vec3 localPos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	vec3 pos = localPos - rockPos;
	float detailSize = GetDetailSize();
	vec2 e = vec2(epsilon,0);
	vec3 normal = normalize(vec3(
		Sdf(pos+e.xyy, detailSize, detailOctavesHighRes) - Sdf(pos-e.xyy, detailSize, detailOctavesHighRes),
		Sdf(pos+e.yxy, detailSize, detailOctavesHighRes) - Sdf(pos-e.yxy, detailSize, detailOctavesHighRes),
		Sdf(pos+e.yyx, detailSize, detailOctavesHighRes) - Sdf(pos-e.yyx, detailSize, detailOctavesHighRes)
	));
	uint seed_ = uint32_t(AABB.data);
	float rocky = pow(RandomFloat(seed_), 2);
	const vec3 sandColor = vec3(0.5, 0.4, 0.3);
	const vec3 rockColor = vec3(0.3);
	
	vec3 color = mix(sandColor, rockColor, rocky);
	color *= mix(0.5, 1.0, pow(abs(FastSimplexFractal(localPos*255.658, detailOctavesTextures)) + (FastSimplexFractal(localPos*29.123, detailOctavesTextures)*0.5+0.5), 0.5));
	color *= pow(normal.y * 0.5 + 0.5, 0.25);
	
	// Reverse gamma
	color = ReverseGamma(color);
	
	MakeAimable(normal, vec2(0), 0);
	
	RayHit(
		/*albedo*/		color,
		/*normal*/		normal,
		/*distance*/	gl_HitTEXT,
		/*roughness*/	1.0,
		/*ior*/			1.5,
		RAY_SURFACE_DIFFUSE
	);
}
