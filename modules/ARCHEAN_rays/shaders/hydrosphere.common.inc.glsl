#include "common.inc.glsl"

WaterData water = WaterData(AABB.data);

bool HydrosphereIntersection(out float T1, out float T2, out bool inside) {
	if (uint64_t(water) == 0) return false;

	const double r = water.radius + double( sin(float(double(renderer.timestamp*1.06))) + sin(float(double(renderer.timestamp*4.25))) + sin(float(double(renderer.timestamp*1.895))) ) * 0.01;
	
	const dvec3 oc = dvec3(gl_WorldRayOriginEXT) - water.center;
	const dvec3 dir = dvec3(gl_WorldRayDirectionEXT);
	const double a = dot(dir, dir);
	const double b = dot(oc, dir);
	const double c = dot(oc, oc) - r*r;
	const double discriminantSqr = b * b - a * c;
	
	if (discriminantSqr >= 0) {
		const double det = double(sqrt(discriminantSqr));
		
		T1 = float((-b - det) / a);
		T2 = float((-b + det) / a);
		
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
