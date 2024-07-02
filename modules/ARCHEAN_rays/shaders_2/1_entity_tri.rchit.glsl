#define SHADER_RCHIT
#include "common.inc.glsl"

hitAttributeEXT vec2 hitAttribs;
vec3 barycentricCoords = vec3(1.0f - hitAttribs.x - hitAttribs.y, hitAttribs.x, hitAttribs.y);

float SurfaceDetail(vec3 position) {
	return SimplexFractal(position, 6) * 0.5 + 0.5;
}

void main() {
	vec4 color = ComputeSurfaceColor(barycentricCoords) * GEOMETRY.material.color;
	vec3 normal = ComputeSurfaceNormal(barycentricCoords);
	float metallic = GEOMETRY.material.metallic;
	float roughness = GEOMETRY.material.roughness;
	vec3 emission = GEOMETRY.material.emission;
	vec2 uv1 = ComputeSurfaceUV1(barycentricCoords);
	// vec2 uv2 = ComputeSurfaceUV2(barycentricCoords);
	float ior = 0.75;
	float specular = step(0.1, roughness) * (0.5 + metallic * 0.5);
	
	// Back Face: flip normal and inverse index of refraction
	if (dot(normal, gl_ObjectRayDirectionEXT) > 0) {
		ior = 1.0 / ior;
		normal *= -1;
	}
	
	// uint64_t instanceData = INSTANCE.data;
	// uint64_t geometryMaterialData = GEOMETRY.material.data;
	// if (instanceData != 0) {
	// 	RenderableData data = RenderableData(instanceData)[gl_GeometryIndexEXT];
	// 	emission += data.emission;
	// 	color = mix(color, data.color, data.colorMix);
	// 	metallic = mix(metallic, data.pbrMetallic, data.pbrMix);
	// 	roughness = mix(roughness, data.pbrRoughness, data.pbrMix);
	// 	if (data.monitorIndex > 0) {
	// 		emission *= ReverseGamma(texture(textures[nonuniformEXT(data.monitorIndex)], uv1).rgb);
	// 		emission /= GetCurrentExposure();
	// 	}
	// }
	// if (geometryMaterialData > 0) {
	// 	uint16_t tex_albedo = 				uint16_t((geometryMaterialData) & 0xffff);
	// 	uint16_t tex_normal = 				uint16_t((geometryMaterialData >> 16) & 0xffff);
	// 	uint16_t tex_metallic_roughness = 	uint16_t((geometryMaterialData >> 32) & 0xffff);
	// 	uint16_t tex_emission = 			uint16_t((geometryMaterialData >> 48) & 0xffff);
	// 	if (tex_albedo > 0) color.rgb *= ReverseGamma(texture(textures[nonuniformEXT(tex_albedo)], uv1).rgb);
	// 	if (tex_normal > 0) {
	// 		//TODO: normal maps using tex_normal
	// 	}
	// 	if (tex_metallic_roughness > 0) {
	// 		vec2 pbr = texture(textures[nonuniformEXT(tex_metallic_roughness)], uv1).rg;
	// 		metallic = pbr.r;
	// 		roughness = pbr.g;
	// 	}
	// 	if (tex_emission > 0) {
	// 		vec3 emissionPower = vec3(10);
	// 		if (instanceData != 0) {
	// 			emissionPower = emission;
	// 		}
	// 		emission = emissionPower * ReverseGamma(texture(textures[nonuniformEXT(tex_emission)], uv1).rgb);
	// 	}
	// }
	
	// // Rough metal
	// if (metallic > 0 && roughness > 0) {
	// 	vec3 scale = vec3(8);
	// 	if (abs(dot(normal, vec3(1,0,0))) < 0.4) scale.x = 100;
	// 	else if (abs(dot(normal, vec3(0,1,0))) < 0.4) scale.y = 100;
	// 	else if (abs(dot(normal, vec3(0,0,1))) < 0.4) scale.z = 100;
	// 	vec3 oldNormal = normal;
	// 	vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * gl_HitTEXT;
	// 	APPLY_NORMAL_BUMP_NOISE(SurfaceDetail, localPosition * scale, normal, roughness * 0.005)
	// 	color.rgb *= pow(dot(oldNormal, normal), 100);
	// }
	
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
