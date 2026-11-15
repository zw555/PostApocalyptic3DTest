shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D player_mask : source_color, repeat_disable, filter_nearest;
uniform vec2 texel_size;
uniform vec4 outline_color : source_color = vec4(0.914, 0.871, 0.773, 1.0);
uniform float opacity = 0.0;
uniform float intensity = 0.82;
uniform float width_pixels = 2.0;
uniform float center_depth = 22.0;
uniform float depth_span = 2.0;
uniform float depth_bias = 0.065;
void vertex() {
	// Godot 4.3+ reverse Z: the near plane is at 1, not 0.
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}
float eye_depth(vec2 uv, mat4 inverse_projection) {
	float raw_depth = texture(scene_depth, uv).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, raw_depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, raw_depth);
	#endif
	vec4 surface = inverse_projection * vec4(ndc, 1.0);
	return -surface.z / surface.w;
}
void fragment() {
	vec4 mask = texture(player_mask, SCREEN_UV);
	if (mask.g < 0.5) { discard; }
	float interior = 1.0;
	for (int i = 0; i < 8; i++) {
		float angle = float(i) * 0.785398163;
		vec2 delta = vec2(cos(angle), sin(angle)) * texel_size * width_pixels;
		interior = min(interior, texture(player_mask, SCREEN_UV + delta).g);
	}
	float edge = 1.0 - step(0.5, interior);
	if (edge < 0.01) { discard; }
	float scene_eye_depth = eye_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float player_eye_depth = center_depth + (mask.r * 2.0 - 1.0) * depth_span;
	// Crucial: a visible player pixel has matching depth and receives no overlay.
	float occluded = step(depth_bias, player_eye_depth - scene_eye_depth);
	// The scene uses MSAA while the small mask is single-sampled. Protect a
	// one-pixel neighborhood of exposed player surfaces at depth discontinuities.
	float exposed_neighbor = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 uv = SCREEN_UV + vec2(float(x), float(y)) * texel_size;
			vec4 nearby = texture(player_mask, uv);
			float player_depth = center_depth + (nearby.r * 2.0 - 1.0) * depth_span;
			float matching_depth = 1.0 - step(depth_bias, abs(player_depth - eye_depth(uv, INV_PROJECTION_MATRIX)));
			exposed_neighbor = max(exposed_neighbor, step(0.5, nearby.g) * matching_depth);
		}
	}
	occluded *= 1.0 - exposed_neighbor;
	ALBEDO = outline_color.rgb;
	ALPHA = edge * occluded * opacity * intensity * outline_color.a;
}
