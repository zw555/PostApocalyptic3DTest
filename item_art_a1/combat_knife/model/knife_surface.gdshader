shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 base_color : source_color = vec4(0.36,0.39,0.38,1.0);
uniform float metalness : hint_range(0.0,1.0) = 0.78;
uniform float base_roughness : hint_range(0.0,1.0) = 0.46;
uniform bool grip = false;
uniform float wear : hint_range(0.0,1.0) = 0.18;
varying vec3 model_pos;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
float segment_distance(vec2 p, vec2 a, vec2 b){vec2 q=p-a;vec2 d=b-a;return length(q-d*clamp(dot(q,d)/dot(d,d),0.0,1.0));}
void vertex(){model_pos=VERTEX;}
void fragment(){
 vec3 p=model_pos;
 float cloud=noise3(p*87.0);
 float micro=noise3(p*4300.0);
 float resolved=1.0-smoothstep(0.3,1.5,length(fwidth(p))*2200.0);
 if(grip){
  float pattern=(p.z+abs(p.x)*0.65)*950.0;
  float chevron=smoothstep(0.84,0.97,abs(sin(pattern)))*resolved;
  ALBEDO=base_color.rgb*(0.90+cloud*0.15+micro*0.055-chevron*0.20);
  ROUGHNESS=clamp(base_roughness+chevron*0.08+(micro-0.5)*0.07,0.0,1.0);
 }else{
  float grain=noise3(vec3(p.z*15000.0,p.x*58.0,p.y*37.0));
  float lines=smoothstep(0.83,0.98,grain)*resolved;
  float stain=smoothstep(0.54,0.91,cloud)*wear;
  float scuff=0.0;
  float aa=max(length(fwidth(p.xz))*0.7,0.000025);
  for(int i=0;i<18;i++){
   float seed=float(i);
   vec2 a=vec2(-0.013+hash3(vec3(seed,4,7))*0.023,-0.077-hash3(vec3(seed,8,3))*0.116);
   vec2 b=a+vec2(0.003+hash3(vec3(seed,2,9))*0.007,0.0005+hash3(vec3(seed,6,1))*0.005);
   scuff=max(scuff,1.0-smoothstep(0.000035,0.000035+aa,segment_distance(p.xz,a,b)));
  }
  ALBEDO=mix(base_color.rgb*(0.96+micro*0.065-lines*0.13-scuff*0.12),vec3(0.23,0.195,0.15),stain);
  ROUGHNESS=clamp(base_roughness+lines*0.12+stain*0.38+scuff*0.13+(cloud-0.5)*0.055,0.0,1.0);
 }
 METALLIC=metalness;
 SPECULAR=0.5;
}
