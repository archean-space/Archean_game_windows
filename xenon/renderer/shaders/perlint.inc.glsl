#ifdef __cplusplus
	#pragma once
#endif
// Integer Gradient Noise (by Olivier St-Laurent)

uint32_t perlint32Hash(u32vec3 p) {
	uint32_t h = 8u, _;
	h += p.x & 0xffffu;
	_ = (((p.x >> 16) & 0xffffu) << 11) ^ h;
	h = (h << 16) ^ _;
	h += h >> 11;
	h += p.y & 0xffffu;
	_ = (((p.y >> 16) & 0xffffu) << 11) ^ h;
	h = (h << 16) ^ _;
	h += h >> 11;
	h += p.z & 0xffffu;
	_ = (((p.z >> 16) & 0xffffu) << 11) ^ h;
	h = (h << 16) ^ _;
	h += h >> 11;
	h ^= h << 3;
	h += h >> 5;
	h ^= h << 4;
	h += h >> 17;
	h ^= h << 25;
	h += h >> 6;
	return h;
}

uint32_t perlint32(u32vec3 pos, uint32_t stride, uint32_t maximum) {
	u32vec3 d = pos % stride;
	pos /= stride;
	uint32_t p000 = perlint32Hash(pos) % maximum;
	uint32_t p001 = perlint32Hash(pos + u32vec3(0,0,1)) % maximum;
	uint32_t p010 = perlint32Hash(pos + u32vec3(0,1,0)) % maximum;
	uint32_t p011 = perlint32Hash(pos + u32vec3(0,1,1)) % maximum;
	uint32_t p100 = perlint32Hash(pos + u32vec3(1,0,0)) % maximum;
	uint32_t p101 = perlint32Hash(pos + u32vec3(1,0,1)) % maximum;
	uint32_t p110 = perlint32Hash(pos + u32vec3(1,1,0)) % maximum;
	uint32_t p111 = perlint32Hash(pos + u32vec3(1,1,1)) % maximum;
	uint32_t p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	uint32_t p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	uint32_t p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	uint32_t p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	uint32_t p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	uint32_t p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	uint32_t p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}
uint64_t perlint64(u64vec3 pos, uint64_t stride, uint64_t maximum) {
	u64vec3 d = pos % stride;
	u32vec3 pos32 = u32vec3(pos / stride);
	uint64_t p000 = uint64_t(perlint32Hash(pos32)) % maximum;
	uint64_t p001 = uint64_t(perlint32Hash(pos32 + u32vec3(0,0,1))) % maximum;
	uint64_t p010 = uint64_t(perlint32Hash(pos32 + u32vec3(0,1,0))) % maximum;
	uint64_t p011 = uint64_t(perlint32Hash(pos32 + u32vec3(0,1,1))) % maximum;
	uint64_t p100 = uint64_t(perlint32Hash(pos32 + u32vec3(1,0,0))) % maximum;
	uint64_t p101 = uint64_t(perlint32Hash(pos32 + u32vec3(1,0,1))) % maximum;
	uint64_t p110 = uint64_t(perlint32Hash(pos32 + u32vec3(1,1,0))) % maximum;
	uint64_t p111 = uint64_t(perlint32Hash(pos32 + u32vec3(1,1,1))) % maximum;
	uint64_t p00 = (p000 * (stride - d.x) + p100 * d.x) / stride;
	uint64_t p01 = (p001 * (stride - d.x) + p101 * d.x) / stride;
	uint64_t p10 = (p010 * (stride - d.x) + p110 * d.x) / stride;
	uint64_t p11 = (p011 * (stride - d.x) + p111 * d.x) / stride;
	uint64_t p0 = (p00 * (stride - d.y) + p10 * d.y) / stride;
	uint64_t p1 = (p01 * (stride - d.y) + p11 * d.y) / stride;
	uint64_t p = (p0 * (stride - d.z) + p1 * d.z) / stride;
	return min(p, maximum);
}

