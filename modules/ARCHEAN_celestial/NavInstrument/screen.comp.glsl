#include "screen.common.inc.glsl"

layout(local_size_x = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_X, local_size_y = XENON_RENDERER_SCREEN_COMPUTE_LOCAL_SIZE_Y) in;
layout(set = 1, binding = 0, rgba8) uniform image2D images[];

vec2 coord = vec2(gl_GlobalInvocationID.xy);
vec2 uv = coord / vec2(SCREEN_COMPUTE_WIDTH, SCREEN_COMPUTE_HEIGHT);

const vec3 skyColor = vec3(0.1,0.18,0.35);
const vec3 groundColor = vec3(0.25,0.15,0.1);
const vec2 textSize = vec2(SCREEN_TEXT_SIZE_X, SCREEN_TEXT_SIZE_Y);

float saturate(float x) {return clamp(x, 0, 1);}

float write(int c, vec2 uv) {
	float charPos = max(0, int(c) - 32); // will get a value between 0(space) and 94 (~)
	// The font atlas used is a 10x10 grid
	const float grid = 10;
	vec2 coord = vec2(
		uv.x / grid + floor(mod(charPos, grid))/grid,
		uv.y / grid + floor(charPos/grid)/grid
	);
	if (uv.x > 1) return 0;
	if (uv.y > 1) return 0;
	if (uv.x < 0) return 0;
	if (uv.y < 0) return 0;
	return texture(textures[0], coord).r;
}

float writeNumber(int n, vec2 uv) {
	return write(48 + n, -uv * textSize);
}

