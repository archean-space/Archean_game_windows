#define SHADER_RCHIT
#include "entity_propeller.common.inc.glsl"
#include "lighting.inc.glsl"

void main() {
	uint rayRecursions = RAY_RECURSIONS;
	
	ray.hitDistance = gl_HitTEXT;
	ray.t2 = 0;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.ssao = 1;
	ray.color.a = 1;
	
	if (RAY_IS_SHADOW) {
		return;
	}
	
	vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	vec2 e = vec2(0.0001,0);
	vec3 normal = normalize(vec3(
		Sdf(pos+e.xyy) - Sdf(pos-e.xyy),
		Sdf(pos+e.yxy) - Sdf(pos-e.yxy),
		Sdf(pos+e.yyx) - Sdf(pos-e.yyx)
	));
	surface.color.rgb = vec3(0.5);
	surface.normal = normal;
	surface.metallic = 0;
	surface.roughness = 1;
	surface.emission = vec3(0);
	surface.ior = 1.45;
	surface.specular = 1;
	
	// Apply world space normal
	ray.normal = normalize(MODEL2WORLDNORMAL * surface.normal);
	
	// Reverse gamma
	surface.color.rgb = ReverseGamma(surface.color.rgb);
	
	// Aim
	MakeAimable();

	// Write Motion Vectors
	WriteMotionVectorsAndDepth(ray.renderableIndex, gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT, gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT, ray.hitDistance, false);
	
	// Apply Lighting
	ApplyDefaultLighting();
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
