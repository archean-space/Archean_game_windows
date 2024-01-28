#include "common.inc.glsl"

layout(location = 0) in vec4 in_color;
layout(location = 0) out vec4 out_post;

void main() {
	float alpha = imageLoad(img_resolved, ivec2(gl_FragCoord.xy / imageSize(img_post) * imageSize(img_resolved))).a;
	if (alpha == 1) discard;
	
	float center = max(0, 1.0 - pow(length(gl_PointCoord * 2 - 1), 2));
	vec4 starColor = vec4(in_color * pow(center, 2));
	
	ApplyToneMapping(starColor.rgb);
	starColor.rgb = mix(vec3(0.5), starColor.rgb, contrast);
	
	out_post = vec4(starColor.rgb * pow(1-alpha, 4), 0);
}
