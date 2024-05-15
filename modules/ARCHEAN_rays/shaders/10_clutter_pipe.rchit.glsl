#define SHADER_RCHIT
#include "common.inc.glsl"

struct PipeAttr {
	vec3 normal;
	vec3 axis;
};

hitAttributeEXT PipeAttr attr;

#define ENTITY_COMPUTE_SURFACE \
	surface.normal = attr.normal;\
	surface.color = GEOMETRY.material.color;\
	surface.aabbData = AABB.data;\

#include "entity.inc.glsl"
