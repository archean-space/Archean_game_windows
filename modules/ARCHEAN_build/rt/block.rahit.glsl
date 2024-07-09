#define SHADER_RAHIT
#include "game/graphics/common.inc.glsl"
#include "../Block.inc.glsl"

void main() {
	BlockColor blockMaterial = BlockColor(GEOMETRY.material.uv2)[gl_PrimitiveID];
	vec4 color;
	color.rgb = vec3(blockMaterial.r, blockMaterial.g, blockMaterial.b) / 255.0;
	color.a = (float(blockMaterial.a & 0xf) + 1) / 16.0;
	
	if (color.a < 1) {
		RayTransparent(color.rgb * (1 - color.a));
	} else {
		RayOpaque();
	}
}
