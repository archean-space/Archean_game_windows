#define SHADER_RCHIT
#include "common.inc.glsl"

// float sdfLine(in vec3 p, in vec3 start, in vec3 end) {
// 	vec3 segmentVector = end - start;
// 	vec3 pointVector = p - start;
// 	float t = clamp(dot(pointVector, segmentVector) / dot(segmentVector, segmentVector), 0.0, 1.0);
// 	vec3 closestPoint = start + segmentVector * t;
// 	return length(closestPoint - p);
// }

hitAttributeEXT hit {
	float t2_;
};

float t1 = gl_HitTEXT;
float t2 = t2_;
// float depth = PlasmaData(AABB.data).depth * (1.0 - RandomFloat(temporalSeed) * 0.1);
// float radius = PlasmaData(AABB.data).radius;
// uint mask = PlasmaData(AABB.data).mask;
// uint flags = PlasmaData(AABB.data).flags;
// float aerospikeEffect = float(flags & PLASMA_FLAG_AEROSPIKE);

// float density(vec3 pos) {
// 	if (mask > 0) {
// 		vec2 uv = pos.xz / radius * 0.5 + 0.5;
// 		if (uv.x > 1 || uv.x < 0 || uv.y > 1 || uv.x < 0) return 0;
// 		vec2 d = texture(textures[nonuniformEXT(mask)], uv).rg;
// 		d = min(d, textureOffset(textures[nonuniformEXT(mask)], uv, ivec2(0,1)).rg);
// 		d = min(d, textureOffset(textures[nonuniformEXT(mask)], uv, ivec2(0,-1)).rg);
// 		d = min(d, textureOffset(textures[nonuniformEXT(mask)], uv, ivec2(1,0)).rg);
// 		d = min(d, textureOffset(textures[nonuniformEXT(mask)], uv, ivec2(-1,0)).rg);
// 		float start = d.r;
// 		float end = radius*2-d.g;
// 		if (pos.y < start || (pos.y > start + radius/32 && pos.y < end)) return 0;
// 		return clamp(pow(1 - pos.y / depth, 8), 0, 1);
// 	}
// 	float distToCenterLine = length(pos.xz);
// 	float aerospikeRadius = radius * max(mix(0, 0.8, aerospikeEffect), pow(1.0 - pos.y / depth, aerospikeEffect * 2));
// 	if (distToCenterLine < aerospikeRadius && pos.y > 0.0 && pos.y < depth) {
// 		float beginFactor = smoothstep(0, 0.0, pos.y / depth);
// 		float endFactor = 1.0 - pos.y / depth;
// 		float centerFactor = 1.0 - distToCenterLine / aerospikeRadius;
// 		return beginFactor * endFactor * centerFactor;
// 	}
// 	return 0;
// }

void main() {
	vec3 exaustColor = PlasmaData(AABB.data).color;
	float exaustDensity = PlasmaData(AABB.data).density;
	float exaustTemperature = PlasmaData(AABB.data).temperature;
	
	if (RAY_IS_GI || RAY_IS_SHADOW) {
		ray.hitDistance = t1;
		ray.t2 = t2;
		ray.renderableIndex = gl_InstanceID;
		ray.geometryIndex = gl_GeometryIndexEXT;
		ray.primitiveIndex = gl_PrimitiveID;
		ray.color = vec4(0,0,0,1);
		ray.normal = vec3(0);
		ray.emission.rgb = GetEmissionColor(exaustTemperature) * 0.5;
		ray.ior = 1.0;
		return;
	}
	
	RAY_RECURSION_PUSH
		traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_SOLID|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, gl_WorldRayOriginEXT, max(t1, xenonRendererData.config.zNear), gl_WorldRayDirectionEXT, xenonRendererData.config.zFar, 0);
		RayPayload originalRay = ray;
		traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT, RAYTRACE_MASK_PLASMA, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, gl_WorldRayOriginEXT, t1, gl_WorldRayDirectionEXT, ray.hitDistance<=0? xenonRendererData.config.zFar : ray.hitDistance, 0);
		originalRay.emission.rgb = max(originalRay.emission.rgb, ray.emission.rgb);
		ray = originalRay;
	RAY_RECURSION_POP
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
