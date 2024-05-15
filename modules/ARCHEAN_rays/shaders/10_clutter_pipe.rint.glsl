#define SHADER_RINT
#include "common.inc.glsl"

struct PipeAttr {
	vec3 normal;
	vec3 axis;
};

hitAttributeEXT PipeAttr attr;

void BoxIntersection() {
	COMPUTE_BOX_INTERSECTION // retrieves T1 and T2
	if (RAY_STARTS_OUTSIDE_T1_T2 || RAY_STARTS_BETWEEN_T1_T2) {
		vec3 localPosition = gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * T1;
		const float THRESHOLD = EPSILON;
		const vec3 absMin = abs(localPosition - AABB_MIN.xyz);
		const vec3 absMax = abs(localPosition - AABB_MAX.xyz);
		float smallestValue = 1e100;
		if (absMin.x < smallestValue) {smallestValue = absMin.x; attr.normal = vec3(-1, 0, 0);}
		if (absMin.y < smallestValue) {smallestValue = absMin.y; attr.normal = vec3( 0,-1, 0);}
		if (absMin.z < smallestValue) {smallestValue = absMin.z; attr.normal = vec3( 0, 0,-1);}
		if (absMax.x < smallestValue) {smallestValue = absMax.x; attr.normal = vec3( 1, 0, 0);}
		if (absMax.y < smallestValue) {smallestValue = absMax.y; attr.normal = vec3( 0, 1, 0);}
		if (absMax.z < smallestValue) {smallestValue = absMax.z; attr.normal = vec3( 0, 0, 1);}
		attr.axis = vec3(1);
		if (T1 > gl_RayTminEXT) {
			reportIntersectionEXT(T1, 0);
		} else {
			reportIntersectionEXT(T2, 1);
		}
	}
}

void CylinderIntersection() {
	
	const vec3 aabb_min = AABB_MIN;
	const vec3 aabb_max = AABB_MAX;

	const vec3 ro = gl_ObjectRayOriginEXT;
	const vec3 rd = gl_ObjectRayDirectionEXT;
	
	// Compute pa, pb, r  from just the aabb info
	vec3 axis = vec3(0);
	float r;
	vec3 pa;
	vec3 pb;
	{
		const float x = aabb_max.x - aabb_min.x;
		const float y = aabb_max.y - aabb_min.y;
		const float z = aabb_max.z - aabb_min.z;
		if (abs(x-y) < EPSILON) { // Z is length
			r = (aabb_max.x - aabb_min.x) / 2.0;
			pa.xy = (aabb_min.xy + aabb_max.xy) / 2.0;
			pb.xy = pa.xy;
			pa.z = aabb_min.z;
			pb.z = aabb_max.z;
			axis.z = 1;
		} else if (abs(x-z) < EPSILON) { // Y is length
			r = (aabb_max.x - aabb_min.x) / 2.0;
			pa.xz = (aabb_min.xz + aabb_max.xz) / 2.0;
			pb.xz = pa.xz;
			pa.y = aabb_min.y;
			pb.y = aabb_max.y;
			axis.y = 1;
		} else { // X is length
			r = (aabb_max.y - aabb_min.y) / 2.0;
			pa.yz = (aabb_min.yz + aabb_max.yz) / 2.0;
			pb.yz = pa.yz;
			pa.x = aabb_min.x;
			pb.x = aabb_max.x;
			axis.x = 1;
		}
	}
	
	// Ray-Cylinder Intersection (ro, rd, pa, pb, r)
	const vec3 ba = pb - pa;
	const vec3 oc = ro - pa;
	const float baba = dot(ba, ba);
	const float bard = dot(ba, rd);
	const float baoc = dot(ba, oc);
	const float k2 = baba - bard*bard;
	const float k1 = baba * dot(oc, rd) - baoc*bard;
	const float k0 = baba * dot(oc, oc) - baoc*baoc - r*r*baba;
	float h = k1*k1 - k2*k0;
	
	if (h < 0.0) return;
	h = sqrt(h);
	
	const float t1 = (-k1-h) / k2;
	const float t2 = (-k1+h) / k2;
	const float y1 = baoc + bard * t1;
	const float y2 = baoc + bard * t2;
	
	// Cylinder body Outside surface
	if (y1 > 0.0 && y1 < baba) {
		if (gl_RayTminEXT <= t1) {
			// attr.radius = r;
			// attr.len = length(ba);
			attr.normal = normalize((oc + rd*t1 - ba*y1/baba) / r);
			attr.axis = axis;
			reportIntersectionEXT(t1, 0);
			return;
		}
	}
	
	// Flat caps Outside surface
	const float capsT1 = (((y1<0.0)? 0.0 : baba) - baoc) / bard;
	if (abs(k1+k2*capsT1) < h) {
		if (gl_RayTminEXT <= capsT1) {
			// attr.radius = r;
			attr.normal = normalize(ba*sign(y1)/baba);
			if (dot(attr.normal, rd) < 0) {
				// attr.len = length(ba);
				attr.axis = axis;
				reportIntersectionEXT(capsT1, 2);
				return;
			}
		}
	}
	
	// Cylinder body Inside surface
	if (y2 > 0.0 && y2 < baba) {
		if (gl_RayTminEXT <= t2) {
			// attr.radius = r;
			// attr.len = length(ba);
			attr.normal = normalize((oc + rd*t2 - ba*y2/baba) / r);
			reportIntersectionEXT(t2, 1);
			return;
		}
	}
	
	// Flat caps Inside surface
	const float capsT2 = (((y2<0.0)? 0.0 : baba) - baoc) / bard;
	if (abs(k1+k2*capsT2) < h) {
		if (gl_RayTminEXT <= capsT2) {
			// attr.radius = r;
			// attr.len = length(ba);
			attr.normal = normalize(ba*sign(y2)/baba);
			reportIntersectionEXT(capsT2, 3);
			return;
		}
	}
	
}

