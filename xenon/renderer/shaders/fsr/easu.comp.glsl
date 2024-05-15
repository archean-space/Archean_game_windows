#define SHADER_FSR
#include "../common.inc.glsl"

layout(push_constant) uniform PushConstant {
	FSRPushConstant pushConstant;
};

#define A_GPU 1
#define A_GLSL 1
#include "../../external/fsr/ffx_a.h.glsl"
#define FSR_EASU_F 1

AF4 FsrEasuRF(AF2 p) {return AF4(textureGather(sampler_resolved,p,0));}
AF4 FsrEasuGF(AF2 p) {return AF4(textureGather(sampler_resolved,p,1));}
AF4 FsrEasuBF(AF2 p) {return AF4(textureGather(sampler_resolved,p,2));}

#include "../../external/fsr/ffx_fsr1.h.glsl"

layout(local_size_x = 64) in;

void Filter(AU2 pos) {
	AF3 c;
	FsrEasuF(c, pos, pushConstant.Const0, pushConstant.Const1, pushConstant.Const2, pushConstant.Const3);
	imageStore(img_post, ASU2(pos), vec4(c,1));
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
