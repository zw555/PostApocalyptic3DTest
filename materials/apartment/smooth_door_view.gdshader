shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
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
uniform bool aperture_open = false;
uniform sampler2D floor_field : filter_linear, repeat_disable;
uniform vec2 field_extent = vec2(2.4,3.0);
instance uniform float region_coverage = 1.0;
instance uniform float object_coverage = 0.0;
instance uniform bool floor_surface = false;
varying vec3 world_point;
void vertex() { world_point = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float neighbor = 0.0;
	if (aperture_open) {
		neighbor = object_coverage;
		if (floor_surface) {
			vec3 relative = world_point-portal_origin;
			vec2 uv = vec2(dot(relative,portal_tangent),dot(relative,portal_normal))/(2.0*field_extent)+0.5;
			neighbor = texture(floor_field,clamp(uv,vec2(0.0),vec2(1.0))).r;
			if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { neighbor = 0.0; }
		}
	}
	float coverage = max(region_coverage,neighbor);
	if (coverage <= 0.001) { discard; }
	vec4 paint = base_color*texture(base_texture,UV*uv_scale.xy+uv_offset.xy);
	ALBEDO = paint.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
	EMISSION = emission_color;
	ALPHA = paint.a*coverage;
}
