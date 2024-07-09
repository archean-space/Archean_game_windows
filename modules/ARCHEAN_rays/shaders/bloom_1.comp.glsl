#include "game/graphics/common.inc.glsl"

// Filter by brightness & horizontal blur pass

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;

const float sigma = 3.0;
const int blurSize = int(sigma*3);

void main() {
	const ivec2 compute_coord = ivec2(gl_GlobalInvocationID);
	
	vec4 blurredColor = vec4(0.0);
	float weightSum = 0.0;
	for (int i = -blurSize; i <= blurSize; ++i) {
		float weight = gaussian(float(i), sigma);
		vec4 sampleColor = imageLoad(img_post, compute_coord + ivec2(i, 0));
		float brightness = dot(sampleColor.rgb, vec3(0.2126, 0.7152, 0.0722));
		blurredColor += sampleColor * weight * smoothstep(0.995, 1.0, brightness);
		weightSum += weight;
	}
	blurredColor /= weightSum;
	imageStore(img_bloom, compute_coord, blurredColor);
}
