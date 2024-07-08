#define SHADER_RCHIT
#include "game/graphics/common.inc.glsl"

struct PipeAttr {
	vec3 normal;
	vec3 axis;
};

hitAttributeEXT PipeAttr attr;

void main() {
	vec4 color = GEOMETRY.material.color;
	vec3 normal = attr.normal;
	float metallic = GEOMETRY.material.metallic;
	float roughness = GEOMETRY.material.roughness;
	vec3 emission = GEOMETRY.material.emission;
	float ior = 1.2;
	
	uint32_t ucolor = uint32_t(AABB.data & 0xFFFFFFFF);
	uint32_t flags = uint32_t(AABB.data >> 32);
	
	AutoFlipNormal(normal, ior);
	ior = 1.2;
	
	MakeAimable(normal, vec2(0), 0);
	
	color *= vec4(
		float(ucolor & 0xFF),
		float((ucolor >> 8) & 0xFF),
		float((ucolor >> 16) & 0xFF),
		float((ucolor >> 24) & 0xFF)
	) / 255.0;
	
	if ((flags & PIPE_FLAG_STRIPES) != 0) {
		vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
		float f = fract(localPosition.x + localPosition.y + localPosition.z);
		color = vec4(mix(color.rgb, color.rgb * 0.02, step(0.5,f)), color.a);
	}
	
	if ((flags & PIPE_FLAG_CHROME) != 0) {
		metallic = 1;
		roughness = 0;
	} else if ((flags & PIPE_FLAG_GLOSSY) != 0) {
		metallic = 0;
		roughness = 0;
	} else if ((flags & PIPE_FLAG_METAL) != 0) {
		metallic = 1;
		roughness = 1;
	}
	
	if (dot(emission, emission) > 0) {
		uint8_t flags = RAY_SURFACE_EMISSIVE;
		if (color.a < 0) flags |= RAY_SURFACE_TRANSPARENT;
		RayHit(
			/*albedo*/		emission,
			/*normal*/		normal,
			/*distance*/	gl_HitTEXT,
			/*roughness*/	roughness,
			/*ior*/			ior,
			flags
		);
	} else {
		uint8_t flags = RAY_SURFACE_DIFFUSE;
		if (metallic > 0) flags |= RAY_SURFACE_METALLIC;
		else if (color.a < 1) {
			flags |= RAY_SURFACE_TRANSPARENT;
			color.rgb *= 1 - color.a;
		}
		RayHit(
			/*albedo*/		color.rgb,
			/*normal*/		normal,
			/*distance*/	gl_HitTEXT,
			/*roughness*/	roughness,
			/*ior*/			ior,
			flags
		);
	}
}
