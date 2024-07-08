#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"
#include "xenon/renderer/shaders/perlint.inc.glsl"

hitAttributeEXT hit {
	float T1;
	float T2;
};

#define WATER_TINT vec3(0.5,0.8,0.8)
#define EPSILON 0.0001

uint stableSeed = InitRandomSeed(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y);
uint coherentSeed = InitRandomSeed(uint(xenonRendererData.frameIndex),0);
uint temporalSeed = uint(int64_t(renderer.timestamp * 1000) % 1000000);
uint seed = InitRandomSeed(stableSeed, coherentSeed);

void main() {
	if ((ray.rayFlags & SHADOW_RAY_FLAG_EMISSION) != 0) {
		
		WaterData water = WaterData(AABB.data);
		
		rayQueryEXT lightQuery;
		rayQueryInitializeEXT(lightQuery, tlas_lights, 0, 0xff, gl_WorldRayOriginEXT, 0, vec3(0,1,0), 0);
		
		while (rayQueryProceedEXT(lightQuery)) {
			mat4 lightTransform = mat4(rayQueryGetIntersectionObjectToWorldEXT(lightQuery, false));
			vec3 lightPosition = lightTransform[3].xyz;
			int lightID = rayQueryGetIntersectionInstanceIdEXT(lightQuery, false);
			
			const int nbSamples = 10;
			
			for (int i = 0; i < nbSamples; i++) {
				vec3 position = gl_WorldRayOriginEXT + gl_WorldRayDirectionEXT * (float(i) + RandomFloat(seed)) / nbSamples * min(200, ray.hitDistance);
				vec3 upDir = normalize(position - vec3(water.center));
				vec3 relativeLightPosition = lightPosition - position;
				vec3 lightDir = normalize(relativeLightPosition);
				float nDotL = dot(upDir, lightDir);
				if (nDotL > 0) {
					LightSourceInstanceData lightSource = renderer.lightSources[lightID].instance;
					float distanceToLightSurface = length(relativeLightPosition) - abs(lightSource.innerRadius) - EPSILON * length(lightPosition);
					if (distanceToLightSurface < lightSource.maxDistance) {
						if (distanceToLightSurface > 100000) { // only sun lights
							float effectiveLightIntensity = max(0, lightSource.power / (4 * PI * distanceToLightSurface*distanceToLightSurface + 1) - LIGHT_LUMINOSITY_VISIBLE_THRESHOLD);
							float underwaterDepth = float(water.radius) - distance(position, vec3(water.center));
							vec3 lightColor = lightSource.color * effectiveLightIntensity * 0.01 * WATER_TINT * WATER_TINT * exp(underwaterDepth / nDotL / -100);
							
							// rayQueryEXT shadowQuery;
							// rayQueryInitializeEXT(shadowQuery, tlas, 0, RAYTRACE_MASK_TERRAIN, position, 0, lightDir, distanceToLightSurface);
							// if (!rayQueryProceedEXT(shadowQuery)) {
								ray.emission += lightColor * nDotL / nbSamples;
							// }
							
						}
					}
				}
			}
		}
		
	}
	
	RayTransparent(mix(
		WATER_TINT * exp(min(T2, ray.hitDistance) / -50),
		vec3(0.9),
		exp(min(T2, ray.hitDistance) / -10)
	));
}
