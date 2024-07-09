#define SHADER_RCHIT
#include "propeller.common.inc.glsl"

void main() {
	vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	vec2 e = vec2(0.0001,0);
	vec3 normal = normalize(vec3(
		Sdf(pos+e.xyy) - Sdf(pos-e.xyy),
		Sdf(pos+e.yxy) - Sdf(pos-e.yxy),
		Sdf(pos+e.yyx) - Sdf(pos-e.yyx)
	));
	
	// Reverse gamma
	vec3 color = ReverseGamma(vec3(0.5));
	
	MakeAimable(normal, vec2(0), 0);
	
	uint8_t flags = RAY_SURFACE_DIFFUSE;
	RayHit(
		/*albedo*/		color,
		/*normal*/		normal,
		/*distance*/	gl_HitTEXT,
		/*roughness*/	1,
		/*ior*/			1.45,
		/*flags*/		RAY_SURFACE_DIFFUSE
	);
}
