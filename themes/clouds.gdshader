/******************************************************************
Clouds = Synty models cloud shader for Godot.
(C) Copyright 2025 - Giancarlo Niccolai
Published under MIT licence.

# Overview

Adapted for GooseSpeed to use local material uniforms only.

*/

shader_type spatial;
render_mode unshaded, cull_disabled;

group_uniforms Color;
uniform vec4 top_color: source_color = vec4(0.965, 0.929, 0.847, 1.0);
uniform vec4 base_color: source_color = vec4(0.945, 0.875, 0.741, 1.0);
uniform vec4 shadow_color: source_color = vec4(0.435, 0.518, 0.565, 1.0);

group_uniforms Lighting;
uniform vec3 light_direction = vec3(0.45, -0.7, 0.25);
uniform float shadow_threshold: hint_range(-1.0, 1.0) = -0.15;
uniform float shadow_strength: hint_range(0.0, 1.0) = 0.55;
uniform bool enable_rim = true;
uniform float rim_power: hint_range(0.25, 8.0) = 2.0;
uniform float rim_strength: hint_range(0.0, 1.0) = 0.25;

group_uniforms Vertex;
uniform float cloud_speed = 0.45;
uniform float cloud_strength = 0.08;


float fresnel_effect(vec3 normal_ws, vec3 view_dir_ws, float power) {
    return pow(1.0 - clamp(dot(normalize(normal_ws), normalize(view_dir_ws)), 0.0, 1.0), power);
}


void vertex() {
	float displacement = cloud_strength * (sin( TIME * cloud_speed + VERTEX.x + VERTEX.z ));
	VERTEX += vec3(0.0, displacement, 0.0);
}


void fragment() {
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 world_view = normalize(INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz;

	float light_step = step(shadow_threshold, dot(-normalize(light_direction), normalize(world_normal)));
	vec3 poster_color = mix(base_color.rgb, shadow_color.rgb, (1.0 - light_step) * shadow_strength);
	poster_color = mix(poster_color, top_color.rgb, light_step * 0.35);

	if (enable_rim) {
		float rim = fresnel_effect(world_normal, world_view, rim_power) * rim_strength;
		poster_color = mix(poster_color, top_color.rgb, rim);
	}

	ALBEDO = poster_color;
	ROUGHNESS = 0.0;
}
