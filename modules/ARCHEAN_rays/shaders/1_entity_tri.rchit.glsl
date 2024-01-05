#define SHADER_RCHIT
#include "common.inc.glsl"

hitAttributeEXT vec3 hitAttribs;

#define ENTITY_COMPUTE_SURFACE \
	vec3 barycentric_coords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);\
	surface.normal = ComputeSurfaceNormal(barycentric_coords);\
	surface.color = ComputeSurfaceColor(barycentric_coords) * GEOMETRY.material.color;\
	surface.barycentricCoords = barycentric_coords;\
	surface.aabbData = 0;\

#include "entity.inc.glsl"
