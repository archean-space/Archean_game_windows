#include "text_common.inc.glsl"
#include "xenon/renderer/shaders/common.inc.glsl"

layout(location = 0) out flat uint out_char;

void main() {
	ivec2 screenSize = imageSize(img_post);
	float screenRatio = float(screenSize.x) / float(screenSize.y);
	float offset = (size * gl_InstanceIndex) - ((length-1) * size * 0.5);
	gl_Position = vec4((x + offset*0.6/screenRatio), y, 0, 1);
	gl_PointSize = size * float(screenSize.y);
	out_char = (text[gl_InstanceIndex / 4] >> ((gl_InstanceIndex % 4) * 8)) & 0xff;
}
