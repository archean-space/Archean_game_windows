#define SHADER_COMP_RAYS

#include "game/graphics/common.inc.glsl"

#define CLOUD_MAX_DISTANCE 200

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X + 1, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y + 1) in;

ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

float GetTrueDistanceFromDepthBuffer(float depth) {
	if (depth == 0 || depth == 1) return xenonRendererData.config.zFar;
	return 2.0 * (xenonRendererData.config.zFar * xenonRendererData.config.zNear) / (xenonRendererData.config.zNear + xenonRendererData.config.zFar - (depth * 2.0 - 1.0) * (xenonRendererData.config.zNear - xenonRendererData.config.zFar));
}

// float GetDistance(vec2 uv) {
// 	float depth = texture(sampler_depth, uv).r;
// 	depth = min(depth, textureLodOffset(sampler_depth, uv, 0.0, ivec2( 1,  0)).r);
// 	depth = min(depth, textureLodOffset(sampler_depth, uv, 0.0, ivec2(-1,  0)).r);
// 	depth = min(depth, textureLodOffset(sampler_depth, uv, 0.0, ivec2( 0,  1)).r);
// 	depth = min(depth, textureLodOffset(sampler_depth, uv, 0.0, ivec2( 0, -1)).r);
// 	depth = min(depth, textureLodOffset(sampler_depth, uv, 0.0, ivec2( 1,  1)).r);
// 	depth = min(depth, textureLodOffset(sampler_depth, uv, 0.0, ivec2(-1, -1)).r);
// 	depth = min(depth, textureLodOffset(sampler_depth, uv, 0.0, ivec2( 1, -1)).r);
// 	depth = min(depth, textureLodOffset(sampler_depth, uv, 0.0, ivec2(-1,  1)).r);
// 	return GetTrueDistanceFromDepthBuffer(depth);
// }

float GetDistance(vec2 uv) {
	float dist = texture(sampler_motion, uv).a;
	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 1,  0)).a);
	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2(-1,  0)).a);
	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 0,  1)).a);
	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 0, -1)).a);
	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 1,  1)).a);
	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2(-1, -1)).a);
	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2( 1, -1)).a);
	dist = max(dist, textureLodOffset(sampler_motion, uv, 0.0, ivec2(-1,  1)).a);
	return dist;
}

bool TraceRayHitTerrain(in vec3 rayOrigin, in float minDistance, in vec3 rayDirection, in float maxDistance, out float hitDistance) {
	rayQueryEXT rq;
	hitDistance = 0;
	rayQueryInitializeEXT(rq, tlas, 0, RAYTRACE_MASK_TERRAIN, rayOrigin, minDistance, rayDirection, maxDistance);
	while (rayQueryProceedEXT(rq)) {
		rayQueryConfirmIntersectionEXT(rq);
	}
	hitDistance = rayQueryGetIntersectionTEXT(rq, true);
	if (hitDistance > 0 && hitDistance < maxDistance) {
		return true;
	}
	return false;
}

bool TraceRayInShadow(in vec3 rayOrigin, in float minDistance, in vec3 lightDirection, in float maxDistance) {
	rayQueryEXT rq;
	rayQueryInitializeEXT(rq, tlas, gl_RayFlagsTerminateOnFirstHitEXT, RAYTRACE_MASK_TERRAIN|RAYTRACE_MASK_ENTITY, rayOrigin, minDistance, lightDirection, maxDistance);
	if (rayQueryProceedEXT(rq)) {
		return true;
	}
	return false;
}

int32_t GetSunLight(in vec3 position, out vec3 lightPosition, out float lightPower) {
	rayQueryEXT q;
	rayQueryInitializeEXT(q, tlas_lights, 0, 0xff, position, 0, vec3(0,1,0), 0);
	
	int32_t lightID = -1;
	lightPower = 0;
	
	while (rayQueryProceedEXT(q)) {
		vec3 lightPos = rayQueryGetIntersectionObjectToWorldEXT(q, false)[3].xyz; // may be broken on AMD...
		int id = rayQueryGetIntersectionInstanceIdEXT(q, false);
		vec3 relativeLightPosition = lightPos - position;
		LightSourceInstanceData lightSource = renderer.lightSources[id].instance;
		float distanceToLightSurface = length(relativeLightPosition) - abs(lightSource.innerRadius);
		if (distanceToLightSurface <= 0.001) {
			return -1;
		} else if (lightSource.power > 1000000 && distanceToLightSurface < lightSource.maxDistance) {
			float effectiveLightIntensity = max(0, lightSource.power / (4.0 * PI * distanceToLightSurface*distanceToLightSurface + 1) - LIGHT_LUMINOSITY_VISIBLE_THRESHOLD);
			if (effectiveLightIntensity > lightPower) {
				lightPower = effectiveLightIntensity;
				lightID = id;
				lightPosition = lightPos;
			}
		}
	}
	
	return lightID;
}

float GetGroundFogRaymarchStartDistanceAlongRay(in vec3 rayOrigin, in vec3 rayDirection, in float terrainRayHitDistance, in vec3 upDirection, in float fogLayerHeightFromGround) {
	// Calculate the position where the ray hits the terrain
	vec3 terrainHitPosition = rayOrigin + terrainRayHitDistance * rayDirection;

	// Calculate the height of the ray origin from the terrain hit point along the up direction
	float rayOriginHeightFromGround = dot(rayOrigin - terrainHitPosition, upDirection);

	// Case where we are in the fog layer
	if (rayOriginHeightFromGround <= fogLayerHeightFromGround) {
		return 0.0;
	}

	// Calculate the cosine of the angle between the ray direction and the up direction
	float cosineAngle = dot(normalize(rayDirection), upDirection);

	// Case where the ray is parallel to the ground
	if (abs(cosineAngle) < 0.001) {
		return terrainRayHitDistance;
	}

	// Calculate the start distance of raymarching along the ray using trigonometry
	float fogRaymarchStartDistance = (rayOriginHeightFromGround - fogLayerHeightFromGround) / -cosineAngle;

	// Clamp the start distance between 0 and terrainRayHitDistance
	return clamp(fogRaymarchStartDistance, 0.0, terrainRayHitDistance);
}

