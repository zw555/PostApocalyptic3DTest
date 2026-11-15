shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.64, 0.63, 0.56, 1.0);
uniform float roughness = 0.94;
uniform float wear_amount = 0.30;
uniform float dust_amount = 0.25;
uniform float noise_scale = 1.5;
uniform bool floor_surface = true;
varying vec3 world_pos;

float hash2(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q,q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}
float noise2(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash2(i), hash2(i + vec2(1,0)), f.x),
               mix(hash2(i + vec2(0,1)), hash2(i + vec2(1,1)), f.x), f.y);
}
float smudge(vec2 p, vec2 center, vec2 radius, float seed) {
    vec2 q = (p - center) / radius;
    if (any(greaterThan(abs(q),vec2(1.6)))) { return 0.0; }
    float edge = length(q) + (noise2(q * 2.1 + seed) - 0.5) * 0.38;
    return (1.0 - smoothstep(0.28, 1.15, edge)) * (0.65 + noise2(p * 5.0 + seed) * 0.35);
}
float footprint(vec2 p, vec2 center, float angle) {
    float c = cos(angle), s = sin(angle);
    vec2 q = mat2(vec2(c,s),vec2(-s,c)) * (p - center);
    if (any(greaterThan(abs(q),vec2(0.19)))) { return 0.0; }
    vec2 sole = q / vec2(0.052,0.12);
    return (1.0 - smoothstep(0.45,1.15,length(sole))) * (0.7 + noise2(p*20.0)*0.3);
}
float scratches(vec2 p, vec2 center) {
    vec2 q = p - center;
    q = mat2(vec2(0.9,0.43),vec2(-0.43,0.9))*q;
    float aa = max(fwidth(q.y),0.005);
    float lines = 1.0 - smoothstep(0.002,0.002+aa,abs(q.y));
    lines += 0.6 * (1.0 - smoothstep(0.002,0.002+aa,abs(q.y+0.055)));
    return lines * (1.0 - smoothstep(0.14,0.35,abs(q.x)));
}
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
    vec3 color = base_color.rgb;
    if (floor_surface) {
        vec2 p = world_pos.xz;
        float broad = noise2(p * noise_scale);
        color *= 0.975 + broad * 0.05;
        vec2 cell = abs(fract(p / 0.6) - 0.5);
        vec2 aa = max(fwidth(p/0.6),vec2(0.002));
        float seam = max(smoothstep(0.496-aa.x,0.5,cell.x),smoothstep(0.496-aa.y,0.5,cell.y));
        color *= 1.0 - seam * 0.09;
        float stains = smudge(p,vec2(-4.25,1.75),vec2(0.80,0.48),1.0);
        stains = max(stains,smudge(p,vec2(4.4,0.95),vec2(0.65,0.42),4.0));
        stains = max(stains,smudge(p,vec2(-5.45,-1.75),vec2(0.48,0.65),7.0));
        stains = max(stains,smudge(p,vec2(-5.0,-3.25),vec2(0.72,0.55),12.0));
        stains = max(stains,smudge(p,vec2(5.1,3.9),vec2(0.72,0.45),19.0));
        stains = max(stains,smudge(p,vec2(-1.9,-3.3),vec2(0.40,0.23),21.0)*0.5);
        color = mix(color, color * vec3(0.78,0.77,0.70), stains * wear_amount * 1.5);
        float wall_dust = exp(-max(0.0,min(6.0-abs(p.x),5.0-abs(p.y)))*7.0);
        color *= 1.0 - wall_dust * dust_amount * 0.23;
        float tracks = footprint(p,vec2(5.5,2.85),-1.2);
        tracks = max(tracks,footprint(p,vec2(5.02,2.65),-1.3));
        tracks = max(tracks,footprint(p,vec2(4.55,2.86),-1.4));
        tracks = max(tracks,footprint(p,vec2(4.08,2.65),-1.5));
        color *= 1.0 - tracks * 0.10;
        float scuff = scratches(p,vec2(4.35,1.2)) + scratches(p,vec2(-4.1,1.4));
        color *= 1.0 - scuff * 0.08;
    } else {
        vec2 p = vec2(world_pos.x + world_pos.z,world_pos.y);
        float broad = noise2(p * noise_scale);
        color *= 0.98 + broad * 0.04;
        float chips_noise = noise2(p * 8.0 + 14.3);
        float aa = max(fwidth(chips_noise),0.015);
        float chips = smoothstep(0.74-aa,0.82+aa,chips_noise);
        chips *= smoothstep(0.10,0.65,world_pos.y) * (1.0-smoothstep(1.7,2.6,world_pos.y));
        color = mix(color,color * 1.16 + vec3(0.015),chips * wear_amount * 0.7);
        float dust = exp(-max(world_pos.y,0.0)*7.0) * (0.65+broad*0.35);
        float corners = exp(-length(world_pos.xz-vec2(-5.9,-4.9))*2.0);
        corners = max(corners,exp(-length(world_pos.xz-vec2(5.9,-4.9))*2.0));
        color *= 1.0 - dust * dust_amount * 0.45 - corners * dust_amount * 0.25;
        float faded = smoothstep(0.53,0.75,noise2(p*0.85+4.0));
        color = mix(color,color*1.04,faded*wear_amount);
    }
    ALBEDO = color;
    ROUGHNESS = roughness;
    SPECULAR = 0.20;
}
