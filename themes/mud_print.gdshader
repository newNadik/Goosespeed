shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_toon, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.480, 0.360, 0.300);
uniform vec3 dark_patch_color : source_color = vec3(0.315, 0.255, 0.225);
uniform vec3 wet_patch_color : source_color = vec3(0.245, 0.325, 0.335);
uniform vec3 streak_color : source_color = vec3(0.180, 0.235, 0.245);
uniform vec3 dry_highlight_color : source_color = vec3(0.650, 0.500, 0.380);
uniform float patch_strength : hint_range(0.0, 1.0, 0.01) = 0.44;
uniform float wet_strength : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float streak_strength : hint_range(0.0, 1.0, 0.01) = 0.22;
uniform float paper_texture : hint_range(0.0, 0.08, 0.001) = 0.018;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec2 print_uv = UV * vec2(3.2, 5.4);
	float broad_patch = smoothstep(0.46, 0.78, value_noise(print_uv));
	float wet_patch = smoothstep(0.66, 0.91, value_noise(print_uv * 0.72 + vec2(6.4, 1.7)));

	float curved = sin((UV.x * 7.0 + sin(UV.y * 8.0) * 0.23) * 6.28318);
	float streak_gate = smoothstep(0.32, 0.72, value_noise(UV * vec2(2.0, 4.5) + vec2(3.1, 9.2)));
	float streak = smoothstep(0.935, 0.988, curved) * streak_gate;

	float dry_fleck = smoothstep(0.965, 0.995, hash21(floor(UV * vec2(34.0, 22.0))));
	float grain = hash21(floor(UV * vec2(92.0, 76.0)));

	vec3 color = base_color;
	color = mix(color, dark_patch_color, broad_patch * patch_strength);
	color = mix(color, wet_patch_color, wet_patch * wet_strength);
	color = mix(color, streak_color, streak * streak_strength);
	color = mix(color, dry_highlight_color, dry_fleck * 0.16);
	ALBEDO = color + (grain - 0.5) * paper_texture;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	vec3 normal_dir = normalize(NORMAL);
	vec3 light_dir = normalize(LIGHT);
	float light_amount = clamp(dot(normal_dir, light_dir), 0.0, 1.0);
	float toon_light = smoothstep(0.18, 0.50, light_amount);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * mix(0.70, 1.0, toon_light);
}
