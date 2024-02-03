#define SHADER_RINT
#include "common.inc.glsl"

struct SphereAttr {
	float t1;
	float t2;
	float radius;
};

hitAttributeEXT SphereAttr sphereAttr;

void main() {

	// Ray-Sphere Intersection
	const vec3 spherePosition = (AABB_MAX + AABB_MIN) / 2;
	const float sphereRadius = (AABB_MAX.x - AABB_MIN.x) / 2;
	const vec3 oc = gl_ObjectRayOriginEXT - spherePosition;
	const float a = dot(gl_ObjectRayDirectionEXT, gl_ObjectRayDirectionEXT);
	const float b = dot(oc, gl_ObjectRayDirectionEXT);
	const float c = dot(oc, oc) - sphereRadius*sphereRadius;
	const float discriminantSqr = b * b - a * c;
	
	// If we hit the sphere
	if (discriminantSqr >= 0) {
		const float discriminant = sqrt(discriminantSqr);
		
		float T1 = (-b - discriminant) / a;
		float T2 = (-b + discriminant) / a;
		
		// Outside of sphere
		if (gl_RayTminEXT <= T1 && T1 < gl_RayTmaxEXT) {
			sphereAttr.t1 = T1;
			sphereAttr.t2 = T2;
			sphereAttr.radius = sphereRadius;
			reportIntersectionEXT(T1, 0);
		}
		// Inside of sphere
		else if (T1 <= gl_RayTminEXT && T2 >= gl_RayTminEXT) {
			sphereAttr.t1 = T1;
			sphereAttr.t2 = T2;
			sphereAttr.radius = sphereRadius;
			reportIntersectionEXT(T2, 1);
		}
	}
	
	DEBUG_RAY_INT_TIME
}
