#define SHADER_RINT
#include "../common.inc.glsl"

hitAttributeEXT hit {
	float t1;
	float t2;
};

void main() {
	WaterData water = WaterData(AABB.data);
	if (uint64_t(water) == 0) return;
	
	const double r = water.radius + double( sin(float(double(renderer.timestamp*1.06))) + sin(float(double(renderer.timestamp*4.25))) + sin(float(double(renderer.timestamp*1.895))) ) * 0.01;
	
	const dvec3 oc = dvec3(gl_WorldRayOriginEXT) - water.center;
	const dvec3 dir = dvec3(gl_WorldRayDirectionEXT);
	const double b = dot(oc, dir);
	const double discriminantSqr = b * b - dot(oc, oc) + r*r;
	
	if (discriminantSqr >= 0) {
		const double det = double(sqrt(discriminantSqr));
		const double T1 = double(-b - det);
		const double T2 = double(-b + det);
		
		// Solid rays
		if ((gl_IncomingRayFlagsEXT & gl_RayFlagsOpaqueEXT) != 0) {
			// Outside of sphere
			if (gl_RayTminEXT <= T1 && T1 <= gl_RayTmaxEXT) {
				t1 = float(T1);
				t2 = float(T2);
				reportIntersectionEXT(float(T1), 0);
			}
			// Inside of sphere
			if (T1 <= gl_RayTminEXT && T2 >= gl_RayTminEXT) {
				t1 = float(T1);
				t2 = float(T2);
				reportIntersectionEXT(float(T2), 1);
			}
		}
		// Fog and Shadow rays
		if ((gl_IncomingRayFlagsEXT & gl_RayFlagsNoOpaqueEXT) != 0) {
			// Inside of sphere
			if (T1 <= gl_RayTminEXT && T2 >= gl_RayTminEXT) {
				t1 = float(T1);
				t2 = float(T2);
				reportIntersectionEXT(gl_RayTminEXT, 1);
			}
		}
	}
}
