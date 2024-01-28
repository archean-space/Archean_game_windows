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
		
		sphereAttr.t1 = (-b - discriminant) / a;
		sphereAttr.t2 = (-b + discriminant) / a;
		sphereAttr.radius = sphereRadius;
		
		// Outside of sphere
		if (gl_RayTminEXT <= sphereAttr.t1 && sphereAttr.t1 < gl_RayTmaxEXT) {
			reportIntersectionEXT(sphereAttr.t1, 0);
		}
		// Inside of sphere
		else if (sphereAttr.t1 <= gl_RayTminEXT && sphereAttr.t2 >= gl_RayTminEXT) {
			reportIntersectionEXT(sphereAttr.t2, 1);
		}
	}
	
	DEBUG_RAY_INT_TIME
}
