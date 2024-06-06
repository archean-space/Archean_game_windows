#define SHADER_FSR
#include "../common.inc.glsl"

layout(set = 1, binding = 0) uniform sampler2D sampler_output;
layout(set = 1, binding = 1, rgba8) uniform image2D img_swapchain;

layout(push_constant) uniform PushConstant {
	FSRPushConstant pushConstant;
};

#define A_GPU 1
#define A_GLSL 1
#include "../../external/fsr/ffx_a.h.glsl"
#define FSR_RCAS_F 1

AF4 FsrRcasLoadF(ASU2 p) {return AF4(imageLoad(img_swapchain,p));}
void FsrRcasInputF(inout AF1 r, inout AF1 g, inout AF1 b) {}

#include "../../external/fsr/ffx_fsr1.h.glsl"

layout(local_size_x = 64) in;

void Filter(AU2 pos) {
	AF3 c;
	FsrRcasF(c.r, c.g, c.b, pos, pushConstant.Const0);
	imageStore(img_swapchain, ASU2(pos), vec4(c,1));
}

void main() {
	AU2 gxy = ARmp8x8(gl_LocalInvocationID.x) + AU2(gl_WorkGroupID.x << 4u, gl_WorkGroupID.y << 4u);
	Filter(gxy);
	
	gxy.x += 8u;
	Filter(gxy);
	
	gxy.y += 8u;
	Filter(gxy);
	
	gxy.x -= 8u;
	Filter(gxy);
}
