#include "game/graphics/common.inc.glsl"

layout(location = 0) out vec4 out_color;

void main() {
	out_color = imageLoad(img_emission, ivec2(gl_FragCoord.xy));
}
