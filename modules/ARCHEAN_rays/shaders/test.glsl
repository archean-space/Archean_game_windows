
// https://iquilezles.org/articles/distfunctions/

float sdRoundBox( vec3 p, vec3 b, float r ) {
	vec3 q = abs(p) - b + r;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0) - r;
}

float sdBox( vec3 p, vec3 b ) {
	vec3 q = abs(p) - b;
	return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
}

float sdPlane( vec3 p, vec3 n, float h ) {
	// n must be normalized
	return dot(p,n) + h;
}

float sdCone( vec3 p, vec2 c , float h ) {
	vec2 q = h*vec2(c.x/c.y,-1.0);
	vec2 w = vec2( length(p.xz), p.y );
	vec2 a = w - q*clamp( dot(w,q)/dot(q,q), 0.0, 1.0 );
	vec2 b = w - q*vec2( clamp( w.x/q.x, 0.0, 1.0 ), 1.0 );
	float k = sign( q.y );
	float d = min(dot( a, a ),dot(b, b));
	float s = max( k*(w.x*q.y-w.y*q.x),k*(w.y-q.y)  );
	return sqrt(d)*sign(s);
}

vec4 opElongate( in vec3 p, in vec3 h ) {
	vec3 q = abs(p)-h;
	return vec4( max(q,0.0), min(max(q.x,max(q.y,q.z)),0.0) );
}

float sdCappedCylinder( vec3 p, vec2 h ) {
	vec2 d = abs(vec2(length(p.xz),p.y)) - h;
	return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float intersectSDF(float distA, float distB) {
	return max(distA, distB);
}
 
float unionSDF(float distA, float distB) {
	return min(distA, distB);
}
 
float differenceSDF(float distA, float distB) {
	return max(distA, -distB);
}

mat3 RotationMatrix(vec3 axis, float angle) {
	axis = normalize(axis);
	float s = sin(angle);
	float c = cos(angle);
	float oc = 1.0 - c;
	return mat3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
				oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
				oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c);
}

mat2 RotationMatrix(float angle) {
	float s = sin(angle);
	float c = cos(angle);
	return mat2(c, -s, s, c);
}

struct PropellerData {
	float depth;
	float radius;
	float speed;
	uint flags;
	uint blades;
};

PropellerData prop = PropellerData(0.3, 0.4, 1., 0u, 3u);

float propTipsRounded = 1.0;
float propTwist = 0.5;
float propPitch = 0.2;

float sdProp(vec3 p) {
	// N blades
	float th = atan(p.z, p.x);
	float angle = float(prop.blades + 2u) * th * 0.5;
	p.xz = RotationMatrix(angle) * p.xz;
	
	// Blade Pitch
	p.yz = RotationMatrix(propPitch * 3.141592654 / 2. * sign(p.x)) * p.yz;
	
	// Blade Twist
	p.y += p.x / prop.radius * p.z * propTwist * 2. / float(prop.blades);
	
	// Blade Shape
	float width = prop.depth / 4. * (pow(smoothstep(0.0, 0.5, abs(p.x) / prop.radius), 0.5) + pow(smoothstep(1.25, 0.5, abs(p.x) / prop.radius), 0.5));
	float thickness = prop.depth / 20. * (0.1 + (1.0 - pow(clamp(abs(p.z) / width, 0., 1.), 2.)) * smoothstep(1.0, 0.5, abs(p.x) / prop.radius));
	
	// Flat tips
	float flatD = sdBox(p, vec3(prop.radius, thickness, width));

	// Rounded tips
	vec4 w = opElongate(p, vec3(prop.radius-width,0.,0.));
	float roundedD = sdCappedCylinder(w.xyz, vec2(width,thickness));
	
	return mix(flatD, roundedD, propTipsRounded*propTipsRounded);
}

float sdNoseProp(vec3 p) {
	float coneRounding = 0.01;
	return sdCone(p - vec3(0,prop.depth/2. - coneRounding,0.), vec2(0.2, 0.4), 0.25 - coneRounding*2.) - coneRounding;
}

float Sdf(vec3 p) {
	p = RotationMatrix(vec3(0,1,0), prop.speed * iTime) * p;
	return min(sdProp(p), sdCappedCylinder(p, vec2(prop.depth/4., prop.depth/4.)));
}


#define AA 2
#define SCALE 6.

vec3 calcNormal( in vec3 pos ) {
	const float ep = 0.0001;
	vec2 e = vec2(1.0,-1.0)*0.5773;
	return normalize( e.xyy*Sdf( pos + e.xyy*ep ) + 
						e.yyx*Sdf( pos + e.yyx*ep ) + 
						e.yxy*Sdf( pos + e.yxy*ep ) + 
						e.xxx*Sdf( pos + e.xxx*ep ) );
}
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
	
	vec3 tot = vec3(0.0);

	#if AA>1
	for( int m=0; m<AA; m++ )
	for( int n=0; n<AA; n++ )
	{
		// pixel coordinates
		vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
		vec2 p = (-iResolution.xy + 2.0*(fragCoord+o))/iResolution.y/SCALE;
		#else
		vec2 p = (-iResolution.xy + 2.0*fragCoord)/iResolution.y/SCALE;
		#endif

		vec3 ro = vec3(0.0,3.0,6.0);
		vec3 rd = normalize(vec3(p-vec2(0.0,1.0),-2.0));

		float t = 5.0;
		for( int i=0; i<256; i++ )
		{
			vec3 p = ro + t*rd;
			float h = Sdf(p);
			if( abs(h)<0.001 || t>10.0 ) break;
			t += h*0.25;
		}

		vec3 col = vec3(0.0);

		if( t<10.0 )
		{
			vec3 pos = ro + t*rd;
			vec3 nor = calcNormal(pos);
			float dif = clamp(dot(nor,vec3(0.57703)),0.0,1.0);
			col = vec3(0.025,0.05,0.08) + dif*vec3(1.0,0.9,0.8);
		}

		col = sqrt( col );
		tot += col;
	#if AA>1
	}
	tot /= float(AA*AA);
	#endif

	
	fragColor = vec4( tot, 1.0 );
}
