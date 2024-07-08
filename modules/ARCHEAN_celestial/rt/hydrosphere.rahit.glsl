#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"
#include "xenon/renderer/shaders/perlint.inc.glsl"

hitAttributeEXT hit {
	float T1;
	float T2;
};

#define WATER_TINT vec3(0.5,0.8,0.85)
#define EPSILON 0.0001

uint stableSeed = InitRandomSeed(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y);
uint coherentSeed = InitRandomSeed(uint(xenonRendererData.frameIndex),0);
uint temporalSeed = uint(int64_t(renderer.timestamp * 1000) % 1000000);
uint seed = InitRandomSeed(stableSeed, coherentSeed);

// Caustics
float h12(vec2 p) {
	return fract(sin(dot(p,vec2(32.52554,45.5634)))*12432.2355);
}
float n12(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f *= f * (3.-2.*f);
	return mix(
		mix(h12(i+vec2(0.,0.)),h12(i+vec2(1.,0.)),f.x),
		mix(h12(i+vec2(0.,1.)),h12(i+vec2(1.,1.)),f.x),
		f.y
	);
}
vec2 getUVfromWorldPos(vec3 position, vec3 normal) {
	vec3 up = abs(normal.z) < 0.99 ? vec3(0,0,1) : vec3(0,1,0);
	vec3 right = normalize(cross(up, normal));
	up = cross(normal, right);
	return vec2(dot(position, right), dot(position, up));
}
float caustics(vec3 worldPosition, vec3 normal, float t) {
	vec2 p = getUVfromWorldPos(worldPosition, normal);
	vec3 k = vec3(p,t);
	float l;
	mat3 m = mat3(-2,-1,2,3,-2,1,1,2,2);
	float n = n12(p);
	k = k*m*.5;
	l = length(.5 - fract(k+n));
	k = k*m*.4;
	l = min(l, length(.5-fract(k+n)));
	k = k*m*.3;
	l = min(l, length(.5-fract(k+n)));
	return pow(l,7.)*25.;
}

void main() {
	float transmittance = 1;
	
	if ((ray.rayFlags & SHADOW_RAY_FLAG_EMISSION) != 0) {
		// Fog Ray: ray-march underwater fog
		
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
		
	} else {
		// Shadow ray: Draw caustics
		vec3 lightIncomingDir = normalize(normalize(vec3(renderer.worldOrigin)) + gl_WorldRayDirectionEXT); // approximation of the refracted ray, good enough here
		transmittance *= clamp(caustics(gl_WorldRayOriginEXT*vec3(0.9,0.5,0.7), lightIncomingDir, float(renderer.timestamp)) * 0.5 + 0.5, 0, 1);
	}
	
	float depth = max(0, min(T2, ray.hitDistance));
	RayTransparent(transmittance * mix(
		WATER_TINT * exp(depth / -50),
		vec3(0.9),
		exp(depth / -10)
	));
}
