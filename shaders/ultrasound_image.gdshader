shader_type canvas_item;

uniform sampler2D raw_data;
uniform sampler2D bg_image;
uniform float gain: hint_range(0.0, 3.0) = 1.0;
uniform float depth_m: hint_range(0.02, 0.30) = 0.15;
uniform int transducer_type: hint_range(0, 2) = 0;
uniform float time: hint_range(0.0, 1000.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 19.19);
	return fract(p.x * p.y);
}

float speckle(vec2 uv, float t) {
	vec2 pos = uv * vec2(400.0, 600.0);
	float n = 0.0;
	for (int i = 0; i < 3; i++) {
		vec2 q = pos + vec2(float(i) * 137.0, float(i) * 73.0);
		n += hash21(q + t * 0.02) * 0.3;
	}
	return n / 3.0;
}

// --- UV mapping functions (convert display UV to raycaster data coords) ---

vec2 uv_linear(vec2 uv) {
	return vec2(uv.x, uv.y);
}

vec2 uv_convex(vec2 uv) {
	float apex_x = 0.5, apex_y = 0.0, half_angle = 0.79;
	vec2 offset = uv - vec2(apex_x, apex_y);
	float angle = atan(offset.x, -offset.y);
	float radius = length(offset);
	float max_radius = length(vec2(0.5, apex_y - 1.0));
	float depth_norm = clamp(radius / max_radius, 0.0, 1.0);
	float ray = clamp(angle / (2.0 * half_angle) + 0.5, 0.0, 1.0);
	return vec2(ray, depth_norm);
}

vec2 uv_sector(vec2 uv) {
	float apex_x = 0.5, apex_y = 0.0, half_angle = 0.52;
	vec2 offset = uv - vec2(apex_x, apex_y);
	float angle = atan(offset.x, -offset.y);
	float radius = length(offset);
	float max_radius = length(vec2(0.5, apex_y - 1.0));
	float depth_norm = clamp(radius / max_radius, 0.0, 1.0);
	float ray = clamp(angle / (2.0 * half_angle) + 0.5, 0.0, 1.0);
	return vec2(ray, depth_norm);
}

// --- Beam shape clipping ---

bool clip_beam(vec2 uv, int type) {
	if (type == 0) {
		float apex_x = 0.5, apex_y = 0.0, half_angle = 0.79;
		vec2 offset = uv - vec2(apex_x, apex_y);
		float radius = length(offset);
		float max_radius = length(vec2(0.5, apex_y - 1.0));
		float width_here = (radius / max_radius) * tan(half_angle);
		if (abs(offset.x) > width_here + 0.008) return true;
	} else if (type == 1) {
		float half_w = 0.40;
		if (abs(uv.x - 0.5) > half_w) return true;
	} else if (type == 2) {
		float apex_x = 0.5, apex_y = 0.0, half_angle = 0.52;
		vec2 offset = uv - vec2(apex_x, apex_y);
		float radius = length(offset);
		float max_radius = length(vec2(0.5, apex_y - 1.0));
		float width_here = (radius / max_radius) * tan(half_angle);
		if (abs(offset.x) > width_here + 0.008) return true;
	}
	return false;
}

// --- Scan line effect ---

float scan_lines(vec2 uv, float t) {
	float speed = 2.5;
	float y = uv.y + t * speed;
	float line = abs(fract(y * 280.0) - 0.5) * 2.0;
	return 1.0 - smoothstep(0.0, 0.08, line) * 0.06;
}

// --- Depth/grid markers ---

vec3 depth_markers(vec2 uv, float d_m, float t, int type) {
	vec3 col = vec3(0.0);
	float depth_cm = d_m * 100.0;
	float num_markers = max(3.0, floor(depth_cm / 2.0));
	float marker_alpha = 0.08 + 0.04 * sin(t * 0.5);

	if (type == 1) {
		for (float i = 1.0; i <= 10.0; i++) {
			float y = i / (num_markers + 1.0);
			float dist = abs(uv.y - y);
			if (dist < 0.005) {
				col = max(col, vec3(0.15, 0.45, 0.55) * marker_alpha);
			}
		}
	} else {
		float apex_x = 0.5, apex_y = 0.0;
		float max_radius = length(vec2(0.5, apex_y - 1.0));
		vec2 offset = uv - vec2(apex_x, apex_y);
		float radius = length(offset);
		for (float i = 1.0; i <= 10.0; i++) {
			float frac = i / (num_markers + 1.0);
			float target_r = frac * max_radius;
			float dist = abs(radius - target_r);
			if (dist < 0.005) {
				col = max(col, vec3(0.15, 0.45, 0.55) * marker_alpha);
			}
		}
	}

	float left_x = 0.02;
	if (abs(uv.x - left_x) < 0.005 && uv.y > 0.02 && uv.y < 0.98) {
		col = max(col, vec3(0.1, 0.35, 0.45) * 0.5);
	}

	return col;
}

// --- Near-field noise / ring-down ---

float near_field(float uv_y) {
	return exp(-uv_y * 15.0) * 0.08;
}

// --- Reverb / multipath artifact ---

float reverb_artifact(vec2 uv, float t) {
	float r = sin(uv.y * 40.0 + t * 0.5) * 0.5 + 0.5;
	return r * exp(-uv.y * 8.0) * 0.02 * (0.5 + 0.5 * sin(uv.x * 20.0));
}

void fragment() {
	vec2 uv = UV;

	if (clip_beam(uv, transducer_type)) {
		discard;
	}

	vec2 raw_uv;
	if (transducer_type == 0) {
		raw_uv = uv_convex(uv);
	} else if (transducer_type == 1) {
		raw_uv = uv_linear(uv);
	} else {
		raw_uv = uv_sector(uv);
	}

	if (raw_uv.x < 0.0 || raw_uv.x > 1.0 || raw_uv.y < 0.0 || raw_uv.y > 1.0) {
		discard;
	}

	float echo = texture(raw_data, raw_uv).r;

	float tgc = 1.0 + raw_uv.y * (1.0 + gain * 1.5);
	echo *= tgc;

	echo = pow(echo, 1.0 / (1.0 + gain * 0.6));
	echo *= 1.0 + gain * 1.8;

	echo = clamp(echo, 0.0, 1.0);

	float sp = speckle(uv, time);
	echo = mix(echo, sp, 0.05 + gain * 0.04);

	echo += hash21(uv + floor(time * 0.5)) * (0.008 + gain * 0.006);

	echo += near_field(uv.y);
	echo += reverb_artifact(uv, time);

	float sl = scan_lines(uv, time);
	echo *= sl;

	vec4 bg = texture(bg_image, UV);
	float e = clamp(echo, 0.0, 1.0);
	vec3 blended = mix(bg.rgb, vec3(e), e * 0.55);
	blended = mix(blended, bg.rgb * (1.0 - e * 0.25), 0.25);

	blended += depth_markers(uv, depth_m, time, transducer_type);

	float v_scan = sin(uv.x * 3.14159 * 96.0 + time * 2.0) * 0.004;
	float h_scan = sin(uv.y * 3.14159 * 400.0 + time * 2.5) * 0.004;
	blended += (v_scan + h_scan) * 0.8;

	COLOR = vec4(blended, 1.0);
}
