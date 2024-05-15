// uint InitRandomSeed(uint val0, uint val1) {
// 	uint v0 = val0, v1 = val1, s0 = 0u;
// 	for (uint n = 0u; n < 16u; n++) {
// 		s0 += 0x9e3779b9u;
// 		v0 += ((v1 << 4) + 0xa341316cu) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4u);
// 		v1 += ((v0 << 4) + 0xad90777du) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761eu);
// 	}
// 	return v0;
// }

// uint GradUintHash(uvec3 p) {
// 	return InitRandomSeed(p.x, InitRandomSeed(p.y, p.z));
// }

uint GradUintHash(uvec3 p) {
	uint h = 8u, _;
	h += p.x & 0xffffu;
	_ = (((p.x >> 16u) & 0xffffu) << 11u) ^ h;
	h = (h << 16u) ^ _;
	h += h >> 11u;
	h += p.y & 0xffffu;
	_ = (((p.y >> 16u) & 0xffffu) << 11u) ^ h;
	h = (h << 16u) ^ _;
	h += h >> 11u;
	h += p.z & 0xffffu;
	_ = (((p.z >> 16u) & 0xffffu) << 11u) ^ h;
	h = (h << 16u) ^ _;
	h += h >> 11u;
	h ^= h << 3u;
	h += h >> 5u;
	h ^= h << 4u;
	h += h >> 17u;
	h ^= h << 25u;
	h += h >> 6u;
	return h;
}

uint GradUint(in uvec3 pos, in uint stride, in uint maximum) {
	uvec3 d = pos % stride;
	pos /= stride;
	uint p000 = GradUintHash(pos) % maximum;
	uint p001 = GradUintHash(pos + uvec3(0,0,1)) % maximum;
	uint p010 = GradUintHash(pos + uvec3(0,1,0)) % maximum;
	uint p011 = GradUintHash(pos + uvec3(0,1,1)) % maximum;
	uint p100 = GradUintHash(pos + uvec3(1,0,0)) % maximum;
	uint p101 = GradUintHash(pos + uvec3(1,0,1)) % maximum;
	uint p110 = GradUintHash(pos + uvec3(1,1,0)) % maximum;
	uint p111 = GradUintHash(pos + uvec3(1,1,1)) % maximum;
	uint p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	uint p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	uint p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	uint p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	uint p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	uint p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	uint p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}

float tricosineInterpolation(float a, float b, float x) {
	float ft = x * 3.1415927;
	float f = (1. - cos(ft)) * 0.5;
	return a*(1.-f) + b*f;
}

// float slerp(float x) {
// 	return x * x * x * (x * (x * 6. - 15.) + 10.);
// }

// float slerp(float x) {
// 	return smoothstep(0.,1., x);
// }

// float slerp(float x) {
// 	return mix(x * x * (3. - 2. * x), x, 0.5);
// }

float slerp(float x) {
	return mix(smoothstep(0.,1.,x), x, 0.5);
}

float GradUintNorm(in uvec3 pos, in uint stride, in uint maximum) {
	float stridef = float(stride);
	vec3 d = vec3(pos % stride) / stridef;
	pos /= stride;
	float maximumf = float(maximum);
	float p000 = float(GradUintHash(pos) % maximum);
	float p001 = float(GradUintHash(pos + uvec3(0,0,1)) % maximum);
	float p010 = float(GradUintHash(pos + uvec3(0,1,0)) % maximum);
	float p011 = float(GradUintHash(pos + uvec3(0,1,1)) % maximum);
	float p100 = float(GradUintHash(pos + uvec3(1,0,0)) % maximum);
	float p101 = float(GradUintHash(pos + uvec3(1,0,1)) % maximum);
	float p110 = float(GradUintHash(pos + uvec3(1,1,0)) % maximum);
	float p111 = float(GradUintHash(pos + uvec3(1,1,1)) % maximum);
	float p00 = (p000 * slerp(1.0 - d.x) + p100 * slerp(d.x));
	float p01 = (p001 * slerp(1.0 - d.x) + p101 * slerp(d.x));
	float p10 = (p010 * slerp(1.0 - d.x) + p110 * slerp(d.x));
	float p11 = (p011 * slerp(1.0 - d.x) + p111 * slerp(d.x));
	float p0 = (p00 * slerp(1.0 - d.y) + p10 * slerp(d.y));
	float p1 = (p01 * slerp(1.0 - d.y) + p11 * slerp(d.y));
	float p = (p0 * slerp(1.0 - d.z) + p1 * slerp(d.z));
	return slerp(p / maximumf);
}

uint RidgedGradUint(in uvec3 pos, in uint stride, in uint maximum) {
	return uint(abs(int(GradUint(pos, stride, maximum)) - int(maximum) / 2));
}

void main() {
	uint top = 1536u;
	uint warpX = 0u;//GradUint(uvec3(gl_FragCoord.xy, 0), 1u, 64u);
	uint warpY = 0u;//GradUint(uvec3(gl_FragCoord.xy, 0), 1u, 64u);
	uint warpZ = top;//GradUint(uvec3(gl_FragCoord.xy, 0), 16u, 41u);
	uint value =
		+ uint(GradUintNorm(uvec3(gl_FragCoord.xy*float(top)/64. + vec2(warpX, warpY), warpZ), top, top) * float(top))
		// + GradUint(uvec3(gl_FragCoord.xy*float(top)/64. + vec2(warpX, warpY), warpZ), top, top)
		
		// + RidgedGradUint(uvec3(gl_FragCoord.xy + vec2(warpX, warpY), warpZ), 64u, 128u)
		// + RidgedGradUint(uvec3(gl_FragCoord.xy + vec2(warpX, warpY)*1.5, warpZ), 32u, 64u)
		// + RidgedGradUint(uvec3(gl_FragCoord.xy + vec2(warpX, warpY)*6.5, warpZ), 16u, 32u)
		// + RidgedGradUint(uvec3(gl_FragCoord.xy, iGlobalTime*0.), 8u, 16u)
		// + RidgedGradUint(uvec3(gl_FragCoord.xy, iGlobalTime*0.), 4u, 8u)
		// + RidgedGradUint(uvec3(gl_FragCoord.xy, iGlobalTime*0.), 2u, 4u)
	;

	gl_FragColor = vec4(vec3(value) / float(
		+ top
		// +128
		// +64
		// +32
		// +16
		// +8
		// +4
	), 1);
}
