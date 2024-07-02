#define SHADER_RINT
#include "common.inc.glsl"

hitAttributeEXT hit {
	float t2;
};

void main() {
	AtmosphereData atmosphere = AtmosphereData(AABB.data);
	if (uint64_t(atmosphere) == 0) return;
	const vec3 spherePosition = gl_ObjectToWorldEXT[3].xyz;
	
	if (RAY_IS_SHADOW) {
		const float r = atmosphere.innerRadius;
		const vec3 oc = gl_WorldRayOriginEXT - spherePosition;
		const float a = dot(gl_WorldRayDirectionEXT, gl_WorldRayDirectionEXT);
		const float b = dot(oc, gl_WorldRayDirectionEXT);
		const float c = dot(oc, oc) - r*r;
		const float discriminantSqr = b * b - a * c;
		
		if (discriminantSqr >= 0) {
			const float det = sqrt(discriminantSqr);
			const float T1 = (-b - det) / a;
			const float T2 = (-b + det) / a;
			
			// Outside of sphere
			if (gl_RayTminEXT <= T1 && T1 < gl_RayTmaxEXT) {
				t2 = T2;
				reportIntersectionEXT(T1, 0);
			}
			
			// Inside of sphere
			if (T1 <= gl_RayTminEXT && T2 >= gl_RayTminEXT) {
				t2 = T2;
				reportIntersectionEXT(max(gl_RayTminEXT, 0), 1);
			}
		}
	} else {
		const float r = atmosphere.outerRadius;
		const vec3 oc = gl_WorldRayOriginEXT - spherePosition;
		const float a = dot(gl_WorldRayDirectionEXT, gl_WorldRayDirectionEXT);
		const float b = dot(oc, gl_WorldRayDirectionEXT);
		const float c = dot(oc, oc) - r*r;
		const float discriminantSqr = b * b - a * c;
		
		if (discriminantSqr >= 0) {
			const float det = sqrt(discriminantSqr);
			const float T1 = (-b - det) / a;
			const float T2 = (-b + det) / a;
			
			// Outside of sphere
			if (gl_RayTminEXT <= T1 && T1 < gl_RayTmaxEXT) {
				t2 = T2;
				reportIntersectionEXT(T1, 0);
			}
			
			// Inside of sphere
			if (T1 <= gl_RayTminEXT && T2 >= gl_RayTminEXT) {
				t2 = T2;
				reportIntersectionEXT(max(gl_RayTminEXT, ATMOSPHERE_RAY_MIN_DISTANCE), 1);
			}
		}
	}
	DEBUG_RAY_INT_TIME
}
