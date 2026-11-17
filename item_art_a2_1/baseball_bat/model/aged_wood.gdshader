shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 wood_color : source_color = vec4(0.43,0.375,0.31,1.0);
varying vec3 object_pos;
float hash3(vec3 p){ return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise3(vec3 p){
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float line_distance(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0));}
void vertex(){object_pos=VERTEX;}
void fragment(){
 vec3 p=object_pos;
 float s=0.075-p.z;
 // One off-centre billet field through the entire solid, including both ends.
 // No atan/UV branch: there is no material discontinuity at cylindrical U=0/1.
 vec2 offset=vec2(0.096,0.028)+vec2(sin(s*5.0),cos(s*4.0))*0.0016;
 float radius=length((p.xy+offset)*vec2(1.0,0.87));
 float warp=noise3(vec3(p.xy*74.0,s*3.5));
 float phase=radius*1700.0+warp*5.0+sin(radius*330.0)*1.3;
 phase+=noise3(vec3(p.xy*310.0,s*13.0))*0.75;
 float phase_aa=max(fwidth(phase),0.015);
 float grain_resolved=1.0-smoothstep(1.0,4.0,phase_aa);
 float latewood=smoothstep(0.62-phase_aa*0.25,0.94+phase_aa*0.25,sin(phase))*grain_resolved;
 float cloud=noise3(vec3(p.xy*42.0,s*8.0));
 float fiber=noise3(vec3(p.xy*2700.0,s*26.0));
 float fine_resolved=1.0-smoothstep(0.2,1.3,length(fwidth(p))*1800.0);
 float pore=smoothstep(0.59,0.85,fiber)*fine_resolved;
 float weather=noise3(vec3(p.xy*135.0,s*20.0));
 float broken_fiber=noise3(vec3(p.xy*720.0,s*37.0));
 latewood*=0.55+0.45*noise3(vec3(p.xy*190.0,s*19.0));
 float grip=(1.0-smoothstep(0.19,0.25,s))*smoothstep(0.025,0.055,s);
 float hand_oil=grip*(0.09+0.07*noise3(vec3(p.xy*65.0,s*23.0)));
 float rubbed=smoothstep(0.52,0.66,s)*(1.0-smoothstep(0.77,0.81,s));
 float scratch=0.0;
 float aa=max(length(fwidth(p.xz)),0.000035);
 for(int i=0;i<12;i++){
  float seed=float(i);
  vec2 a=vec2(-0.027+hash3(vec3(seed,2,5))*0.054,-0.26-hash3(vec3(seed,6,9))*0.43);
  vec2 b=a+vec2((hash3(vec3(seed,4,7))-0.5)*0.004,0.008+hash3(vec3(seed,8,3))*0.022);
  scratch=max(scratch,1.0-smoothstep(0.00012,0.00012+aa,line_distance(p.xz,a,b)));
 }
 vec3 base=wood_color.rgb*(0.84+cloud*0.24+weather*0.14-latewood*0.32-pore*0.14-hand_oil);
 base*=1.0+(broken_fiber-0.5)*0.16*fine_resolved;
 base=mix(base,base*vec3(0.91,0.94,0.98),smoothstep(0.46,0.80,weather)*0.65);
 ALBEDO=mix(base,base*1.20,scratch*0.45+rubbed*0.07);
 ROUGHNESS=clamp(0.77+latewood*0.08+pore*0.08+cloud*0.05-scratch*0.04-hand_oil*0.45,0.55,0.95);
 METALLIC=0.0;
 SPECULAR=0.32;
}
