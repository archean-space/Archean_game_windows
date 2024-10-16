#define SHADER_RINT
#include "common.inc.glsl"

hitAttributeEXT hit {
	float t1;
	float t2;
};

void main() {
	COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
	if RAY_STARTS_OUTSIDE_T1_T2 {
		t1 = T1;
		t2 = T2;
		reportIntersectionEXT(T1, 0);
	} else if RAY_STARTS_BETWEEN_T1_T2 {
		t1 = T1;
		t2 = T2;
		reportIntersectionEXT(gl_RayTminEXT, 1);
	}
	DEBUG_RAY_INT_TIME
}
