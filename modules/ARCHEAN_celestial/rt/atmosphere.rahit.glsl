#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"

// https://www.alanzucconi.com/2017/10/10/atmospheric-scattering-1/

#define ATMOSPHERE_RAY_MIN_DISTANCE 1000

const int RAYMARCH_LIGHT_STEPS = 5; // low=2, medium=3, high=5, ultra=8
const float sunLuminosityThreshold = LIGHT_LUMINOSITY_VISIBLE_THRESHOLD;

uint stableSeed = InitRandomSeed(gl_LaunchIDEXT.x, gl_LaunchIDEXT.y);
uint coherentSeed = InitRandomSeed(uint(xenonRendererData.frameIndex),0);
uint temporalSeed = uint(int64_t(renderer.timestamp * 1000) % 1000000);
uint seed = InitRandomSeed(stableSeed, coherentSeed);

bool RaySphereIntersection(in vec3 position, in vec3 rayDir, in float radius, out float t1, out float t2) {
	const vec3 p = -position; // equivalent to cameraPosition - spherePosition (or negative position of sphere in view space)
	const float a = dot(rayDir, rayDir);
	const float b = dot(p, rayDir);
	const float c = dot(p, p) - radius*radius;
	const float discriminant = b * b - a * c;
	if (discriminant < 0) return false;
	const float det = sqrt(discriminant);
	t1 = (-b - det) / a;
	t2 = (-b + det) / a;
	bool inside = t1 < 0 && t2 > 0;
	bool outside = t1 > 0 && t1 < t2;
	return inside || outside;
}

hitAttributeEXT hit {
	float intersectionT2;
};

