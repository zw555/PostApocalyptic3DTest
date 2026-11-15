shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
// A private, linear-tonemapped viewport records only the frontmost player surface.
uniform float center_depth = 22.0;
uniform float depth_span = 2.0;
void fragment() {
	ALBEDO = vec3(clamp((-VERTEX.z - center_depth + depth_span) / (2.0 * depth_span), 0.0, 1.0), 1.0, 0.0);
}
