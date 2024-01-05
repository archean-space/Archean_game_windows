#define SHADER_RMISS
#include "common.inc.glsl"

layout(location = 0) rayPayloadInEXT RayPayload ray;

void main() {
	// ray.normal = vec3(0);
	ray.hitDistance = -1;
	// ray.t2 = xenonRendererData.config.zFar;
	ray.aimID = 0;
	ray.renderableIndex = -1;
	ray.geometryIndex = -1;
	ray.primitiveIndex = -1;
	ray.color = vec4(0);
}
