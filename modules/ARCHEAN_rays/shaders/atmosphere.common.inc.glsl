#include "common.inc.glsl"

AtmosphereData atmosphere = AtmosphereData(AABB.data);

bool AtmosphereIntersection(out float T1, out float T2, out bool inside) {
	if (uint64_t(atmosphere) == 0) return false;

	const vec3 spherePosition = gl_ObjectToWorldEXT[3].xyz;
	const float r = atmosphere.outerRadius;
	const vec3 oc = gl_WorldRayOriginEXT - spherePosition;
	const float a = dot(gl_WorldRayDirectionEXT, gl_WorldRayDirectionEXT);
	const float b = dot(oc, gl_WorldRayDirectionEXT);
	const float c = dot(oc, oc) - r*r;
	const float discriminantSqr = b * b - a * c;
	
	if (discriminantSqr >= 0) {
		const float det = sqrt(discriminantSqr);

		T1 = (-b - det) / a;
		T2 = (-b + det) / a;
		
		// Outside of sphere
		if (gl_RayTminEXT <= T1 && T1 <= gl_RayTmaxEXT) {
            inside = false;
            return true;
		}
		
		// Inside of sphere
		else if (T1 <= gl_RayTminEXT && T2 >= gl_RayTminEXT) {
            inside = true;
            return true;
		}
	}
    return false;
}