// float slerp(float x) {return mix(smoothstep(0.0f,1.0f,x), x, 0.5f);}
// double slerp(double x) {return mix(smoothstep(0.0,1.0,x), x, 0.5);}
float slerp(float x) {return smoothstep(0.0f,1.0f,x);}
double slerp(double x) {return smoothstep(0.0,1.0,x);}
uint32_t mixint(uint32_t x, uint32_t y, uint32_t t, uint32_t maximum) {return x * (maximum - t) + y * maximum;}
uint64_t mixint(uint64_t x, uint64_t y, uint64_t t, uint64_t maximum) {return x * (maximum - t) + y * maximum;}

float perlint32f(u32vec3 pos, uint32_t stride, uint32_t maximum) {
	float stridef = float(stride);
	f32vec3 d = f32vec3(pos % stride) / stridef;
	pos /= stride;
	float maximumf = float(maximum);
	float p000 = float(perlint32Hash(pos) % maximum);
	float p001 = float(perlint32Hash(pos + u32vec3(0,0,1)) % maximum);
	float p010 = float(perlint32Hash(pos + u32vec3(0,1,0)) % maximum);
	float p011 = float(perlint32Hash(pos + u32vec3(0,1,1)) % maximum);
	float p100 = float(perlint32Hash(pos + u32vec3(1,0,0)) % maximum);
	float p101 = float(perlint32Hash(pos + u32vec3(1,0,1)) % maximum);
	float p110 = float(perlint32Hash(pos + u32vec3(1,1,0)) % maximum);
	float p111 = float(perlint32Hash(pos + u32vec3(1,1,1)) % maximum);
	float p00 = (p000 * slerp(1.0f - d.x) + p100 * slerp(d.x));
	float p01 = (p001 * slerp(1.0f - d.x) + p101 * slerp(d.x));
	float p10 = (p010 * slerp(1.0f - d.x) + p110 * slerp(d.x));
	float p11 = (p011 * slerp(1.0f - d.x) + p111 * slerp(d.x));
	float p0 = (p00 * slerp(1.0f - d.y) + p10 * slerp(d.y));
	float p1 = (p01 * slerp(1.0f - d.y) + p11 * slerp(d.y));
	float p = (p0 * slerp(1.0f - d.z) + p1 * slerp(d.z));
	return slerp(p / maximumf);
}
double perlint64f(u64vec3 pos, uint64_t stride, uint64_t maximum) {
	double stridef = double(stride);
	f64vec3 d = smoothstep(0.0, 1.0, f64vec3(pos % stride) / stridef);
	u32vec3 pos32 = u32vec3(pos / stride);
	double maximumf = double(maximum);
	double p000 = double(uint64_t(perlint32Hash(pos32)) % maximum);
	double p001 = double(uint64_t(perlint32Hash(pos32 + u32vec3(0,0,1))) % maximum);
	double p010 = double(uint64_t(perlint32Hash(pos32 + u32vec3(0,1,0))) % maximum);
	double p011 = double(uint64_t(perlint32Hash(pos32 + u32vec3(0,1,1))) % maximum);
	double p100 = double(uint64_t(perlint32Hash(pos32 + u32vec3(1,0,0))) % maximum);
	double p101 = double(uint64_t(perlint32Hash(pos32 + u32vec3(1,0,1))) % maximum);
	double p110 = double(uint64_t(perlint32Hash(pos32 + u32vec3(1,1,0))) % maximum);
	double p111 = double(uint64_t(perlint32Hash(pos32 + u32vec3(1,1,1))) % maximum);
	double p00 = (p000 * (1-d.x) + p100 * d.x);
	double p01 = (p001 * (1-d.x) + p101 * d.x);
	double p10 = (p010 * (1-d.x) + p110 * d.x);
	double p11 = (p011 * (1-d.x) + p111 * d.x);
	double p0 = (p00 * (1-d.y) + p10 * d.y);
	double p1 = (p01 * (1-d.y) + p11 * d.y);
	double p = (p0 * (1-d.z) + p1 * d.z);
	return smoothstep(0.0, 1.0, p / maximumf);
}

