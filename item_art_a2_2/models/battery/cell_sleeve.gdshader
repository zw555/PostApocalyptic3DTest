shader_type spatial;
varying vec3 object_pos;
void vertex(){object_pos=VERTEX;}
void fragment(){
 float label=step(0.30,UV.y)*(1.0-step(0.70,UV.y));
 vec3 olive=vec3(0.19,0.22,0.15);
 vec3 paper=vec3(0.55,0.54,0.44);
 float stripe=step(0.40,UV.y)*(1.0-step(0.44,UV.y));
 float dash=step(0.48,UV.y)*(1.0-step(0.51,UV.y))*step(0.2,fract(UV.x*4.0));
 ALBEDO=mix(olive,paper,label)*(1.0-(stripe+dash)*0.30);
 ROUGHNESS=0.79;
 METALLIC=0.0;
}