void main() {
	if ((ray.rayFlags & SHADOW_RAY_FLAG_EMISSION) == 0) return;
	
	int raymarchSteps = renderer.atmosphere_raymarch_steps;
	
	AtmosphereData atmosphere = AtmosphereData(AABB.data);
	vec4 rayleigh = atmosphere.rayleigh;
	vec4 mie = atmosphere.mie;
	float outerRadius = atmosphere.outerRadius;
	float innerRadius = atmosphere.innerRadius - 1000;
	float g = atmosphere.g;
	float temperature = atmosphere.temperature;
	
	vec3 atmospherePosition = gl_ObjectToWorldEXT[3].xyz;
	vec3 origin = gl_WorldRayOriginEXT;
	vec3 viewDir = gl_WorldRayDirectionEXT;
	float t1 = gl_HitTEXT;
	float t2 = intersectionT2;
	
	float startAltitude = distance(origin, atmospherePosition);
	float thickness = outerRadius - innerRadius;
	
	float inner_t1, inner_t2;
	bool hitInnerRadius = RaySphereIntersection(atmospherePosition, viewDir, innerRadius, inner_t1, inner_t2);
	if (hitInnerRadius && inner_t1 > 0) {
		t2 = mix(inner_t1, t2, clamp((innerRadius - startAltitude) / thickness, 0,1));
	}
	
	float nextHitDistance = ray.hitDistance;
	
	const vec2 scaleHeight = vec2(rayleigh.a, mie.a);
	
	// Ray-marching configuration
	bool hasHitSomethingWithinAtmosphere = nextHitDistance < t2;
	const vec3 startPoint = origin + viewDir * t1;
	const float rayStartAltitude = length(startPoint - atmospherePosition);
	vec3 endPoint = origin + viewDir * min(nextHitDistance, t2);
	float rayDepth = distance(startPoint, endPoint);
	float stepSize = rayDepth / float(raymarchSteps);
	
	if (hasHitSomethingWithinAtmosphere) {
		g = 0.0;
	}
	
	bool shadows = (renderer.options & RENDERER_OPTION_ATMOSPHERIC_SHADOWS) != 0;
	float shadowsMinDistance = 0;
	if (!hasHitSomethingWithinAtmosphere) {
		shadowsMinDistance = outerRadius;
	}
	
	// Start Ray-Marching in the atmosphere!
	vec3 rayleighScattering = vec3(0);
	vec3 mieScattering = vec3(0);
	float maxDepth = 0;
	if (atmosphere.nbSuns > 0) {
		for (int sunIndex = 0; sunIndex < atmosphere.nbSuns; ++sunIndex) {
			SunData sun = atmosphere.suns[sunIndex];
			vec3 relativeSunPosition = sun.position - atmospherePosition;
			float sunDistance = length(relativeSunPosition);
			vec3 lightIntensity = sun.color * GetSunRadiationAtDistanceSqr(sun.temperature, sun.radius, dot(relativeSunPosition, relativeSunPosition)) * 0.5;
			if (length(lightIntensity) > sunLuminosityThreshold) {
				vec3 lightDir = normalize(relativeSunPosition);
				
				// Cache some values related to that light before raymarching in the atmosphere
				float mu = dot(viewDir, -lightDir);
				float mumu = mu * mu;
				float gg = g*g;
				float rayleighPhase = 3.0 / (50.2654824574 /* (16 * pi) */) * (1.0 + mumu);
				float miePhase = 3.0 / (25.1327412287 /* (8 * pi) */) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg));
				
				// Init accumulation variables
				vec2 opticalDepth = vec2(0);

				// Ray-March
				vec3 rayPos = startPoint;
				for (int i = 0; i < raymarchSteps; ++i) {
					rayPos += viewDir * stepSize;
					vec3 posOnSphere = rayPos - atmospherePosition;
					float rayAltitude = length(posOnSphere);
					float rayAltitudeAboveInnerRadius = rayAltitude - innerRadius;
					vec2 density = exp(-rayAltitudeAboveInnerRadius / scaleHeight) * stepSize;
					opticalDepth += density;
					maxDepth = max(maxDepth, outerRadius - rayAltitude);
					
					// step size for light ray
					float a = dot(lightDir, lightDir);
					float b = 2.0 * dot(lightDir, posOnSphere);
					float c = dot(posOnSphere, posOnSphere) - (outerRadius * outerRadius);
					float d = (b * b) - 4.0 * a * c;
					float lightRayStepSize = (-b + sqrt(d)) / (2.0 * a * float(RAYMARCH_LIGHT_STEPS));
					
					// RayMarch towards light source
					vec2 lightRayOpticalDepth = vec2(0);
					float lightRayDist = 0;
					float lightRayVisibility = 1.0;
					
					if (shadows) {
						// God rays and eclipes
						vec3 shadowRayDir = lightDir;
						vec2 rnd = vec2(RandomFloat(seed), RandomFloat(seed));
						float pointRadius = sun.radius / sunDistance * rnd.x;
						float pointAngle = rnd.y * 2.0 * PI;
						vec2 diskPoint = vec2(pointRadius * cos(pointAngle), pointRadius * sin(pointAngle));
						vec3 lightTangent = normalize(posOnSphere);// normalize(cross(shadowRayDir, viewDir));
						vec3 lightBitangent = normalize(cross(lightTangent, shadowRayDir));
						shadowRayDir = normalize(shadowRayDir + diskPoint.x * lightTangent * mix(1, 12, smoothstep(24, 8, float(raymarchSteps))) + diskPoint.y * lightBitangent);
						rayQueryEXT rq;
						rayQueryInitializeEXT(rq, tlas, gl_RayFlagsTerminateOnFirstHitEXT, RAYTRACE_MASK_TERRAIN, rayPos, shadowsMinDistance, shadowRayDir, sunDistance);
						if (rayQueryProceedEXT(rq)) {
							// Sunlight occluded by terrain
							lightRayVisibility = 0;
						}
					}

					for (int l = 0; l < RAYMARCH_LIGHT_STEPS; ++l) {
						vec3 posLightRay = posOnSphere + lightDir * (lightRayDist + lightRayStepSize/2.0);
						float lightRayAltitude = length(posLightRay) - innerRadius;
						vec2 lightRayDensity = exp(-lightRayAltitude / scaleHeight) * lightRayStepSize;
						
						lightRayOpticalDepth += lightRayDensity;
						lightRayDist += lightRayStepSize;
					}
					
					vec3 attenuationRayleigh = exp(-rayleigh.rgb * (opticalDepth.x + lightRayOpticalDepth.x)) * lightRayVisibility;
					vec3 attenuationMie = exp(-mie.rgb * (opticalDepth.y + lightRayOpticalDepth.y)) * lightRayVisibility;
					rayleighScattering += max(vec3(0),
						+ rayleigh.rgb * attenuationRayleigh * max(0, density.x * rayleighPhase) * lightIntensity
					);
					mieScattering += max(vec3(0),
						+ mie.rgb * attenuationMie * max(0, density.y * miePhase) * lightIntensity
					);
				}
			}
		}
	} else {
		// Ray-March
		vec3 rayPos = startPoint;
		for (int i = 0; i < raymarchSteps; ++i) {
			rayPos += viewDir * stepSize;
			vec3 posOnSphere = rayPos - atmospherePosition;
			float rayAltitude = length(posOnSphere);
			maxDepth = max(maxDepth, outerRadius - rayAltitude);
		}
	}
	
	vec3 emission = GetEmissionColor(temperature) * 1e10;
	if (dot(rayleighScattering,rayleighScattering) > 0) mieScattering *= normalize(rayleighScattering);
	else mieScattering = vec3(0);
	vec4 fog = vec4(rayleighScattering + mieScattering + emission, pow(clamp(maxDepth/thickness, 0, 1), 2));
	
	ray.emission += fog.rgb * ray.colorAttenuation;
	// RayTransparent(vec3(1-pow(fog.a, 32)));
	RayTransparent(vec3(1));
}
