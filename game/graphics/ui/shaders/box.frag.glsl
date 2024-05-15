#include "box_common.inc.glsl"
#include "xenon/renderer/shaders/common.inc.glsl"

layout(location = 0) in vec2 in_uv;
layout(location = 0) out vec4 out_color;

void main() {
	out_color = box.color;
	if (box.texture != 0) {
		vec2 uv = in_uv;
		vec4 tex = texture(textures[box.texture], uv);
		out_color = mix(out_color, tex, tex.a);
	}
}
