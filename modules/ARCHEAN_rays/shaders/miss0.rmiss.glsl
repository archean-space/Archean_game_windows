#define SHADER_RMISS
#include "common.inc.glsl"

layout(location = 0) rayPayloadInEXT RayPayload ray;

void main() {
	ray.albedo = vec3(0);
	ray.t1 = -1;
	ray.normal = -gl_WorldRayDirectionEXT;
	ray.t2 = -1;
	ray.emission = vec3(0);
	ray.transmittance = vec3(1);
	ray.ior = 1;
	ray.reflectance = 0;
	ray.metallic = 0;
	ray.roughness = 0;
	ray.specular = 0;
	ray.localPosition = vec3(0);
	ray.renderableIndex = -1;
}
