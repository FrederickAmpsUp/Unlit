shader_type canvas_item;

#define MAX_LIGHTS 100
#define MAX_SEGMENTS 500
#define segmentSamples 8
#define lightSamples 8

uniform int nLights;
uniform int nSegments;

uniform vec2 lightPos[MAX_LIGHTS];
uniform vec3 lightCol[MAX_LIGHTS];
uniform float lightRad[MAX_LIGHTS];

uniform vec2 segment0[MAX_SEGMENTS];
uniform vec2 segment1[MAX_SEGMENTS];

uniform vec3 segmentCol[MAX_SEGMENTS];

struct Ray {
	vec2 origin;
	vec2 direction;
};

struct Hit {
	bool hit;
	
	vec2 pos;
	float dist;
	vec2 norm;
	vec3 albedo;
};

// https://iquilezles.org/articles/distfunctions2d/
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

float rayDstSegment(Ray r, vec2 a, vec2 b) {
	float dd = dot(r.direction, r.direction);
	vec2 d = r.direction / sqrt(dd);
	vec2 oa = r.origin-a;
	float t = dot(oa, d) / dd;
	return sdSegment(r.origin + d*t, a, b);
}

// ACES Tonemapping
vec3 ACESFilm(vec3 x) {

    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return clamp((x*(a*x + b)) / (x*(c*x + d) + e), 0.0f, 1.0f);
}

Hit rayCircleIntersect(Ray ray, vec2 circleCenter, float circleRadius) {
    Hit hitResult;
    vec2 toCircle = ray.origin - circleCenter;
    float projectionLength = dot(-toCircle, normalize(ray.direction));

    if (projectionLength < 0.0) {
        hitResult.hit = false;
        return hitResult;
    }

    vec2 closestPoint = ray.origin + projectionLength * normalize(ray.direction);
    float distance = length(closestPoint - circleCenter);
    
    if (distance <= circleRadius) {
        hitResult.hit = true;
        hitResult.pos = closestPoint;
        hitResult.dist = length(closestPoint - ray.origin);
        hitResult.norm = (closestPoint - circleCenter) / distance;
        hitResult.albedo = vec3(0.0);
    } else {
        hitResult.hit = false;
    }

    return hitResult;
}

Hit rayLineSegmentIntersect(Ray r, vec2 p0, vec2 p1) {
    vec2 v1 = r.origin - p0;
    vec2 v2 = p1 - p0;
    vec2 v3 = normalize(vec2(r.direction.y, -r.direction.x));

    float dp = dot(v2, v3);
	Hit ret;
    if (abs(dp) < 0.0001) {
		ret.hit = false;
		return ret;
	}

    float t1 = ((v1.x*v2.y) - (v1.y*v2.x)) / dp;
    float t2 = dot(v1, v3) / dp;

    if (t1 >= 0.0) {
       	ret.hit = (t2 >= 0.0 && t2 <= 1.0);
		ret.pos = r.origin + normalize(r.direction)*t1;
		ret.dist = t1;
		ret.norm = normalize(vec2(-v2.y, v2.x));
		ret.norm *= -sign(dot(ret.norm, r.direction));
		ret.albedo = vec3(1.0, 0.0, 0.0);
		
		return ret;
	}

    ret.hit = false;
	return ret;
}

vec2 segmentSegmentIntersect(vec2 a0, vec2 b0, vec2 a1, vec2 b1)
{
    vec2 v1 = a0 - a1;
    vec2 v2 = b1 - a1;
	
	vec2 d = b0-a0;
    vec2 v3 = normalize(vec2(d.y, -d.x));

    float dp = dot(v2, v3);
    if (abs(dp) < 0.0001) {
		return vec2(-1);
	}

    float t1 = ((v1.x*v2.y) - (v1.y*v2.x)) / dp / distance(a0,b0);
    float t2 = dot(v1, v3) / dp;

    if (t2 >= 0.0 && t2 <= 1.0) {
		return vec2(t1,t2);
	}

	return vec2(-1);
}

Hit segmentsIntersect(Ray r) {
	Hit ret;
	ret.hit = false;
	ret.dist = 10000.0;
	
	for (int i = 0; i < nSegments; i++) {
		Hit hit = rayLineSegmentIntersect(r, segment0[i], segment1[i]);
		if (hit.hit && (hit.dist < ret.dist)) ret = hit;
	}
	
	return ret;
}

Hit sceneIntersect(Ray r) {
	Hit ret;
	ret.hit = false;
	ret.dist = 10000.0;
	
	for (int i = 0; i < nLights; i++) {
		vec2 lC = lightPos[i];
		float lR = lightRad[i];
		Hit hit = rayCircleIntersect(r, lC, lR);
		if (hit.hit && (hit.dist < ret.dist)) ret = hit;
	}
	
	Hit seg = segmentsIntersect(r);
	if (seg.hit && seg.dist < ret.dist) ret = seg;
	
	return ret;
}

float segmentArea(vec2 a, vec2 b, vec2 p) {
	vec2 pa = p-a;
	vec2 pb = p-b;
	
	return acos(0.999*dot(normalize(pa),normalize(pb))) / PI;
}

