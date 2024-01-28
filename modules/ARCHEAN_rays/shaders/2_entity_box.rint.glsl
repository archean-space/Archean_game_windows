#define SHADER_RINT
#include "common.inc.glsl"

void main() {
	COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
	if RAY_STARTS_OUTSIDE_T1_T2 {
		reportIntersectionEXT(T1, 0);
	}
	DEBUG_RAY_INT_TIME
}
