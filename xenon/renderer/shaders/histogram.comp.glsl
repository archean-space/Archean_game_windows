#include "common.inc.glsl"

// #extension GL_EXT_shader_atomic_float : enable

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
ivec2 compute_coord = ivec2(gl_GlobalInvocationID.xy);

void main() {
	ivec2 offset = imageSize(img_thumbnail) / 2 - imageSize(img_thumbnail) / 2 / XENON_RENDERER_HISTOGRAM_DIVIDER;
	vec4 color = clamp(imageLoad(img_thumbnail, compute_coord + offset), vec4(0.1), vec4(vec3(1000), 1));
	
	ivec2 halfSize = ivec2(gl_WorkGroupSize.xy * gl_NumWorkGroups.xy) / 2;
	color.rgb *= pow(1.0 - min(1.0, length(vec2(compute_coord - halfSize) / halfSize)), 0.25);
	
	// atomicAdd(xenonRendererData.histogram_total_luminance.r, color.r);
	// atomicAdd(xenonRendererData.histogram_total_luminance.g, color.g);
	// atomicAdd(xenonRendererData.histogram_total_luminance.b, color.b);
	// atomicAdd(xenonRendererData.histogram_total_luminance.a, 1);
}
