shader_type canvas_item;

#define MAX_LIGHTS 100
#define MAX_SEGMENTS 500
#define RAY_BOUNCE 10

uniform vec2 SIZE;
uniform int nLights;
uniform int nSegments;
uniform int segmentSamples;

uniform int lightSamples;

uniform vec2 lightPos[MAX_LIGHTS];
uniform vec3 lightCol[MAX_LIGHTS];
uniform float lightRad[MAX_LIGHTS];

uniform vec2 segment0[MAX_SEGMENTS];
uniform vec2 segment1[MAX_SEGMENTS];

uniform vec3 segmenCol[MAX_SEGMENTS];

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

Hit rayLineSegmentIntersect(Ray r, vec2 p0, vec2 p1)
    {
        vec2 v1 = r.origin - p0;
        vec2 v2 = p1 - p0;
        vec2 v3 = normalize(vec2(r.direction.y, -r.direction.x));


        float dp = dot(v2, v3);
		Hit ret;
        if (abs(dp) < 0.000001) {
			ret.hit = false;
			return ret;
		}

        float t1 = ((v1.x*v2.y) - (v1.y*v2.x)) / dp;
        float t2 = dot(v1, v3) / dp;

        if (t1 >= 0.0 && (t2 >= 0.0 && t2 <= 1.0)) {
        	ret.hit = true;
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
	
	for (int i = 0; i < nSegments; i++) {
		Hit hit = rayLineSegmentIntersect(r, segment0[i], segment1[i]);
		if (hit.hit && (hit.dist < ret.dist)) ret = hit;
	}
	
	return ret;
}


vec3 directImpl(vec2 c, int samples) {
	vec3 directLight = vec3(0.0);
	for (int i = 0; i < nLights; i++) {
		vec2 lC = lightPos[i];
		float lR = lightRad[i];
		
		vec2 toL = c - lC;
		float sqDst = dot(toL, toL);
		float shadowTerm = 0.0;
		for (int j = 0; j < samples; j++) {
			float theta = 2.0*PI * float(j) / float(samples);
			vec2 lCLocal = lC+lR*vec2(cos(theta), sin(theta));
			vec2 toLLocal = c - lCLocal;
			float sqDstLocal = dot(toLLocal, toLLocal);
			Ray light = Ray(c, -toLLocal);
			Hit shadow = sceneIntersect(light);
			if (!shadow.hit || shadow.dist*shadow.dist > sqDstLocal-0.01 || distance(shadow.pos, lC) < lR)
				shadowTerm += 1.0 / float(samples);
		}
		directLight += shadowTerm * lightCol[i] / max(0.01, sqDst-lR*lR);
	}
	return directLight;
}

vec3 direct(vec2 c) {
	return directImpl(c, lightSamples);
}

vec3 indirect(vec2 c) {
	vec3 cOut = vec3(0.0);
	for (int i = 0; i < nSegments; i++) {
		vec2 p0 = segment0[i];
		vec2 p1 = segment1[i];
		
		vec3 color = segmenCol[i];
		
		vec2 tp0 = c-p0;
		vec2 tp1 = c-p1;
		
		float tht0 = atan(tp0.y, tp0.x);
		float tht1 = atan(tp1.y, tp1.x);
		if (tht0-tht1 > PI) tht0 -= 2.0*PI;
		if (tht1-tht0 > PI) tht1 -= 2.0*PI;
		
		if (abs(tht0-tht1) < 0.01) continue;
		
		vec2 norm = normalize(p0-p1);
		norm = vec2(-norm.y, norm.x);
		norm *= sign(dot(norm, tp0));
		
		vec3 light = vec3(0.0);
		
		float o = 2.0 / float(segmentSamples);
		for (int j = 0; j < segmentSamples; j++) {
			float t = float(j)/float(segmentSamples-1);
			vec2 pos = mix(p0,p1,t)+0.01*norm;
			vec2 thisA = mix(p0, p1, clamp(t-o, 0.0, 1.0));
			vec2 thisB = mix(p0, p1, clamp(t+o, 0.0, 1.0));
			
			vec2 tA = c-thisA;
			vec2 tB = c-thisB;
			
			float lTht0 = atan(tA.y, tA.x);
			float lTht1 = atan(tB.y, tB.x);
			if (lTht0-lTht1 > PI) lTht0 -= 2.0*PI;
			if (lTht1-lTht0 > PI) lTht1 -= 2.0*PI;
			
			float lArea = abs(lTht0-lTht1)/PI;

			vec3 directL = directImpl(pos, 4) * lArea * 2.0;
			vec3 cThis = directL / float(segmentSamples);
			vec3 cFinal = cThis;
			
			light += cFinal;
			//light += 2.0*lArea / float(segmentSamples);
		}
		light *= color;
		
		cOut += light;
		if (sdSegment(c, p0, p1) < 0.1) cOut += 5.0*directImpl(c,4)*color;
	}
	return cOut;
}

void fragment() {
	vec2 c = (2.0*UV-1.0)*SIZE;
	
	vec3 directLight = direct(c);
	
	vec3 color = directLight;
	color += indirect(c);
	
	color *= 2.0;
	color = color / (color+1.0);
	
	COLOR = vec4(color, 1.0);
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
