vec3 rgb_to_hsv(vec3 rgb) {
	float r = rgb.r, g = rgb.g, b = rgb.b;
	float maxC = max(r, max(g, b));
	float minC = min(r, min(g, b));
	float delta = maxC - minC;

	float h = 0.0;
	if (delta > 0.0) {
		if (maxC == r) {
			h = mod((g - b) / delta, 6.0);
		} else if (maxC == g) {
			h = (b - r) / delta + 2.0;
		} else {
			h = (r - g) / delta + 4.0;
		}
		h *= 60.0;
		if (h < 0.0) h += 360.0;
	}

	float s = (maxC == 0.0) ? 0.0 : (delta / maxC);
	float v = maxC;

	return vec3(h, s, v);
}

vec3 hsv_to_rgb(vec3 hsv) {
	float h = hsv.x, s = hsv.y, v = hsv.z;
	float c = v * s;
	float x = c * (1.0 - abs(mod(h / 60.0, 2.0) - 1.0));
	float m = v - c;

	vec3 rgb;
	if (h < 60.0) {
		rgb = vec3(c, x, 0.0);
	} else if (h < 120.0) {
		rgb = vec3(x, c, 0.0);
	} else if (h < 180.0) {
		rgb = vec3(0.0, c, x);
	} else if (h < 240.0) {
		rgb = vec3(0.0, x, c);
	} else if (h < 300.0) {
		rgb = vec3(x, 0.0, c);
	} else {
		rgb = vec3(c, 0.0, x);
	}

	return rgb + vec3(m);
}

vec3 hex_to_rgb(int hex) {
	vec3 rgb = vec3(1.0);
  int r = (hex >> 16) & 0xFF;
  int g = (hex >> 8) & 0xFF;
  int b = hex & 0xFF;
  rgb.r = float(r) / 255.0;
  rgb.g = float(g) / 255.0; 
  rgb.b = float(b) / 255.0;
	return rgb;
}

bool almost_equals(vec3 a, vec3 b, float epsilon) {
	return all(lessThan(abs(a - b), vec3(epsilon)));
}

float square(float x) {
	return x * x;
}

vec2 local_uv_to_atlas_uv(vec2 local_uv, vec4 atlas_uv) {
	vec2 altas_uv_size = atlas_uv.zw-atlas_uv.xy;

	vec2 wrapped_local_uv = fract(local_uv);
	//vec2 wrapped_local_uv = vec2(mod(local_uv.x, 1), mod(local_uv.y, 1));

	// punch in a bit from the edges so we don't go over
	const float epsilon = 0.0001;
	wrapped_local_uv = vec2(
		wrapped_local_uv.x < epsilon ? epsilon : wrapped_local_uv.x,
		wrapped_local_uv.y < epsilon ? epsilon : wrapped_local_uv.y
	);
	wrapped_local_uv = vec2(
		wrapped_local_uv.x > 1.0-epsilon ? 1.0-epsilon : wrapped_local_uv.x,
		wrapped_local_uv.y > 1.0-epsilon ? 1.0-epsilon : wrapped_local_uv.y
	);

	return atlas_uv.xy + altas_uv_size * wrapped_local_uv;
}