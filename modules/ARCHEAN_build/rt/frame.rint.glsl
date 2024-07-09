#define SHADER_RINT
#include "game/graphics/common.inc.glsl"

void main() {
	COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
	if RAY_STARTS_OUTSIDE_T1_T2 {
		reportIntersectionEXT(T1, 0);
	} else if RAY_STARTS_BETWEEN_T1_T2 {
		reportIntersectionEXT(T2, 1);
	}
}
