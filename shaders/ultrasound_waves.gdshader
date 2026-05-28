shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

uniform int transducer_type : hint_range(0, 2) = 0;
uniform float wave_speed : hint_range(0.1, 5.0) = 1.5;
uniform float wave_count : hint_range(3.0, 30.0) = 14.0;
uniform float brightness : hint_range(0.0, 2.0) = 1.2;

vec3 core_color(float intensity) {
	vec3 col = vec3(0.78, 0.9, 1.0);
	return col * intensity;
}

vec3 glow_color(float intensity) {
	vec3 col = vec3(0.24, 0.55, 1.0);
	return col * intensity;
}

float draw_line(float dist, float width) {
	return smoothstep(width, 0.0, abs(dist));
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * wave_speed;
	vec3 color = vec3(0.0);
	float alpha = 0.0;
	int N = int(wave_count);

	if (transducer_type == 0) {
		vec2 center = vec2(0.5, 0.0);
		vec2 dir = uv - center;
		float dist = length(dir);
		float angle = atan(uv.y, uv.x - 0.5);
		float half_angle = 1.35;
		float angle_from_center = abs(angle - PI / 2.0);
		if (angle_from_center < half_angle && dist > 0.0) {
			float angle_fade = 1.0 - smoothstep(0.0, half_angle, angle_from_center);
			float arc_progress = dist * 1.4;
			for (int i = 0; i < N; i++) {
				float fi = float(i);
				float ph = fract(fi / float(N) - t * 0.55);
				float wave_dist = abs(arc_progress - ph);
				float fade = sin(ph * 3.1416);
				if (fade < 0.03) continue;
				for (int g = 4; g >= 0; g--) {
					float fg = float(g);
					float gw = 0.007 + fg * 0.025;
					float core_w = 0.007;
					float intensity = draw_line(wave_dist, fg > 0.5 ? gw : core_w) * fade * angle_fade;
					if (intensity < 0.005) continue;
					if (g == 0) {
						float ci = intensity;
						color += core_color(ci * 0.95) * brightness;
						alpha = max(alpha, ci * 0.85);
					} else {
						color += glow_color(intensity * 0.12) * brightness;
						alpha = max(alpha, intensity * 0.25);
					}
				}
			}
		}
	} else if (transducer_type == 1) {
		float bw = 0.72;
		float rel_x = abs(uv.x - 0.5);
		if (rel_x < bw * 0.5) {
			float x_fade = 1.0 - smoothstep(0.0, bw * 0.5, rel_x);
			for (int i = 0; i < N; i++) {
				float fi = float(i);
				float ph = fract(fi / float(N) - t * 0.5);
				float wave_dist = abs(uv.y - ph);
				float fade = sin(ph * 3.1416);
				if (fade < 0.03) continue;
				for (int g = 3; g >= 0; g--) {
					float fg = float(g);
					float gw = 0.006 + fg * 0.035;
					float core_w = 0.006;
					float intensity = draw_line(wave_dist, fg > 0.5 ? gw : core_w) * fade * x_fade;
					if (intensity < 0.005) continue;
					if (g == 0) {
						float grad = 1.0 - smoothstep(0.0, bw * 0.5, rel_x);
						float ci = intensity * (0.25 + 0.75 * grad);
						color += core_color(ci * 0.85) * brightness;
						alpha = max(alpha, ci * 0.85);
					} else {
						color += glow_color(intensity * 0.1) * brightness;
						alpha = max(alpha, intensity * 0.25);
					}
				}
			}
		}
	} else if (transducer_type == 2) {
		vec2 center = vec2(0.5, 0.0);
		vec2 dir = uv - center;
		float dist = length(dir);
		float angle = atan(uv.y, uv.x - 0.5);
		float half_angle = 0.72;
		float angle_from_center = abs(angle - PI / 2.0);
		if (angle_from_center < half_angle && dist > 0.0) {
			float angle_fade = 1.0 - smoothstep(0.0, half_angle, angle_from_center);
			float arc_progress = dist * 1.1;
			for (int i = 0; i < N; i++) {
				float fi = float(i);
				float ph = fract(fi / float(N) - t * 0.55);
				float wave_dist = abs(arc_progress - ph);
				float fade = sin(ph * 3.1416);
				if (fade < 0.03) continue;
				for (int g = 4; g >= 0; g--) {
					float fg = float(g);
					float gw = 0.007 + fg * 0.025;
					float core_w = 0.007;
					float intensity = draw_line(wave_dist, fg > 0.5 ? gw : core_w) * fade * angle_fade;
					if (intensity < 0.005) continue;
					if (g == 0) {
						float ci = intensity;
						color += core_color(ci * 0.95) * brightness;
						alpha = max(alpha, ci * 0.85);
					} else {
						color += glow_color(intensity * 0.13) * brightness;
						alpha = max(alpha, intensity * 0.25);
					}
				}
			}
		}
	}

	ALBEDO = color;
	ALPHA = alpha * 0.9;
}
