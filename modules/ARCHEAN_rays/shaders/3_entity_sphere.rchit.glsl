#define SHADER_RCHIT
#include "common.inc.glsl"

struct SphereAttr {
	float t1;
	float t2;
	float radius;
};

hitAttributeEXT SphereAttr sphereAttr;

#define ENTITY_COMPUTE_SURFACE {\
	const vec3 spherePosition = (AABB_MAX + AABB_MIN) / 2;\
	const vec3 hitPoint1 = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * sphereAttr.t1;\
	const vec3 hitPoint2 = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * sphereAttr.t2;\
	if (gl_HitKindEXT == 1) /*Inside of sphere*/ {\
		surface.normal = normalize(hitPoint2 - spherePosition);\
	} else /*Outside of sphere*/ {\
		surface.normal = normalize(hitPoint1 - spherePosition);\
	}\
	surface.color = ComputeSurfaceColor(vec3(0)) * GEOMETRY.material.color;\
	surface.aabbData = AABB.data;\
}

#include "entity.inc.glsl"
