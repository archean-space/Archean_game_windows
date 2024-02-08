#define SHADER_RCHIT
#include "entity_propeller.common.inc.glsl"
#include "lighting.inc.glsl"

void main() {
	ray.hitDistance = gl_HitTEXT;
	ray.t2 = 0;
	ray.aimID = gl_InstanceCustomIndexEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	ray.ssao = 1;
	ray.color.a = 1;
	
	vec3 pos = ray.localPosition;
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
	
	// Apply Lighting
	ApplyDefaultLighting();
	
	// Store albedo and roughness (may remove this in the future)
	if (RAY_RECURSIONS == 0) {
		imageStore(img_primary_albedo_roughness, COORDS, vec4(surface.color.rgb, surface.roughness));
	}
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