uint32_t perlint32Ridged(u32vec3 pos, uint32_t stride, uint32_t maximum) {
	return uint32_t(abs(int32_t(perlint32(pos, stride, maximum)) - int32_t(maximum) / 2)) * 2;
}
uint64_t perlint64Ridged(u64vec3 pos, uint64_t stride, uint64_t maximum) {
	return uint64_t(abs(int64_t(perlint64(pos, stride, maximum)) - int64_t(maximum) / 2)) * 2;
}
float perlint32fRidged(u32vec3 pos, uint32_t stride, uint32_t maximum) {
	return abs(perlint32f(pos, stride, maximum) - 0.5f) * 2.0f;
}
double perlint64fRidged(u64vec3 pos, uint64_t stride, uint64_t maximum) {
	return abs(perlint64f(pos, stride, maximum) - 0.5) * 2.0;
}

uint32_t perlint32(u32vec3 pos, uint32_t stride, uint32_t maximum, uint32_t octaves) {
	uint32_t value = 0;
	for (uint32_t i = 1; i <= octaves; ++i) {
		value = mixint(value, perlint32(pos, stride/i, maximum/i), i, octaves);
	}
	return value;
}
uint64_t perlint64(u64vec3 pos, uint64_t stride, uint64_t maximum, uint64_t octaves) {
	uint64_t value = 0;
	for (uint64_t i = 1; i <= octaves; ++i) {
		value = mixint(value, perlint64(pos, stride/i, maximum/i), i, octaves);
	}
	return value;
}
float perlint32f(u32vec3 pos, uint32_t stride, uint32_t maximum, uint32_t octaves) {
	float value = 0;
	for (uint32_t i = 1; i <= octaves; ++i) {
		value = mix(value, perlint32f(pos, stride/i, maximum/i), 1.0f/float(i));
	}
	return clamp(value, 0.0f, 1.0f);
}
double perlint64f(u64vec3 pos, uint64_t stride, uint64_t maximum, uint64_t octaves) {
	double value = 0;
	for (uint64_t i = 1; i <= octaves; ++i) {
		value = mix(value, perlint64f(pos, stride/i, maximum/i), 1.0/double(i));
	}
	return clamp(value, 0.0, 1.0);
}

uint32_t perlint32Ridged(u32vec3 pos, uint32_t stride, uint32_t maximum, uint32_t octaves) {
	uint32_t value = 0;
	for (uint32_t i = 1; i <= octaves; ++i) {
		value += perlint32Ridged(pos, stride/i, maximum/i);
	}
	return value;
}
uint64_t perlint64Ridged(u64vec3 pos, uint64_t stride, uint64_t maximum, uint64_t octaves) {
	uint64_t value = 0;
	for (uint64_t i = 1; i <= octaves; ++i) {
		value += perlint64Ridged(pos, stride/i, maximum/i);
	}
	return value;
}
float perlint32fRidged(u32vec3 pos, uint32_t stride, uint32_t maximum, uint32_t octaves) {
	float value = 0;
	for (uint32_t i = 1; i <= octaves; ++i) {
		value = mix(value, perlint32fRidged(pos, stride/i, maximum/i), 1.0f/float(i));
	}
	return clamp(value, 0.0f, 1.0f);
}
double perlint64fRidged(u64vec3 pos, uint64_t stride, uint64_t maximum, uint64_t octaves) {
	double value = 0;
	for (uint64_t i = 1; i <= octaves; ++i) {
		value = mix(value, perlint64fRidged(pos, stride/i, maximum/i), 1.0/double(i));
	}
	return clamp(value, 0.0, 1.0);
}
