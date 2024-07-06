#include "../common.inc.glsl"

vec3 GetViewSpacePositionFromDepthAndUV(float depth, vec2 uv) {
	vec4 viewSpacePos = inverse(xenonRendererData.config.projectionMatrixWithTAA) * vec4((uv * 2 - 1), depth, 1);
	viewSpacePos.xyz /= viewSpacePos.w;
	if (depth == 0) viewSpacePos.z = xenonRendererData.config.zFar;
	return viewSpacePos.xyz;
}

float GetDepth(vec2 uv) {
	return texture(sampler_depth, uv).r;
}

float GetTrueDistanceFromDepthBuffer(float depth) {
	if (depth == 0 || depth == 1) return xenonRendererData.config.zFar;
	return 2.0 * (xenonRendererData.config.zFar * xenonRendererData.config.zNear) / (xenonRendererData.config.zNear + xenonRendererData.config.zFar - (depth * 2.0 - 1.0) * (xenonRendererData.config.zNear - xenonRendererData.config.zFar));
}

layout(local_size_x = 17, local_size_y = 17) in;

void main() {
	const int nbSamples = 32;
	const float maxDistance = 100.0;
	const float ambient = 0;
	
	const ivec2 coords = ivec2(gl_GlobalInvocationID);
	const vec4 normalAndSsaoStrength = imageLoad(img_normal_or_debug, coords);
	const float ssaoStrength = normalAndSsaoStrength.a;
	const vec3 viewSpaceNormal = normalize(WORLD2VIEWNORMAL * normalAndSsaoStrength.xyz);
	if (ssaoStrength == 0) return;
	
	uint seed = InitRandomSeed(uint(xenonRendererData.frameIndex), InitRandomSeed(uint(coords.x), uint(coords.y)));
	const vec2 uv = vec2(coords) / imageSize(img_depth);
	const vec3 viewSpacePos = GetViewSpacePositionFromDepthAndUV(GetDepth(uv), uv);
	if (-viewSpacePos.z > maxDistance) return;
	float kernelSize = mix(0.05, 10.0, smoothstep(0.02, maxDistance, -viewSpacePos.z));
	
	float occluded = 0;
	for (int i = 0; i < nbSamples; ++i) {
		vec3 offset = RandomInUnitSphere(seed);
		vec3 viewSpaceSample = viewSpacePos + normalize(offset * dot(offset, viewSpaceNormal)) * RandomFloat(seed) * kernelSize;
		vec4 clipSpaceCoord = xenonRendererData.config.projectionMatrixWithTAA * vec4(viewSpaceSample, 1);
		vec2 uv2 = (clipSpaceCoord.xyz / clipSpaceCoord.w).xy * 0.5 + 0.5;
		float sampleDist = -viewSpaceSample.z;
		float sampleDepthDist = GetTrueDistanceFromDepthBuffer(GetDepth(uv2));
		if (sampleDist > sampleDepthDist) {
			occluded += smoothstep(kernelSize*4, kernelSize, sampleDist - sampleDepthDist);
		}
	}
	float ssao = clamp(occluded / float(nbSamples), 0, 1) * clamp(smoothstep(maxDistance, maxDistance/3, -viewSpacePos.z), 0, 1) * clamp(ssaoStrength, 0, 1);
	
	vec4 composite = imageLoad(img_composite, coords);
	imageStore(img_composite, coords, vec4(composite.rgb * mix(1.0, ambient, ssao), composite.a));

	// Debug
	if (xenonRendererData.config.debugViewMode == RENDERER_DEBUG_VIEWMODE_SSAO) {
		imageStore(img_normal_or_debug, coords, vec4(vec3(1 - ssao), 1));
	}
}
