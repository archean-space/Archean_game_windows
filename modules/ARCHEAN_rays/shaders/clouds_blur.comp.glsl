#include "game/graphics/common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X + 1, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y + 1) in;

ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

layout(push_constant) uniform PushConstant {
	ivec2 blurDir;
	uint imageIndex;
};

// blur img_cloud
void main() {
	const float sigma = 2;
	const int blurSize = int(sigma*3);
	
	vec4 blurredColor = vec4(0.0);
	float weightSum = 0.0;
	for (int i = -blurSize; i <= blurSize; ++i) {
		float weight = gaussian(float(i), sigma);
		vec4 sampleColor = imageLoad(img_cloud[imageIndex], compute_coord + blurDir * i);
		blurredColor += sampleColor * weight;
		weightSum += weight;
	}
	blurredColor /= weightSum;
	imageStore(img_cloud[(imageIndex + 1) % 2], compute_coord, blurredColor);
}
