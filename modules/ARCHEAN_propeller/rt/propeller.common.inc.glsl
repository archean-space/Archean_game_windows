#include "game/graphics/common.inc.glsl"

float sdBox( vec3 p, vec3 b ) {
	vec3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

vec4 opElongate( in vec3 p, in vec3 h ) {
	vec3 q = abs(p) - h;
	return vec4( max(q,0.0), min(max(q.x,max(q.y,q.z)),0.0) );
}

float sdCappedCylinder( vec3 p, vec2 h ) {
	vec2 d = abs(vec2(length(p.xz),p.y)) - h;
	return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

mat2 RotationMatrix(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat2(c, -s, s, c);
}

PropellerData prop = PropellerData(AABB.data);

float sdProp(vec3 p) {
	// N blades
	float th = atan(p.z, p.x);
	float angle = float(prop.blades + 2u) * th * 0.5;
	p.xz = RotationMatrix(angle) * p.xz;
	
	// Blade Pitch
	p.yz = RotationMatrix(-prop.pitch * 3.141592654 / 4. * sign(p.x)) * p.yz;
	
	// Blade Twist
	p.y -= p.x / prop.radius * p.z * prop.twist * 2. / float(prop.blades);
	
	// Blade Shape
	float width = prop.width / 8. * float(prop.blades) * (pow(smoothstep(0.0, 0.5, abs(p.x) / prop.radius), 0.5) + pow(smoothstep(1.25, 0.5, abs(p.x) / prop.radius), 0.5));
	float thickness = prop.width / 20. * (0.1 + (1.0 - pow(clamp(abs(p.z) / width, 0., 1.), 2.)) * smoothstep(1.0, 0.5, abs(p.x) / prop.radius));
	
	// Flat tips
	float flatD = sdBox(p, vec3(prop.radius, thickness, width));

	// Rounded tips
	vec4 w = opElongate(p, vec3(prop.radius-width,0.,0.));
	float roundedD = sdCappedCylinder(w.xyz, vec2(width,thickness));
	
	return mix(flatD, roundedD, prop.roundedTips);
}

float Sdf(vec3 p) {
	return min(sdProp(p), sdCappedCylinder(p, vec2(max(prop.base, prop.width/4.), prop.width/4.)));
}
