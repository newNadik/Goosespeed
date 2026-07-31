shader_type spatial;

render_mode cull_disabled, depth_draw_opaque, ambient_light_disabled, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float base_brightness : hint_range(0.0, 1.0) = 0.84;
uniform float saturated_brightness : hint_range(0.0, 1.0) = 0.9;
uniform vec4 lit_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.58, 0.66, 0.69, 1.0);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.42;
uniform float shadow_cutoff : hint_range(0.0, 1.0) = 0.08;

void fragment() {
	vec4 texture_color = texture(albedo_texture, UV);
	float max_channel = max(texture_color.r, max(texture_color.g, texture_color.b));
	float min_channel = min(texture_color.r, min(texture_color.g, texture_color.b));
	float saturation = max_channel > 0.0 ? (max_channel - min_channel) / max_channel : 0.0;
	float saturation_mix = smoothstep(0.2, 0.55, saturation);
	float adjusted_brightness = mix(base_brightness, saturated_brightness, saturation_mix);

	ALBEDO = texture_color.rgb * lit_tint.rgb * adjusted_brightness;
	ALPHA = texture_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = 1.0;
}

void light() {
	float shadow_mask = step(shadow_cutoff, 1.0 - ATTENUATION);
	vec3 shadowed_color = mix(ALBEDO, ALBEDO * shadow_tint.rgb, shadow_strength);
	vec3 flat_color = mix(ALBEDO, shadowed_color, shadow_mask);

	DIFFUSE_LIGHT += flat_color;
}
