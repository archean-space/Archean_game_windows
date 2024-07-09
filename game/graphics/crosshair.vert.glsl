layout(push_constant) uniform PushConstant {
	float ui_scaling;
};

void main() {
	gl_Position = vec4(0,0,0,1);
	gl_PointSize = 24 * ui_scaling;
}
