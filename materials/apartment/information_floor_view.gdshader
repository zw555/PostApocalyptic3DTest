shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D base_texture : source_color, hint_default_white, filter_linear_mipmap;
uniform vec3 uv_scale = vec3(1.0);
uniform float roughness_value = 0.8;
uniform sampler2D permission_field : filter_linear, repeat_disable;
uniform sampler2D zone_mask : filter_nearest, repeat_disable;
uniform vec2 local_min;
uniform vec2 local_size;
uniform mat4 surface_transform = mat4(1.0);
instance uniform float region_coverage = 1.0;
varying vec2 local_uv;
void vertex() { local_uv = ((surface_transform*vec4(VERTEX,1.0)).xz-local_min)/local_size; }
void fragment() {
 float coverage = max(region_coverage,texture(permission_field,local_uv).r)*texture(zone_mask,local_uv).r;
 if(coverage <= 0.001) discard;
 vec4 paint = base_color*texture(base_texture,UV*uv_scale.xy);
 ALBEDO = paint.rgb;
 ROUGHNESS = roughness_value;
 ALPHA = paint.a*coverage;
}
