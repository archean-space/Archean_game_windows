layout(location = 0) out vec4 out_color;

void main() {
	float center = length(1.0-abs(gl_PointCoord-0.5)*2.5);
	out_color = vec4(0,1,1, 0.5) * (pow(center, 8) - pow(center, 20)/10);
}
