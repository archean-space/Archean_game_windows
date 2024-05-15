layout(location = 0) out vec4 out_color;

layout(buffer_reference, std430, buffer_reference_align = 4) buffer PixelBuffer {
	uint32_t data[];
};

layout(push_constant) uniform PushConstant {
	PixelBuffer pixelBuffer;
	uvec2 start;
	uvec2 size;
	uint scale;
};

void main() {
	ivec2 coord = ivec2(round(gl_FragCoord.xy - start) / scale);
	
	if (coord.x < 0 || coord.y < 0 || coord.x >= size.x || coord.y >= size.y) {
		discard;
	} else {
		
		uint coordIndex = coord.x + coord.y * size.x;
		uint colorValue = pixelBuffer.data[coordIndex];
		uvec4 color;
		color.r = colorValue & 0xFF;
		color.g = (colorValue >> 8) & 0xFF;
		color.b = (colorValue >> 16) & 0xFF;
		color.a = (colorValue >> 24) & 0xFF;
		
		out_color = vec4(color) / 255.0;
	}
}