void main() {
	vec4 overlay = imageLoad(images[imageIndex*2], ivec2(uv*vec2(imageSize(images[imageIndex*2]))));
	vec3 col = vec3(0);
	
	if (mode > 0 && screenPowerCycle > 0) {
		// Screen From -1 down to +1 up
		vec2 screen = (uv * 2 - 1) * vec2(-1);
		
		// compute pitch
		float pitch = dot(-planetUp, forward);
		
		// compute roll
		float roll = atan(dot(normalize(cross(planetUp, forward)), up), dot(planetUp, up));
		float sinX = sin(roll);
		float cosX = cos(roll);
		mat2 screenRotation = mat2(cosX, -sinX, sinX, cosX);
		
		// FLIGHT MODE
		if (mode == 1) {
			const float zoom = 1.5;
			vec2 horizon = screenRotation * screen;
			horizon.y -= pitch * zoom;
			horizon /= zoom;
			
			// Horizon Color
			col = groundColor; // Brown
			if (horizon.y > 0) col = skyColor; // Blue sky
			
			// Middle line
			if (horizon.y > -0.005 && horizon.y < 0.005) col = vec3(0.3);
			
			// +45 degrees Lines
			col = mix(col, vec3(0.4), writeNumber(4, horizon + vec2(-0.1,-0.61)));
			col = mix(col, vec3(0.4), writeNumber(5, horizon + vec2(-0.055,-0.61)));
			if (horizon.y > 0.495 && horizon.y < 0.505 && horizon.x > -0.5 && horizon.x < 0.5) col = vec3(0.3);
			// -45 degrees Lines
			col = mix(col, vec3(0.4), writeNumber(4, horizon + vec2(-0.1,0.39)));
			col = mix(col, vec3(0.4), writeNumber(5, horizon + vec2(-0.055,0.39)));
			if (horizon.y > -0.505 && horizon.y < -0.495 && horizon.x > -0.5 && horizon.x < 0.5) col = vec3(0.3);
			
			// +30 degrees Lines
			col = mix(col, vec3(0.4), writeNumber(3, horizon + vec2(-0.1,-0.445)));
			col = mix(col, vec3(0.4), writeNumber(0, horizon + vec2(-0.055,-0.445)));
			if (horizon.y > 0.33 && horizon.y < 0.34 && horizon.x > -0.3 && horizon.x < 0.3) col = vec3(0.3);
			// -30 degrees Lines
			col = mix(col, vec3(0.4), writeNumber(3, horizon + vec2(-0.1,0.225)));
			col = mix(col, vec3(0.4), writeNumber(0, horizon + vec2(-0.055,0.225)));
			if (horizon.y > -0.34 && horizon.y < -0.33 && horizon.x > -0.3 && horizon.x < 0.3) col = vec3(0.3);
			
			// +15 degrees Lines
			col = mix(col, vec3(0.4), writeNumber(1, horizon + vec2(-0.1,-0.27)));
			col = mix(col, vec3(0.4), writeNumber(5, horizon + vec2(-0.055,-0.27)));
			if (horizon.y > 0.155 && horizon.y < 0.165 && horizon.x > -0.1 && horizon.x < 0.1) col = vec3(0.3);
			// -15 degrees Lines
			col = mix(col, vec3(0.4), writeNumber(1, horizon + vec2(-0.1,0.05)));
			col = mix(col, vec3(0.4), writeNumber(5, horizon + vec2(-0.055,0.05)));
			if (horizon.y > -0.165 && horizon.y < -0.155 && horizon.x > -0.1 && horizon.x < 0.1) col = vec3(0.3);
			
			// 90 degree line
			if (abs(horizon.y) > 0.98 && abs(horizon.y) < 1.02) col = vec3(0);
			// Next 45 degrees lines
			if (abs(horizon.y) > 1.495 && abs(horizon.y) < 1.505 && horizon.x > -0.5 && horizon.x < 0.5) col = vec3(0.3);
			
			// Center marker
			if (screen.y > -0.02 && screen.y < 0.02 && (screen.x < -0.8 || screen.x > 0.8)) col = vec3(0.5, 0.5, 0); // thick yellow lines
			if (screen.y > -0.005 && screen.y < 0.005 && (screen.x < -0.6 || screen.x > 0.6)) col = vec3(0.5, 0.5, 0); // thin yellow lines
			if (screen.y > -0.02 && screen.y < 0.02 && screen.x > -0.02 && screen.x < 0.02) col = vec3(0.5, 0.5, 0); // Center yellow square
			
			// Velocity
			vec2 v = velocity.xz / 20;
			if (length(v) > 0.2) v = normalize(v) / 5;
			vec2 vcenter = vec2(0.705, -0.705) + v;
			if (screen.y > -0.9 && screen.y < -0.5 && screen.x > 0.7 && screen.x < 0.71) col = vec3(0, 0.3, 0); // horizontal line
			if (screen.y > -0.71 && screen.y < -0.7 && screen.x > 0.5 && screen.x < 0.9) col = vec3(0, 0.3, 0); // vertical line
			if (screen.y > vcenter.y - 0.03 && screen.y < vcenter.y + 0.03 && screen.x > vcenter.x - 0.03 && screen.x < vcenter.x + 0.03) col = vec3(0.5, 0, 0); // Red square
		} else
		// ORBIT MODE
		if (mode == 2) {
			// Orbital parameters for ellipse
			const float globeSize = 0.8;
			float r_periapsis = periapsis + planetInnerRadius;
			float r_apoapsis = apoapsis + planetInnerRadius;
			float a = (r_periapsis + r_apoapsis) / 2;
			float e = (r_apoapsis - r_periapsis) / (r_apoapsis + r_periapsis);
			float b = a * sqrt(1 - e*e);
			
			// Navball+ellipse position and scale
			float ballScale = planetInnerRadius / a;
			float ellipseScale = 1;
			if (ballScale > 1.0) {
				ballScale = 1;
				ellipseScale = a / planetInnerRadius;
			} else if (ballScale < 0.5) {
				ballScale = 0.5;
				ellipseScale = a / planetInnerRadius / 2;
			}
			float ellipseOffset = 0;
			vec2 navballscreen = screen / globeSize / ballScale;
			float ballOffset = -e / ballScale;
			if (ballOffset < (1-1/ballScale)) {
				ballOffset = (1-1/ballScale);
				ellipseOffset = ballOffset + e / ballScale;
			}
			navballscreen.x += ballOffset;
			vec2 horizon = screenRotation * navballscreen;
			float heading_0 = horizon.x - (heading / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			float heading_plus90 = horizon.x - ((heading - 90) / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			float heading_minus90 = horizon.x - ((heading + 90) / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			float heading_plus180 = horizon.x - ((heading - 180) / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			float heading_minus180 = horizon.x - ((heading + 180) / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			horizon.y -= pitch * sqrt(1 - pow(abs(horizon.x), 2));
			float horizontalLineFade = 1-clamp(abs(horizon.x), 0, 1);
			float verticalLineFade = 1-clamp(abs(horizon.y), 0, 1);
			
			// Horizon Color
			col = groundColor; // Brown
			if (horizon.y > 0) col = skyColor; // Blue sky
			
			// Middle line
			if (horizon.y > -0.005 && horizon.y < 0.005) col = vec3(0.3);
			
			// Heading lines
			// 0 (north)
			if (heading_0 > -0.005 && heading_0 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_0 - 0.045, horizon.y - 0.03)));
			// 180 (south)
			if (heading_plus180 > -0.005 && heading_plus180 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			if (heading_minus180 > -0.005 && heading_minus180 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			col = mix(col, vec3(0.4), writeNumber(1, vec2(heading_plus180 - 0.04, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(8, vec2(heading_plus180, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_plus180 + 0.045, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(1, vec2(heading_minus180 - 0.04, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(8, vec2(heading_minus180, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_minus180 + 0.045, horizon.y - 0.03)));
			// +90
			if (heading_plus90 > -0.005 && heading_plus90 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			col = mix(col, vec3(0.4), writeNumber(-5, vec2(heading_plus90 - 0.045, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(9, vec2(heading_plus90, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_plus90 + 0.045, horizon.y - 0.03)));
			// -90
			if (heading_minus90 > -0.005 && heading_minus90 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			col = mix(col, vec3(0.4), writeNumber(-3, vec2(heading_minus90 - 0.045, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(9, vec2(heading_minus90, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_minus90 + 0.045, horizon.y - 0.03)));
			
			// Circle Mask
			float navballCircle = saturate(length(navballscreen));
			col *= 1-pow(navballCircle, 10/ballScale);

			// Ellipse orbit preview
			if (r_periapsis > 0 && apoapsis > periapsis && apoapsis > 0.01) {
				vec2 position = screen * a / globeSize / ellipseScale;
				float ellipse = pow(position.x / a + ellipseOffset, 2.0) + pow(position.y / b, 2.0);
				if (navballCircle == 1 && ellipse < (1 + 0.01 / ellipseScale) && ellipse > (1 - 0.02 / ellipseScale)) col = mix(col, (r_periapsis > planetOuterRadius)? vec3(0,0.5,0.5) : vec3(0.5,0,0), ellipse);
				// Altitude ratio between periapsis and apoapsis
				if (screen.y < -0.92) {
					float delta = abs(r_apoapsis - r_periapsis);
					float t = clamp((altitude - r_periapsis + planetInnerRadius) / delta, 0.03, 0.97);
					float s = screen.x * -0.5 + 0.5;
					float diff = abs(t-s);
					if (delta < 1000) col = vec3(0,0.5,0.5);
					else col = mix(vec3(0.1), vec3(0,0.5,0.5), smoothstep(mix(0.995, 0.0, smoothstep(100000, 1000, delta)), 1.0, 1-diff));
				}
			}
			
			// Speed Indicator
			float speed = length(velocity);
			if (targetSpeed > 0) {
				if (screen.y > -0.505 && screen.y < 0.505 && screen.x > 0.88) {
					float delta = speed - targetSpeed;
					float t = clamp(delta / targetSpeedRange, -1, +1) * 0.5;
					if (screen.y > t-0.005 && screen.y < t+0.005 || abs(delta) < 1.0) {
						col = vec3(0,0.5,0.5);
					} else {
						if (screen.y > -0.01 && screen.y < 0.01) {
							col = vec3(0);
						} else {
							col = vec3(0.1);
						}
					}
				}
			}
			
			// Altitude Indicator
			if (targetAltitude > 0) {
				if (screen.y > -0.5 && screen.y < 0.5 && screen.x < -0.88) {
					float delta = altitude - targetAltitude;
					float t = clamp(delta / targetAltitudeRange, -1, +1) * 0.5;
					if (screen.y > t-0.005 && screen.y < t+0.005 || abs(delta) < 2000.0) {
						col = vec3(0,0.5,0.5);
					} else {
						if (screen.y > -0.01 && screen.y < 0.01) {
							col = vec3(0);
						} else {
							col = vec3(0.1);
						}
					}
				}
			}

			// Center marker
			if (navballscreen.y > -0.004 && navballscreen.y < 0.004 && navballscreen.x > -1 && navballscreen.x < 1) col = mix(col, vec3(0), 1-clamp(abs(screen.x), 0, 1)); // Center line (horizontal)
			if (navballscreen.y > -1 && navballscreen.y < 1 && navballscreen.x > -0.004 && navballscreen.x < 0.004) col = mix(col, vec3(0), 1-clamp(abs(screen.y), 0, 1)); // Center line (vertical)
			
			// Prograde/Retrograde Orbital Velocity (cross)
			vec3 v = normalize(velocity);
			bool prograde = dot(forward, v) > 0;
			vec2 cross = vec2(saturate(dot(right, v)) - saturate(dot(-right, v)), dot(up, v));
			if (!prograde) cross *= -1;
			if (length(cross) > 1) cross = normalize(cross);
			vec2 navballScreenCross = navballscreen - cross;
			float crossDistance = length(navballScreenCross);
			if (crossDistance < 0.1 && (abs(navballScreenCross).y < 0.005 || abs(navballScreenCross).x < 0.005)) {
				col = prograde ? vec3(0.8) : vec3(0.8, 0, 0);
			}

			// Prograde/Retrograde Target Direction (circle)
			if (length(targetDirection) > 0) {
				vec3 t = normalize(targetDirection);
				bool t_prograde = dot(forward, t) > 0;
				vec2 circle = vec2(saturate(dot(right, t)) - saturate(dot(-right, t)), dot(up, t));
				if (!t_prograde) circle *= -1;
				if (length(circle) > 1) circle = normalize(circle);
				float circleDistance = length(navballscreen - circle);
				if (circleDistance < 0.04 && circleDistance > 0.03) {
					col = t_prograde ? vec3(0.8) : vec3(0.8, 0, 0);
				}
			}
			
		}else
		// LOCATOR MODE
		if (mode == 3) {
			const float globeSize = 0.72;
			vec2 navballscreen = screen / globeSize;
			vec2 horizon = screenRotation * navballscreen;
			float heading_0 = horizon.x - (heading / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			float heading_plus90 = horizon.x - ((heading - 90) / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			float heading_minus90 = horizon.x - ((heading + 90) / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			float heading_plus180 = horizon.x - ((heading - 180) / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			float heading_minus180 = horizon.x - ((heading + 180) / 180 * PI) * sqrt(1 - pow(abs(horizon.y), 2));
			horizon.y -= pitch * sqrt(1 - pow(abs(horizon.x), 2));
			float horizontalLineFade = 1-clamp(abs(horizon.x), 0, 1);
			float verticalLineFade = 1-clamp(abs(horizon.y), 0, 1);
			
			// Horizon Color
			col = groundColor; // Brown
			if (horizon.y > 0) col = skyColor; // Blue sky
			
			// Middle line
			if (horizon.y > -0.005 && horizon.y < 0.005) col = vec3(0.25);
			
			// Heading lines
			// 0 (north)
			if (heading_0 > -0.005 && heading_0 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_0 - 0.045, horizon.y - 0.03)));
			// 180 (south)
			if (heading_plus180 > -0.005 && heading_plus180 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			if (heading_minus180 > -0.005 && heading_minus180 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			col = mix(col, vec3(0.4), writeNumber(1, vec2(heading_plus180 - 0.04, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(8, vec2(heading_plus180, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_plus180 + 0.045, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(1, vec2(heading_minus180 - 0.04, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(8, vec2(heading_minus180, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_minus180 + 0.045, horizon.y - 0.03)));
			// +90
			if (heading_plus90 > -0.005 && heading_plus90 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			col = mix(col, vec3(0.4), writeNumber(-5, vec2(heading_plus90 - 0.045, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(9, vec2(heading_plus90, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_plus90 + 0.045, horizon.y - 0.03)));
			// -90
			if (heading_minus90 > -0.005 && heading_minus90 < +0.005) col = mix(col, vec3(0.3), verticalLineFade);
			col = mix(col, vec3(0.4), writeNumber(-3, vec2(heading_minus90 - 0.045, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(9, vec2(heading_minus90, horizon.y - 0.03)));
			col = mix(col, vec3(0.4), writeNumber(0, vec2(heading_minus90 + 0.045, horizon.y - 0.03)));
			
			// Circle Mask
			float navballCircle = saturate(length(navballscreen));
			col *= 1-pow(navballCircle, 10);

			// Center marker
			if (navballscreen.y > -0.004 && navballscreen.y < 0.004 && navballscreen.x > -1 && navballscreen.x < 1) col = mix(col, vec3(0), 1-clamp(abs(screen.x), 0, 1)); // Center line (horizontal)
			if (navballscreen.y > -1 && navballscreen.y < 1 && navballscreen.x > -0.004 && navballscreen.x < 0.004) col = mix(col, vec3(0), 1-clamp(abs(screen.y), 0, 1)); // Center line (vertical)
			
			// Prograde/Retrograde Orbital Velocity (cross)
			vec3 v = normalize(velocity);
			bool prograde = dot(forward, v) > 0;
			vec2 cross = vec2(saturate(dot(right, v)) - saturate(dot(-right, v)), dot(up, v));
			if (!prograde) cross *= -1;
			if (length(cross) > 1) cross = normalize(cross);
			vec2 navballScreenCross = navballscreen - cross;
			float crossDistance = length(navballScreenCross);
			if (crossDistance < 0.1 && (abs(navballScreenCross).y < 0.005 || abs(navballScreenCross).x < 0.005)) {
				col = prograde ? vec3(0.8) : vec3(0.8, 0, 0);
			}

			// Prograde/Retrograde Target Direction (circle)
			if (length(targetDirection) > 0) {
				vec3 t = normalize(targetDirection);
				bool t_prograde = dot(forward, t) > 0;
				vec2 circle = vec2(saturate(dot(right, t)) - saturate(dot(-right, t)), dot(up, t));
				if (!t_prograde) circle *= -1;
				if (length(circle) > 1) circle = normalize(circle);
				float circleDistance = length(navballscreen - circle);
				if (circleDistance < 0.04 && circleDistance > 0.03) {
					col = t_prograde ? vec3(0.8) : vec3(0.8, 0, 0);
				}
			}
			
		}
	}
	
	imageStore(images[imageIndex*2+1], ivec2(coord), vec4(mix(col, overlay.rgb, overlay.a), 1));
}
