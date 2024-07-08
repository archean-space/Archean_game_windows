#define SHADER_RINT
#include "propeller.common.inc.glsl"

void main() {
	float t = 0.0;
	for(int i = 0; i < 256; i++) {
		vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * t;
		float d = Sdf(pos);
		if (abs(d) < 0.0001 || t > gl_RayTmaxEXT) break;
		t += d * 0.5;
	}
	if (t < gl_RayTmaxEXT) {
		reportIntersectionEXT(max(gl_RayTminEXT, t), 0);
	}
}
