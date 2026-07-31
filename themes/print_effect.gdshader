shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float colour_levels : hint_range(3.0, 12.0, 1.0) = 7.0;
uniform float effect_strength : hint_range(0.0, 1.0) = 0.65;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.45;
uniform float pattern_scale : hint_range(1.0, 4.0, 1.0) = 1.0;
uniform float shadow_start : hint_range(0.0, 1.0) = 0.35;
uniform float shadow_end : hint_range(0.0, 1.0) = 0.85;
uniform vec4 paper_tint : source_color = vec4(0.945, 0.875, 0.741, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.094, 0.184, 0.267, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.14;


float bayer4(vec2 pixel_coord) {
	int x = int(mod(pixel_coord.x, 4.0));
	int y = int(mod(pixel_coord.y, 4.0));
	int index = y * 4 + x;

	if (index == 0) return 0.0 / 16.0;
	if (index == 1) return 8.0 / 16.0;
	if (index == 2) return 2.0 / 16.0;
	if (index == 3) return 10.0 / 16.0;
	if (index == 4) return 12.0 / 16.0;
	if (index == 5) return 4.0 / 16.0;
	if (index == 6) return 14.0 / 16.0;
	if (index == 7) return 6.0 / 16.0;
	if (index == 8) return 3.0 / 16.0;
	if (index == 9) return 11.0 / 16.0;
	if (index == 10) return 1.0 / 16.0;
	if (index == 11) return 9.0 / 16.0;
	if (index == 12) return 15.0 / 16.0;
	if (index == 13) return 7.0 / 16.0;
	if (index == 14) return 13.0 / 16.0;
	return 5.0 / 16.0;
}


void fragment() {
	vec4 source = texture(screen_texture, SCREEN_UV);
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float shadow_mask = 1.0 - smoothstep(shadow_start, shadow_end, luminance);
	float highlight_mask = smoothstep(0.45, 1.0, luminance);

	float threshold = bayer4(FRAGCOORD.xy / pattern_scale) - 0.5;
	float scale = colour_levels - 1.0;
	vec3 posterised = floor(source.rgb * scale + 0.5 + threshold * dither_strength * shadow_mask) / scale;

	vec3 tinted = mix(posterised, paper_tint.rgb, tint_strength * highlight_mask);
	tinted = mix(tinted, shadow_tint.rgb, tint_strength * shadow_mask);

	vec3 result = mix(source.rgb, tinted, effect_strength);
	COLOR = vec4(result, source.a);
}
