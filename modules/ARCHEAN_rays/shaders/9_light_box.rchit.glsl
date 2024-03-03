#define SHADER_RCHIT
#include "common.inc.glsl"

hitAttributeEXT hit {
	float t2;
};

void main() {
	ray.hitDistance = gl_HitTEXT;
	ray.renderableIndex = gl_InstanceID;
	ray.geometryIndex = gl_GeometryIndexEXT;
	ray.primitiveIndex = gl_PrimitiveID;
	ray.t2 = t2;
	ray.normal = vec3(0);
	ray.color = vec4(0);
	ray.emission += GEOMETRY.material.emission;
	
	if (RAY_RECURSIONS < RAY_MAX_RECURSION) {
		RAY_RECURSION_PUSH
			vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
			vec3 worldPosition = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * gl_HitTEXT;
			RayPayload originalRay = ray;
			vec3 bounceDirection = normalize(MODEL2WORLDNORMAL * vec3(0,-1,0));
			float maxDistance = localPosition.y - AABB_MIN.y;
			traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_ENTITY, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, worldPosition, 0, bounceDirection, maxDistance, 0);
			if (ray.hitDistance == -1) {
				ray = originalRay;
			}
		RAY_RECURSION_POP
	}
}
