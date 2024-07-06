#include "game/graphics/common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
layout(set = 2, binding = 0, rg32f) uniform image2D images[];

ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

layout(push_constant) uniform PushConstant {
	mat4 invViewMatrix;
	ivec2 blurDir;
	float boundingRadius;
	uint32_t imageIndex;
};

void main() {
	const int blurSize = 6;
	ivec2 size = ivec2(imageSize(images[imageIndex]).xy);
	vec2 pixel = imageLoad(images[imageIndex], compute_coord).rg;
	for (int i = -blurSize; i <= blurSize; ++i) if (i != 0) {
		ivec2 coord = compute_coord + blurDir * i;
		if (coord.x >= 0 && coord.y >= 0 && coord.x < size.x && coord.y < size.y) {
			vec2 sampleColor = imageLoad(images[imageIndex], coord).rg;
			pixel = min(pixel, sampleColor * pow(2.0, float(max(0,abs(i)-2))));
		}
	}
	imageStore(images[imageIndex], compute_coord, vec4(pixel,0,0));
}
