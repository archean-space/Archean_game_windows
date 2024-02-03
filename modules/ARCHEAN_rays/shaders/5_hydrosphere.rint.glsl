#define SHADER_RINT
#include "hydrosphere.common.inc.glsl"

void main() {
	float T1;
	float T2;
	bool inside;
	if (HydrosphereIntersection(T1, T2, inside)) {
		if (inside) {
			reportIntersectionEXT(gl_RayTminEXT, 1);
		} else {
			reportIntersectionEXT(T1, 0);
		}
	}
	DEBUG_RAY_INT_TIME
}
