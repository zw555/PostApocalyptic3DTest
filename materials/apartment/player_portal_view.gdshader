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
uniform vec3 view_to_camera; // Retained binding; never used as player vision.
uniform vec2 portal_height = vec2(0.02,2.1);
uniform float portal_half_width = 0.49;
uniform bool aperture_open = false;
uniform vec3 observer_eye;
uniform mat4 leaf_inverse;
uniform vec3 leaf_half_size;
uniform sampler2D occlusion_planes : filter_nearest, repeat_disable;
uniform vec2 fan_size = vec2(12.0,8.0);
uniform float peek_range = 5.0;
uniform float surface_tolerance = 0.035;
instance uniform float region_coverage = 1.0;
varying vec3 world_point;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
bool leaf_blocks(vec3 point) {
	vec3 start = (leaf_inverse*vec4(observer_eye,1.0)).xyz;
	vec3 finish = (leaf_inverse*vec4(point,1.0)).xyz;
	vec3 direction = finish-start;
	float enter = 0.0;
	float leave = 1.0;
	for (int axis=0;axis<3;axis++) {
		if (abs(direction[axis]) < 0.000001) {
			if (abs(start[axis]) > leaf_half_size[axis]) { return false; }
		} else {
			float a = (-leaf_half_size[axis]-start[axis])/direction[axis];
			float b = (leaf_half_size[axis]-start[axis])/direction[axis];
			enter = max(enter,min(a,b));
			leave = min(leave,max(a,b));
			if (enter > leave) { return false; }
		}
	}
	return leave > 0.0001 && enter < 0.9999;
}
bool player_sees(vec3 point) {
	if (!aperture_open) { return false; }
	vec3 ray = point-observer_eye;
	float distance_to_point = length(ray);
	if (distance_to_point > peek_range) { return false; }
	float divisor = dot(portal_normal,ray);
	if (abs(divisor) < 0.00001) { return false; }
	float fraction = dot(portal_normal,portal_origin-observer_eye)/divisor;
	vec3 crossing = observer_eye+ray*fraction;
	float across = dot(crossing-portal_origin,portal_tangent);
	if (fraction <= 0.0 || fraction >= 1.0 || abs(across) > portal_half_width || crossing.y < portal_height.x || crossing.y > portal_height.y || leaf_blocks(point)) { return false; }
	vec2 uv = vec2(across/(portal_half_width*2.0)+0.5,(crossing.y-portal_height.x)/(portal_height.y-portal_height.x));
	vec3 unit_ray = ray/max(distance_to_point,0.0001);
	// Native rays store the nearest hit plane. Intersecting the actual fragment
	// direction with this plane keeps a large flat floor continuous between rays.
	vec4 plane = texture(occlusion_planes,uv);
	float limit = peek_range;
	if (length(plane.xyz) > 0.5) {
		float dot_ray = dot(plane.xyz,unit_ray);
		if (abs(dot_ray) > 0.00001) {
			float hit_distance = (plane.w-dot(plane.xyz,observer_eye))/dot_ray;
			if (hit_distance >= 0.0) { limit = hit_distance; }
		}
	} else { limit = plane.w; }
	return distance_to_point <= limit+surface_tolerance;
}
void fragment() {
	int x = int(FRAGCOORD.x) % 4;
	int y = int(FRAGCOORD.y) % 4;
	float threshold = (float(((x & 1)*2+(y & 1))*4+((x >> 1)*2+(y >> 1)))+0.5)/16.0;
	if (region_coverage < threshold && !player_sees(world_point)) { discard; }
	vec4 paint = base_color*texture(base_texture,UV*uv_scale.xy+uv_offset.xy);
	ALBEDO = paint.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	SPECULAR = specular_value;
	EMISSION = emission_color;
}