const float FOG_TERRAIN_MAX_DISTANCE = 5.0;
const float FOG_TERRAIN_MAX_DISTANCE_UNDERWATER = 10.0;

float GetFogDensity(in vec3 position, in float altitude) {
	return pow(smoothstep(FOG_TERRAIN_MAX_DISTANCE, 0, altitude), 8) * (SimplexFractal(position, 2) * 0.5 + 0.5) * (Simplex(position * 10) * 0.5 + 0.5);
}

float GetFogDensityUnderwater(in vec3 position, in float altitude) {
	return pow(smoothstep(FOG_TERRAIN_MAX_DISTANCE, 0, altitude), 2);
}

layout(push_constant) uniform PushConstant {
	vec3 windVelocity;
};

// read from img_resolved.a, write to img_cloud
void main() {
	
	// Get spatial information from G-buffer
	vec2 uv = vec2(compute_coord) / vec2(imageSize(img_cloud[0]));
	float viewDistance = GetDistance(uv);
	bool isUnderwater = false;
	if (viewDistance < 0) {
		viewDistance *= -1;
		isUnderwater = true;
	}
	viewDistance = clamp(viewDistance, 0.5, CLOUD_MAX_DISTANCE);
	vec3 viewDir = normalize(VIEW2WORLDNORMAL * normalize(vec4(inverse(mat4(xenonRendererData.config.projectionMatrix)) * vec4(uv*2-1, 1, 1)).xyz));
	vec3 terrainUpDir = normalize(vec3(renderer.worldOrigin));
	vec3 origin = inverse(renderer.viewMatrix)[3].xyz			;//		+viewDir*EPSILON;// BUGFIX for CRASH on Windows (NVIDIA Driver Bug?)
	vec3 endPosition = origin + viewDir * viewDistance;
	float startDistance = 0;
	float endDistance = viewDistance;
	if (!isUnderwater) {
		float hitDistance;
		if (TraceRayHitTerrain(origin, 0, viewDir, CLOUD_MAX_DISTANCE, hitDistance)) {
			endDistance = min(endDistance, hitDistance);
			startDistance = GetGroundFogRaymarchStartDistanceAlongRay(origin, viewDir, endDistance, terrainUpDir, FOG_TERRAIN_MAX_DISTANCE);
			if (startDistance >= endDistance) {
				imageStore(img_cloud[0], compute_coord, vec4(0));
				return;
			}
		}
	}
	vec3 startPosition = origin + viewDir * startDistance;
	
	// Get sun light
	vec3 lightPosition;
	float lightPower;
	int32_t lightID = GetSunLight(startPosition, lightPosition, lightPower);
	if (lightID == -1) {
		imageStore(img_cloud[0], compute_coord, vec4(0));
		return;
	}
	LightSourceInstanceData lightSource = renderer.lightSources[lightID].instance;
	vec3 relativeLightPosition = lightPosition - startPosition;
	float lightDistance = length(relativeLightPosition) - abs(lightSource.innerRadius);
	vec3 lightDir = normalize(relativeLightPosition);

	uint stableSeed = InitRandomSeed(compute_coord.x, compute_coord.y);
	// uint coherentSeed = InitRandomSeed(uint(xenonRendererData.frameIndex),0);
	// uint seed = InitRandomSeed(stableSeed, coherentSeed);
	
	vec4 fog = vec4(0);
	
	const vec3 fogColor = isUnderwater? vec3(0.005,0.02,0.04) : vec3(1,0.3,0.12);
	
	// raymarch
	const int RAYMARCH_STEPS = 5;
	float stepSize = (endDistance - startDistance) / (RAYMARCH_STEPS);
	float stepDistance = startDistance + RandomFloat(stableSeed) * stepSize;
	for (int i = 0; i < RAYMARCH_STEPS; i++) {
		vec3 rayOrigin = origin + viewDir * stepDistance;
		stepDistance += stepSize;
		float density = 0;
		float hitDistance;
		if (TraceRayHitTerrain(rayOrigin, 0, -terrainUpDir, FOG_TERRAIN_MAX_DISTANCE, hitDistance)) {
			density = isUnderwater? GetFogDensityUnderwater(rayOrigin * 0.02, hitDistance) : GetFogDensity((rayOrigin - windVelocity * float(renderer.timestamp)) * 0.02, hitDistance);
			if (!TraceRayInShadow(rayOrigin, 0, lightDir, lightDistance)) {
				fog.rgb += lightSource.color * lightPower * density * fogColor;
				fog.a += density;
			}
		}
	}
	
	fog *= stepSize;
	fog /= RAYMARCH_STEPS;
	fog *= renderer.globalLightingFactor;
	fog.a = clamp(fog.a, 0, 0.25) * renderer.globalLightingFactor * smoothstep(CLOUD_MAX_DISTANCE, CLOUD_MAX_DISTANCE/2, viewDistance);
	
	ApplyToneMapping(fog.rgb);
	imageStore(img_cloud[0], compute_coord, clamp(fog, vec4(0), vec4(1)));
}
