#include "game/graphics/common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X + 1, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y + 1) in;

ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

// read from img_cloud, write to img_post
void main() {
	vec2 uv = vec2(compute_coord) / vec2(imageSize(img_post));
	vec4 clouds = texture(sampler_cloud, uv);
	vec4 color = imageLoad(img_post, compute_coord);
	ivec2 render_coords = ivec2(uv * vec2(imageSize(img_normal_or_debug)));
	color.rgb = mix(color.rgb, clouds.rgb, clouds.a);
	imageStore(img_post, compute_coord, color);
}
