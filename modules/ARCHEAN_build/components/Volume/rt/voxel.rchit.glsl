#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"
#include "../../../common.inc.glsl"

void main() {
	
	vec3 normal = ComputeSurfaceNormal(gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT);
	float ior = 1.01;
	AutoFlipNormal(normal, ior);
	ior = 1.01;
	
	RayHit(
		/*albedo*/		vec3(0.2,0.4,0.8),
		/*normal*/		normal,
		/*distance*/	gl_HitTEXT,
		/*roughness*/	0,
		/*ior*/			ior,
		/*flags*/		RAY_SURFACE_DIFFUSE
	);
	
}
