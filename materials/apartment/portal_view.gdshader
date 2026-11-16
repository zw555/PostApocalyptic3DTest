shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float roughness_value = 0.8;
uniform float metallic_value = 0.0;
uniform float specular_value = 0.25;
uniform vec3 emission_color : source_color = vec3(0.0);
uniform vec3 portal_origin;
uniform vec3 portal_normal;
uniform vec3 portal_tangent;
uniform vec3 view_to_camera;
uniform vec2 portal_height = vec2(0.02,2.1);
uniform float portal_half_width = 0.49;
uniform bool aperture_open = false;
instance uniform float region_coverage = 1.0;
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	float denominator = dot(portal_normal,view_to_camera);
	float travel = dot(portal_normal,portal_origin-world_point)/(abs(denominator) < 0.0001 ? 0.0001 : denominator);
	vec3 crossing = world_point + view_to_camera*travel;
	bool in_portal = aperture_open && abs(denominator) >= 0.0001 && travel >= 0.0 && abs(dot(crossing-portal_origin,portal_tangent)) <= portal_half_width && crossing.y >= portal_height.x && crossing.y <= portal_height.y;
	// Stable 4x4 ordered dissolve only while crossing a region boundary.
	int x = int(FRAGCOORD.x) % 4;
	int y = int(FRAGCOORD.y) % 4;
	float threshold = (float(((x & 1) * 2 + (y & 1)) * 4 + ((x >> 1) * 2 + (y >> 1)))+0.5)/16.0;
	if (!in_portal && region_coverage < threshold) { discard; }
	vec4 paint = base_color*texture(base_texture,UV*uv_scale.xy+uv_offset.xy);
	ALBEDO = paint.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
	EMISSION = emission_color;
}
