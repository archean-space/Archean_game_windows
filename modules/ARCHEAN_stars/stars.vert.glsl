#include "common.inc.glsl"

layout(location = 0) out vec4 out_color;

uint seed = gl_VertexIndex;

void main() {
	float nbRatio = pow(1e6 / nbStars, 0.333);
	
	// Position
	float distance = 1e13;
	vec3 pos = RandomInUnitSphere(seed) * distance + vec3((RandomFloat(seed)-0.5) * RandomFloat(seed)*distance, (RandomFloat(seed)-0.5) * RandomFloat(seed)*distance, (RandomFloat(seed)-0.5) * RandomFloat(seed)*distance);
	pos.y = sign(pos.y) * pow(abs(pos.y), mix(0.92, 0.97, step(nbStars * 0.5, gl_VertexIndex)));
	pos.z = sign(pos.z) * pow(abs(pos.z), 0.975);
	gl_Position = xenonRendererData.config.projectionMatrix * viewMatrix * vec4(pos,1);
	
	// Color
	vec3 color1 = pow(abs(RandomInUnitSphere(seed)) * vec3((1-abs(Simplex(pos/8e11))), abs(Simplex(pos/1e12)), abs(Simplex(pos/2e12))), vec3(0.1));
	vec3 color2 = pow(abs(RandomInUnitSphere(seed)), vec3(0.25));
	
	// Luminosity
	float smallStars = (abs(Simplex(pos/4e12)) + abs(Simplex(pos/8e12))) * nbRatio;
	float normalStars = step(0.9, RandomFloat(seed)) * abs(Simplex(pos/8e12)) * nbRatio;
	float brightStars = step(1 - 5000.0/nbStars, RandomFloat(seed));
	float veryBrightStars = step(1 - 400.0/nbStars, RandomFloat(seed));
	float ultraBrightStars = step(1 - 15.0/nbStars, RandomFloat(seed));
	
	// Size
	gl_PointSize = clamp(RandomFloat(seed) * 3, 2, 3);
	// Compensate for darkening on some monitors when moving
	float starBrightnessCompensationForMonitorDuringMovement = 1.1;
	if (starBrightnessCompensationForMonitorDuringMovement > 1.001) {
		vec2 ndc = gl_Position.xy / gl_Position.w;
		vec2 screenSpacePos = ndc.xy * 0.5 + 0.5;
		vec2 motion = imageLoad(img_motion, ivec2(screenSpacePos * xenonRendererData.config.renderScale)).xy;
		if (abs(motion.x) + abs(motion.y) > 0.001) gl_PointSize *= starBrightnessCompensationForMonitorDuringMovement;
	}
	
	// Final color + intensity
	out_color = vec4(
		+ color1 * smallStars * 0.2
		+ color1 * normalStars
		+ color2 * brightStars * 4
		+ color2 * veryBrightStars * 64
		+ color2 * ultraBrightStars * 1024
	, 1) * 0.01;
}