void CapsuleIntersection() {
	
	const vec3 aabb_min = AABB_MIN;
	const vec3 aabb_max = AABB_MAX;

	const vec3 ro = gl_ObjectRayOriginEXT;
	const vec3 rd = gl_ObjectRayDirectionEXT;
	
	// Compute pa, pb, r  from just the aabb info
	vec3 axis = vec3(0);
	float r;
	vec3 pa;
	vec3 pb;
	{
		const float x = aabb_max.x - aabb_min.x;
		const float y = aabb_max.y - aabb_min.y;
		const float z = aabb_max.z - aabb_min.z;
		if (abs(x-y) < EPSILON) { // Z is length
			r = (aabb_max.x - aabb_min.x) / 2.0;
			pa.xy = (aabb_min.xy + aabb_max.xy) / 2.0;
			pb.xy = pa.xy;
			pa.z = aabb_min.z + sign(aabb_max.z - aabb_min.z) * r;
			pb.z = aabb_max.z + sign(aabb_min.z - aabb_max.z) * r;
			axis.z = 1;
		} else if (abs(x-z) < EPSILON) { // Y is length
			r = (aabb_max.x - aabb_min.x) / 2.0;
			pa.xz = (aabb_min.xz + aabb_max.xz) / 2.0;
			pb.xz = pa.xz;
			pa.y = aabb_min.y + sign(aabb_max.y - aabb_min.y) * r;
			pb.y = aabb_max.y + sign(aabb_min.y - aabb_max.y) * r;
			axis.y = 1;
		} else { // X is length
			r = (aabb_max.y - aabb_min.y) / 2.0;
			pa.yz = (aabb_min.yz + aabb_max.yz) / 2.0;
			pb.yz = pa.yz;
			pa.x = aabb_min.x + sign(aabb_max.x - aabb_min.x) * r;
			pb.x = aabb_max.x + sign(aabb_min.x - aabb_max.x) * r;
			axis.x = 1;
		}
	}
	
	// Ray-Capsule Intersection (ro, rd, pa, pb, r)
	const vec3 ba = pb - pa;
	const vec3 oa = ro - pa;
	const float baba = dot(ba, ba);
	const float bard = dot(ba, rd);
	const float baoa = dot(ba, oa);
	const float rdoa = dot(rd, oa);
	const float oaoa = dot(oa, oa);
	float a = baba - bard*bard;
	float b = baba*rdoa - baoa*bard;
	float c = baba*oaoa - baoa*baoa - r*r*baba;
	float h = b*b - a*c;
	
	if (h >= 0.0) {
		const float t1 = (-b-sqrt(h)) / a;
		const float t2 = (-b+sqrt(h)) / a;
		const float y1 = baoa + t1*bard;
		const float y2 = baoa + t2*bard;
		
		// cylinder body Outside surface
		if (y1 > 0.0 && y1 < baba && gl_RayTminEXT <= t1) {
			// attr.radius = r;
			// attr.len = length(ba);
			const vec3 posa = (gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * t1) - pa;
			attr.normal = normalize((posa - clamp(dot(posa, ba) / dot(ba, ba), 0.0, 1.0) * ba) / r);
			attr.axis = axis;
			reportIntersectionEXT(t1, 0);
			return;
		}
		
		vec3 oc;
		
		// rounded caps Outside surface
		// BUG: There is currently an issue with this when the ray origin starts inside the cylinder between points A and B, we can see part of the sphere of cap A. This should not be a problem if we always render the outside surfaces or for collision detection.
		oc = (y1 <= 0.0)? oa : ro - pb;
		b = dot(rd, oc);
		c = dot(oc, oc) - r*r;
		h = b*b - c;
		if (h > 0.0) {
			const float t = -b - sqrt(h);
			if (gl_RayTminEXT <= t) {
				// attr.radius = r;
				const vec3 posa = (gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * t) - pa;
				attr.normal = normalize((posa - clamp(dot(posa, ba) / dot(ba, ba), 0.0, 1.0) * ba) / r);
				if (dot(attr.normal, rd) < 0) {
					// attr.len = length(ba);
					attr.axis = axis;
					reportIntersectionEXT(t, 2);
					return;
				}
			}
		}
		
		// cylinder body Inside surface
		if (y2 > 0.0 && y2 < baba && gl_RayTminEXT <= t2) {
			// attr.radius = r;
			// attr.len = length(ba);
			const vec3 posa = (gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * t2) - pa;
			attr.normal = normalize((posa - clamp(dot(posa, ba) / dot(ba, ba), 0.0, 1.0) * ba) / r);
			reportIntersectionEXT(t2, 1);
			return;
		}
		
		// rounded caps Inside surface
		oc = (y2 <= 0.0)? oa : ro - pb;
		b = dot(rd, oc);
		c = dot(oc, oc) - r*r;
		h = b*b - c;
		if (h > 0.0) {
			const float t = -b + sqrt(h);
			if (gl_RayTminEXT <= t) {
				// attr.radius = r;
				// attr.len = length(ba);
				const vec3 posa = (gl_ObjectRayOriginEXT + gl_ObjectRayDirectionEXT * t) - pa;
				attr.normal = normalize((posa - clamp(dot(posa, ba) / dot(ba, ba), 0.0, 1.0) * ba) / r);
				reportIntersectionEXT(t, 3);
				return;
			}
		}
		
	}
}

void main() {
	uint32_t flags = uint32_t(AABB.data >> 32);
	if ((flags & PIPE_FLAG_CAPSULE) != 0) {
		CapsuleIntersection();
	} else if ((flags & PIPE_FLAG_BOX) != 0) {
		BoxIntersection();
	} else {
		CylinderIntersection();
	}
	DEBUG_RAY_INT_TIME
}
