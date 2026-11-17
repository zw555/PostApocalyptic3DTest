shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform bool cut_face=false;
varying vec3 object_pos;
void vertex(){object_pos=VERTEX;}
void fragment(){
 vec3 p=object_pos;
 float resolved=1.0-smoothstep(0.3,1.8,length(fwidth(p))*1800.0);
 float weave=sin((p.x+p.z)*9200.0)*sin(p.y*9600.0)*resolved;
 float phase=length(p.xz)*4500.0;
 float rings=(0.5+0.5*sin(phase))*(1.0-smoothstep(0.5,3.0,fwidth(phase)));
 float cut=cut_face?1.0:0.0;
 ALBEDO=vec3(0.66,0.64,0.55)*(0.95+weave*0.055-cut*rings*0.13);
 ROUGHNESS=0.96;
 METALLIC=0.0;
 SPECULAR=0.15;
}
