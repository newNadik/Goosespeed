shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

group_uniforms Color;
uniform vec4 base_color: source_color = vec4(0.302, 0.558, 0.343, 1.0);
uniform vec4 top_color: source_color = vec4(0.485, 0.710, 0.375, 1.0);

group_uniforms Wind;
uniform vec2 wind_direction = vec2(1.0, 0.35);
uniform float wind_strength: hint_range(0.0, 2.0, 0.01) = 0.35;
uniform float wind_speed: hint_range(0.0, 8.0, 0.01) = 1.35;
uniform float wave_scale: hint_range(0.0, 1.0, 0.001) = 0.035;
uniform float gust_strength: hint_range(0.0, 1.0, 0.01) = 0.35;

group_uniforms Shape;
uniform float base_y = -0.62;
uniform float top_y = 12.9;
uniform float root_stiffness: hint_range(0.0, 1.0, 0.01) = 0.16;

varying float height_factor;


void vertex() {
	float local_height = clamp((VERTEX.y - base_y) / max(top_y - base_y, 0.001), 0.0, 1.0);
	height_factor = local_height;

	float sway_mask = smoothstep(root_stiffness, 1.0, local_height);
	sway_mask *= sway_mask;

	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 wind = normalize(wind_direction);
	float phase = dot(world_position.xz, wind) * wave_scale + TIME * wind_speed;
	float gust = sin(phase) + sin(phase * 1.73 + TIME * wind_speed * 0.41) * gust_strength;

	VERTEX.xz += wind * gust * wind_strength * sway_mask;
}


void fragment() {
	ALBEDO = mix(base_color.rgb, top_color.rgb, height_factor * 0.65);
	ROUGHNESS = 0.95;
}
