shader_type spatial;
render_mode depth_draw_opaque, cull_disabled, diffuse_toon, specular_disabled;

uniform vec3 paper_color : source_color = vec3(0.960, 0.610, 0.160);
uniform vec3 shadow_color : source_color = vec3(0.610, 0.390, 0.090);
uniform vec3 light_color : source_color = vec3(1.000, 0.820, 0.360);
uniform float paper_texture : hint_range(0.0, 0.08, 0.001) = 0.025;

void fragment() {
	float grain = fract(sin(dot(VERTEX.xy, vec2(173.31, 91.17))) * 43758.5453);
	ALBEDO = paper_color + (grain - 0.5) * paper_texture;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}

void light() {
	vec3 normal_dir = normalize(NORMAL);
	vec3 light_dir = normalize(LIGHT);

	float light_amount = clamp(dot(normal_dir, light_dir), 0.0, 1.0);
	float toon_light = smoothstep(0.20, 0.46, light_amount);
	vec3 color = mix(shadow_color, ALBEDO, toon_light);
	color = mix(color, light_color, max(toon_light - 0.72, 0.0) * 0.16);
	DIFFUSE_LIGHT += color * LIGHT_COLOR * ATTENUATION;
}
