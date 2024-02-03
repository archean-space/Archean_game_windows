#define SHADER_RCHIT
#include "entity_propeller.common.inc.glsl"

void main() {
	vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	vec2 e = vec2(0.0001,0);
	vec3 normal = normalize(vec3(
		Sdf(pos+e.xyy) - Sdf(pos-e.xyy),
		Sdf(pos+e.yxy) - Sdf(pos-e.yxy),
		Sdf(pos+e.yyx) - Sdf(pos-e.yyx)
	));
	
	// Ray Payload
	ray.albedo = vec3(0.5);
	ray.t1 = gl_HitTEXT;
	ray.normal = normalize(MODEL2WORLDNORMAL * normal);
	ray.t2 = 0;
	ray.emission = vec3(0);
	ray.transmittance = vec3(0);
	ray.ior = 1.45;
	ray.reflectance = 0;
	ray.metallic = 0;
	ray.roughness = 1;
	ray.specular = 1;
	ray.localPosition = pos;
	ray.renderableIndex = gl_InstanceID;
	
	// Aim
	if (COORDS == ivec2(gl_LaunchSizeEXT.xy) / 2) {
		if (renderer.aim.aimID == 0) {
			renderer.aim.uv = surface.uv1;
			renderer.aim.localPosition = ray.localPosition;
			renderer.aim.geometryIndex = gl_GeometryIndexEXT;
			renderer.aim.aimID = gl_InstanceCustomIndexEXT;
			renderer.aim.worldSpaceHitNormal = ray.normal;
			renderer.aim.primitiveIndex = gl_PrimitiveID;
			renderer.aim.worldSpacePosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
			renderer.aim.hitDistance = ray.t1;
			renderer.aim.color = surface.color;
			renderer.aim.viewSpaceHitNormal = normalize(WORLD2VIEWNORMAL * ray.normal);
			renderer.aim.tlasInstanceIndex = gl_InstanceID;
		}
	}
	
	// Debug
	DEBUG_RAY_HIT_TIME
}
