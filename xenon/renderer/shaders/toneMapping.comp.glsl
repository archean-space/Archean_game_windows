#include "common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

void main() {
	ivec2 compute_size = imageSize(img_resolved);
	if (compute_coord.x >= compute_size.x || compute_coord.y >= compute_size.y) return;
	
	vec4 color = imageLoad(img_resolved, compute_coord);
	
	// Copy to history BEFORE applying Tone Mapping
	imageStore(img_history, compute_coord, color);
	
	ApplyToneMapping(color.rgb);
	color = clamp(color, vec4(0), vec4(1));
	
	imageStore(img_resolved, compute_coord, color);
}
