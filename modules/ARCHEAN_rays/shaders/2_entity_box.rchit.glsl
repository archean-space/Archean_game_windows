#define SHADER_RCHIT
#include "common.inc.glsl"

#define ENTITY_COMPUTE_SURFACE \
	surface.normal = ComputeSurfaceNormal(ray.localPosition);\
	surface.color = ComputeSurfaceColor(ray.localPosition) * GEOMETRY.material.color;\
	surface.aabbData = AABB.data;\

#include "entity.inc.glsl"