vec3 shadow(vec2 p, vec2 c, float r) {
	vec2 pc = p-c;
	float sqPC = dot(pc,pc);
	vec2 perp = normalize(vec2(pc.y,-pc.x));
	vec2 a0 = c + perp*r;
	vec2 b0 = c - perp*r;
	
	vec2 toA0 = p-a0;
	vec2 toB0 = p-b0;
	float lTht0 = atan(toA0.y, toA0.x);
	float lTht1 = atan(toB0.y, toB0.x);
	if (lTht0-lTht1 > PI) lTht0 -= 2.0*PI;
	if (lTht1-lTht0 > PI) lTht1 -= 2.0*PI;
	
	float lArea = min(1.0, abs(lTht0-lTht1) / PI);
	
	float shadow = 1.0;
	
	for (int i = 0; i < nSegments; i++) {
		vec2 a = segment0[i];
		vec2 b = segment1[i];
		
		vec2 pA = p-a;
		vec2 pB = p-b;
		
		vec2 cA = c-a;
		vec2 cB = c-b;
		
		float t0 = segmentSegmentIntersect(a, b, p, a0).x;
		float t1 = segmentSegmentIntersect(a, b, p, b0).x;
		
		float area = min(1.0, segmentArea(a,b, c));
		
		if ((t0 > 0.0 && t0 < 1.0) && (t1 < 0.0 || t1 > 1.0)) {
			vec2 perpPA0 = vec2(toA0.y, -toA0.x);
			
			float dp0 = dot(perpPA0, pA);
			float dp1 = dot(perpPA0, toB0);
			float side = dp0*dp1; // negative: A is on opposite side of B0
								  // positive: A is on same side of B0 (both of PA0)
			if (side < 0.0) {
				a = mix(a,b, t0);
				area = segmentArea(a, b, p);
			} else {
				a = mix(a,b, t0);
				area = segmentArea(a, b, p);
			}
		}
		
		if ((t1 > 0.0 && t1 < 1.0) && (t0 < 0.0 || t0 > 1.0)) {
			vec2 perpPB0 = vec2(toB0.y, -toB0.x);
			
			float dp0 = dot(perpPB0, pB);
			float dp1 = dot(perpPB0, toA0);
			float side = dp0*dp1; // negative: B is on opposite side of A0
								  // positive: B is on same side of A0 (both of PB0)
			if (side < 0.0) {
				a = mix(a,b, t1);
				area = segmentArea(a, b, p);
			}
		}
		
		if ((t0 > 0.0 && t0 < 1.0) && (t1 > 0.0 && t1 < 1.0)) { // both hit
			area = 1.0;
		}
		if ((t0 < 0.0 || t0 > 1.0) && (t1 < 0.0 || t1 > 1.0)) { // neither hit
			area = 0.0;
		}
		shadow = min(1.0, area);
	}
	
	return vec3(1.0-shadow);
}

vec3 directImpl(vec2 c, int samples) {
	vec3 directLight = vec3(0.0);
	for (int i = 0; i < nLights; i++) {
		vec2 lC = lightPos[i];
		float lR = lightRad[i];
		
		vec2 toL = c - lC;
		float sqDst = dot(toL, toL);
		if (sqDst < lR*lR) {
			directLight += lightCol[i];
			continue;
		}
		vec3 shadowTerm = shadow(c, lC, lR);
		directLight += shadowTerm * lightCol[i] / max(0.01, pow(sqDst-lR*lR, 0.7));
	}
	return directLight;
}

vec3 direct(vec2 c) {
	return directImpl(c, lightSamples);
}

vec3 indirect(vec2 c) {
	for (int i = 0; i < nLights; i++) {
		if (dot(c-lightPos[i], c-lightPos[i]) < lightRad[i]*lightRad[i]) return vec3(0.0);
	}
	vec3 cOut = vec3(0.0);
	for (int i = 0; i < nSegments; i++) {
		vec2 p0 = segment0[i];
		vec2 p1 = segment1[i];
		
		vec3 color = segmentCol[i];
		
		vec2 norm = normalize(p0-p1);
		norm = vec2(-norm.y, norm.x);
		norm *= sign(dot(norm, c-p0));
		
		vec3 light = vec3(0.0);
		
		float o = 2.0 / float(segmentSamples);
		for (int j = 0; j < segmentSamples; j++) {
			float t = float(j)/float(segmentSamples-1);
			vec2 pos = mix(p0,p1,t)+0.01*norm;
			vec2 thisA = mix(p0, p1, clamp(t-o, 0.0, 1.0));
			vec2 thisB = mix(p0, p1, clamp(t+o, 0.0, 1.0));
			
			float occlusion = 1.0;
			
			vec2 toGI = c-pos;
			Ray occR = Ray(pos, toGI);
			Hit occ = segmentsIntersect(occR);
			if (!(occ.hit && occ.dist*occ.dist > dot(toGI,toGI))) {
				occlusion = 0.0;
			}

			vec3 directL = directImpl(pos, 4) * occlusion;
			vec3 cThis = directL / float(segmentSamples);
			vec3 cFinal = cThis;
			
			light += cFinal;
		}
		light *= color * segmentArea(p0,p1,c);
		
		cOut += light;
		if (sdSegment(c, p0, p1) < 0.1) cOut += 5.0*directImpl(c,4)*color;
	}
	return cOut;
}
varying vec2 c;
render_mode skip_vertex_transform;
void vertex() {
    VERTEX = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	c = VERTEX.xy;
}

void fragment() {
	vec3 directLight = direct(c);
	
	vec3 color = directLight;
	//color += indirect(c);
/*
		// tone mapping
	color += 0.01;
	if (length(color) > 1.0) {
		color *= length(color);
	}
	color *= 2.0;
	color = color / (color+1.0);*/
	
	COLOR = vec4(color, 1.0);
}


//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
