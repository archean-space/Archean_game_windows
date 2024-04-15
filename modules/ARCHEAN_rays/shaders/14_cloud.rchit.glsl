#define SHADER_RCHIT
#include "common.inc.glsl"
#include "lighting.inc.glsl"

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
// float t2 = t2_;
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

float DensitySample(in vec3 pos) {
	return SimplexFractal(pos * 5.0, 4) * 0.5 + 0.5;
	// return clamp(renderer.testSlider - length(pos), 0, 1);
	// return 1.0;
}

float HenyeyGreenstein(float g, float cosTheta) {
	return (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5) / (4.0 * PI);
}

void main() {
	// vec3 exaustColor = PlasmaData(AABB.data).color;
	// float exaustDensity = PlasmaData(AABB.data).density;
	// float exaustTemperature = PlasmaData(AABB.data).temperature;
	
	// if (RAY_IS_GI || RAY_IS_SHADOW) {
		// ray.hitDistance = t1;
		// ray.t2 = t2;
		// ray.renderableIndex = gl_InstanceID;
		// ray.geometryIndex = gl_GeometryIndexEXT;
		// ray.primitiveIndex = gl_PrimitiveID;
		// ray.color = vec4(0,0,0,1);
		// ray.normal = vec3(0);
		// ray.emission.rgb += GetEmissionColor(exaustTemperature) * 0.5;
		// ray.ior = 1.0;
	// 	return;
	// }
	
	if (RAY_RECURSIONS >= RAY_MAX_RECURSION) {
		ray.hitDistance = -1;
		return;
	}
	
	// RAY_RECURSION_PUSH
	// 	traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_SOLID|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, gl_WorldRayOriginEXT, t1, gl_WorldRayDirectionEXT, xenonRendererData.config.zFar, 0);
	// RAY_RECURSION_POP
	
	// ray.hitDistance = RandomFloat(seed) * (t2 - t1) + t1;
	// vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * ray.hitDistance;
	// float density = 0.5 - length(pos);
	// if (density < 0) {
	// } else {
	// 	ray.color = vec4(1,1,1, density);
	// 	ray.ior = 1.3;
	// 	ray.normal = normalize(RandomInUnitSphere(seed));
	// }
	
	
	const int nb_steps = 25;
	float t2 = RayQueryHitT(RAYTRACE_MASK_SOLID|RAYTRACE_MASK_HYDROSPHERE, gl_WorldRayOriginEXT, t1, gl_WorldRayDirectionEXT, t2_);
	float stepSize = (t2 - t1) / nb_steps;
	float density = 0.0;
	vec3 light = vec3(0);
	vec3 aabb_min = AABB_MIN;
	vec3 aabb_max = AABB_MAX;
	
	vec3 worldPos = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * t1;
	vec3 lightDir;
	float lightDistance;
	vec3 lightColor;
	float lightPower;
	GetDirectLight(worldPos, lightDir, lightDistance, lightColor, lightPower);
	
	for (int i = 0; i < nb_steps; ++i) {
		float t = t1 + stepSize * (i + RandomFloat(seed));
		vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * t;
		density += (1-exp(-DensitySample(pos))) * stepSize;
		if (lightPower > 0) {
			vec3 lightDirLocal = normalize(mat3(gl_WorldToObjectEXT) * lightDir);
			vec3 lightPos = pos;
			float lightDensity = 0;
			float lightDist = 0;
			for (int j = 0; j < nb_steps; ++j) {
				lightDist += stepSize;
				lightPos = pos + lightDirLocal * lightDist;
				if (lightPos.x < aabb_min.x || lightPos.y < aabb_min.y || lightPos.z < aabb_min.z || lightPos.x > aabb_max.x || lightPos.y > aabb_max.y || lightPos.z > aabb_max.z || lightDist > lightDistance) {
					break;
				}
				lightDensity += (1-exp(-DensitySample(lightPos))) * stepSize;
			}
			float cosTheta = dot(lightDir, gl_WorldRayDirectionEXT);
			light += lightColor * lightPower * stepSize * 2.0 * exp(-lightDensity) * (1.0 - exp(-lightDensity*2.0)) * min(1, HenyeyGreenstein(-0.25, cosTheta) + HenyeyGreenstein(0.5, cosTheta));
		}
	}
	// float falloff = exp(-density);
	// ray.color = mix(vec4(0,0,0,1), ray.color, falloff);
	// ray.emission.rgb *= falloff;
	ray.emission += light;
	
	ray.ior = 1;
	ray.hitDistance = t2;
	ray.color = vec4(1,1,1,1-exp(-density));
	
	// RAY_RECURSION_PUSH
	// 	traceRayEXT(tlas, gl_RayFlagsOpaqueEXT, RAYTRACE_MASK_SOLID|RAYTRACE_MASK_HYDROSPHERE|RAYTRACE_MASK_ATMOSPHERE, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, gl_WorldRayOriginEXT, max(t1, xenonRendererData.config.zNear), gl_WorldRayDirectionEXT, xenonRendererData.config.zFar, 0);
	// 	RayPayload originalRay = ray;
	// 	traceRayEXT(tlas, gl_RayFlagsNoOpaqueEXT, RAYTRACE_MASK_PLASMA, 0/*rayType*/, 0/*nbRayTypes*/, 0/*missIndex*/, gl_WorldRayOriginEXT, t1, gl_WorldRayDirectionEXT, ray.hitDistance<=0? xenonRendererData.config.zFar : ray.hitDistance, 0);
	// 	originalRay.emission.rgb = max(originalRay.emission.rgb, ray.emission.rgb);
	// 	ray = originalRay;
	// RAY_RECURSION_POP
	
	// Debug Time
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_RAYHIT_TIME) {
		if (RAY_RECURSIONS == 0) WRITE_DEBUG_TIME
	}
}
