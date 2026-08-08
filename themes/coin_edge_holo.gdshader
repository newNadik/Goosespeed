shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_toon, specular_disabled;

uniform vec3 base_edge : source_color = vec3(0.180, 0.300, 0.340);
uniform vec3 warm_edge : source_color = vec3(0.800, 0.420, 0.180);
uniform vec3 holo_gold : source_color = vec3(1.000, 0.690, 0.220);
uniform vec3 holo_cream : source_color = vec3(1.000, 0.860, 0.520);
uniform vec3 holo_cyan : source_color = vec3(0.520, 0.760, 0.780);
uniform vec3 holo_pink : source_color = vec3(0.900, 0.560, 0.520);
uniform float holo_strength : hint_range(0.0, 0.6, 0.01) = 0.22;
uniform float paper_texture : hint_range(0.0, 0.08, 0.001) = 0.018;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float glancing = 1.0 - facing;
	float height_shift = clamp((VERTEX.y + 0.01) * 50.0, 0.0, 1.0);
	float shift = clamp(glancing * 1.08 + height_shift * 0.18, 0.0, 1.0);
	vec3 holo = mix(holo_gold, holo_cream, smoothstep(0.18, 0.52, shift));
	holo = mix(holo, holo_cyan, smoothstep(0.48, 0.78, shift) * 0.42);
	holo = mix(holo, holo_pink, smoothstep(0.76, 1.0, shift) * 0.28);
	vec3 ink = mix(base_edge, warm_edge, smoothstep(0.18, 0.74, glancing) * 0.34);
	vec3 color = mix(ink, holo, smoothstep(0.32, 0.86, glancing) * holo_strength);
	float grain = fract(sin(dot(VERTEX, vec3(131.7, 79.3, 41.1))) * 43758.5453);
	ALBEDO = color + (grain - 0.5) * paper_texture;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	vec3 normal_dir = normalize(NORMAL);
	vec3 light_dir = normalize(LIGHT);
	float light_amount = clamp(dot(normal_dir, light_dir), 0.0, 1.0);
	float toon_light = smoothstep(0.16, 0.48, light_amount);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * mix(0.64, 1.0, toon_light);
}
