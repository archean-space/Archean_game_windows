#define SHADER_RINT
#include "game/graphics/common.inc.glsl"

hitAttributeEXT hit {
	float t2;
};

void main() {
	if (PlasmaData(AABB.data).density > 0.0) {
		COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
		if RAY_STARTS_OUTSIDE_T1_T2 {
			t2 = T2;
			reportIntersectionEXT(T1, 0);
		} else if RAY_STARTS_BETWEEN_T1_T2 {
			t2 = T2;
			reportIntersectionEXT(gl_RayTminEXT, 1);
		}
	}
}
