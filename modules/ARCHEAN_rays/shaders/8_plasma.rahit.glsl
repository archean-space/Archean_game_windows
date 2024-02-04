#define SHADER_RAHIT
#include "common.inc.glsl"

hitAttributeEXT hit {
	float t2_;
};

float t1 = gl_HitTEXT;
float t2 = t2_;
float depth = PlasmaData(AABB.data).depth * (1.0 - RandomFloat(temporalSeed) * 0.1);
float radius = PlasmaData(AABB.data).radius;
uint mask = PlasmaData(AABB.data).mask;
uint flags = PlasmaData(AABB.data).flags;
float aerospikeEffect = float(flags & PLASMA_FLAG_AEROSPIKE);

float density(vec3 pos) {
	if (mask > 0) {
		vec2 uv = pos.xz / radius * 0.5 + 0.5;
		if (uv.x > 1 || uv.x < 0 || uv.y > 1 || uv.x < 0) return 0;
		vec2 d = texture(textures[nonuniformEXT(mask)], uv).rg;
		d = min(d, textureOffset(textures[nonuniformEXT(mask)], uv, ivec2(0,1)).rg);
		d = min(d, textureOffset(textures[nonuniformEXT(mask)], uv, ivec2(0,-1)).rg);
		d = min(d, textureOffset(textures[nonuniformEXT(mask)], uv, ivec2(1,0)).rg);
		d = min(d, textureOffset(textures[nonuniformEXT(mask)], uv, ivec2(-1,0)).rg);
		float start = d.r;
		float end = radius*2-d.g;
		if (pos.y < start || (pos.y > start + radius/32 && pos.y < end)) return 0;
		return clamp(pow(1 - pos.y / depth, 8), 0, 1);
	}
	float distToCenterLine = length(pos.xz);
	float aerospikeRadius = radius * max(mix(0, 0.8, aerospikeEffect), pow(1.0 - pos.y / depth, aerospikeEffect * 2));
	if (distToCenterLine < aerospikeRadius && pos.y > 0.0 && pos.y < depth) {
		float centerFactor = 1.0 - distToCenterLine / aerospikeRadius;
		float beginFactor = clamp(centerFactor * 0.125 + smoothstep(0, max(0, 0.5 - aerospikeEffect), pos.y / depth), 0.0, 1.0);
		float endFactor = 1.0 - pos.y / depth;
		return beginFactor * endFactor * centerFactor;
	}
	return 0;
}

void main() {
	// vec3 exaustColor = PlasmaData(AABB.data).color;
	// float exaustDensity = PlasmaData(AABB.data).density;
	// float exaustTemperature = PlasmaData(AABB.data).temperature;
	
	// if (ray.hitDistance > 0) {
	// 	t2 = min(t2, ray.hitDistance);
	// 	vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * ray.hitDistance;
	// 	if (mask == 0) {
	// 		ray.color.rgb += GetEmissionColor(exaustTemperature * density(pos));
	// 	} else {
	// 		vec2 uv = pos.xz / radius * 0.5 + 0.5;
	// 		float d = texture(textures[nonuniformEXT(mask)], uv).r;
	// 		if (d > 0 && d < radius*2 && pos.y < d + 0.125) {
	// 			ray.color.rgb += GetEmissionColor(min(exaustTemperature * 3, 2500));
	// 		}
	// 	}
	// }
	
	// int nb_steps = 4;
	// if (mask > 0) {
	// 	nb_steps = int(textureSize(textures[nonuniformEXT(mask)], 0).x);
	// }
	// const float stepSize = (t2 - t1) / (nb_steps + 2);
	// float t = stepSize * (0.5 + RandomFloat(seed));
	
	// vec3 accumulatedLight = vec3(0);
	// float accumulatedDensity = 0.0;
	
	// uint thrusterSeed = temporalSeed + uint(gl_InstanceID);
	// vec3 offset = vec3(0);
	// if ((flags & PLASMA_FLAG_SHAKE) != 0) {
	// 	offset += RandomInUnitSphere(thrusterSeed) * radius * 0.1;
	// }
	
	// for (int i = 0; i < nb_steps; ++i) {
	// 	vec3 pos = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * (t1 + t);
	// 	pos += offset * pos.y / depth;
	// 	float d = density(pos);
	// 	accumulatedDensity += d*d * exaustDensity * stepSize;
	// 	accumulatedLight += GetEmissionColor(d * exaustTemperature) * stepSize;
	// 	t += stepSize;
	// 	if (ray.hitDistance > 0 && t1 + t > ray.hitDistance) break;
	// }
	
	// ray.emission.rgb += max(accumulatedLight, exaustColor * accumulatedDensity);
	// ray.emission.a += accumulatedDensity;
	// ray.ssao = clamp(ray.ssao - accumulatedDensity * 0.2, 0.0, 1.0);
	
	// ray.albedo = vec3(0);
	// ray.t1 = -1;
	// ray.normal = -gl_WorldRayDirectionEXT;
	// ray.t2 = -1;
	// ray.transmittance = vec3(1);
	// ray.ior = 1;
	// ray.reflectance = 0;
	// ray.metallic = 0;
	// ray.roughness = 0;
	// ray.specular = 0;
	// ray.localPosition = vec3(0);
	// ray.renderableIndex = -1;
	
	// ignoreIntersectionEXT;
}
