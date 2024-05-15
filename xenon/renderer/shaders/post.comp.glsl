#include "common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

void main() {
	const ivec2 compute_size = imageSize(img_post);
	if (compute_coord.x >= compute_size.x || compute_coord.y >= compute_size.y) return;
	const vec2 render_uv = vec2(compute_coord) / vec2(compute_size);
	const ivec2 render_coord = ivec2(render_uv * vec2(imageSize(img_composite)));
	
	// Read the rendered image
	vec4 color = imageLoad(img_post, compute_coord);
	
	// Dithering
	if ((xenonRendererData.config.options & RENDER_OPTION_DITHERING) != 0) {
		uint seed = InitRandomSeed(compute_coord.x, compute_coord.y);
		color.rgb += (vec3(RandomFloat(seed), RandomFloat(seed), RandomFloat(seed)) - 0.5) / 127.0;
	}
	
	// Debug View Mode
	if (xenonRendererData.config.debugViewMode != 0) {
		vec4 debug = imageLoad(img_normal_or_debug, render_coord);
		color.rgb = mix(color.rgb, debug.rgb, debug.a);
	}
	
	// This performs a blend like a rasterization pipeline would, to add the rendered image on top of say a background that could have been added via PostCommands
	vec4 swapchain = imageLoad(img_swapchain, compute_coord);
	imageStore(img_swapchain, compute_coord, vec4(swapchain.rgb * (1-color.a) + color.rgb, 1));
}
