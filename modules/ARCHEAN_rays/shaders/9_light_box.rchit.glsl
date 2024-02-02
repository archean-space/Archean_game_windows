#define SHADER_RCHIT
#include "common.inc.glsl"

hitAttributeEXT hit {
	float t2;
};

void main() {
	// ray.hitDistance = gl_HitTEXT;
	// ray.aimID = gl_InstanceCustomIndexEXT;
	// ray.renderableIndex = gl_InstanceID;
	// ray.geometryIndex = gl_GeometryIndexEXT;
	// ray.primitiveIndex = gl_PrimitiveID;
	// ray.localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	// ray.worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
	// ray.t2 = t2;
	// ray.ssao = 0;
	// ray.normal = vec3(0);
	// ray.color = vec4(0);
	// ray.plasma = vec4(GEOMETRY.material.emission, 0);
	
	// if (RAY_RECURSIONS < RAY_MAX_RECURSION) {
	// 	RAY_RECURSION_PUSH
	// 		RayPayload originalRay = ray;
	// 		ray.plasma = vec4(0);
	// 		vec3 bounceDirection = normalize(MODEL2WORLDNORMAL * vec3(0,-1,0));
	// 		float maxDistance = ray.localPosition.y - AABB_MIN.y;
	// 		traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_ENTITY, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, originalRay.worldPosition, 0, bounceDirection, maxDistance, 0);
	// 		if (ray.hitDistance == -1) {
	// 			ray = originalRay;
	// 		}
	// 	RAY_RECURSION_POP
	// }
}
