shader_type spatial;
render_mode diffuse_burley;

uniform vec4 base_color : source_color = vec4(0.4, 0.45, 0.4, 1.0);
uniform float grain = 0.08;
uniform float surface_roughness = 0.85;
uniform bool floor_tiles = false;
uniform bool wood_grain = false;
varying vec3 world_pos;

float hash(vec3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float smooth_noise(vec3 p) {
    vec3 cell = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(cell), hash(cell + vec3(1,0,0)), f.x),
                   mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), f.x),
                   mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    float speckle = smooth_noise(world_pos * 28.0);
    float broad = smooth_noise(world_pos * 3.0);
    vec3 color = base_color.rgb * (1.0 + (speckle - 0.5) * grain + (broad - 0.5) * grain * 0.5);
    if (floor_tiles) {
        vec2 cell = abs(fract(world_pos.xz / 0.6) - 0.5);
        float grout = smoothstep(0.481, 0.494, max(cell.x, cell.y));
        float tile = hash(vec3(floor(world_pos.xz / 0.6), 2.0));
        color *= (0.95 + tile * 0.10) * (1.0 - grout * 0.24);
    }
    if (wood_grain) {
        color *= 0.96 + 0.04 * sin(world_pos.x * 95.0 + sin(world_pos.z * 8.0));
    }
    ALBEDO = color;
    ROUGHNESS = surface_roughness;
}
