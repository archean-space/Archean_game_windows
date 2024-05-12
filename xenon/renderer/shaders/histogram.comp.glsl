#include "common.inc.glsl"

void main() {
	uvec2 size = imageSize(img_thumbnail);
	uvec2 imageOffset = size/4;
	vec4 luminance = vec4(0);
	for (uint x = 0; x < size.s/2; x+=2) {
		for (uint y = 0; y < size.t/2; y+=2) {
			vec4 color = imageLoad(img_thumbnail, ivec2(imageOffset + uvec2(x,y)));
			luminance += vec4(clamp(color.rgb, vec3(0.01), vec3(1e3)), 0.25);
		}
	}
	xenonRendererData.histogram_total_luminance.r = luminance.r;
	xenonRendererData.histogram_total_luminance.g = luminance.g;
	xenonRendererData.histogram_total_luminance.b = luminance.b;
	xenonRendererData.histogram_total_luminance.a = luminance.a;
}
