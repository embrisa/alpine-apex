shader_type particles;
render_mode disable_force, disable_velocity;
uniform float emission_ratio = 0.0;
uniform vec3 skier_velocity = vec3(0);
float hash(float x) { return fract(sin(x*127.1+311.7)*43758.5453); }
void start() {
 float id=float(NUMBER)+float(RANDOM_SEED%10000u);
 float r=hash(id); float s=hash(id+7.0);
 ACTIVE=hash(id+19.0)<emission_ratio;
 TRANSFORM=EMISSION_TRANSFORM;
 TRANSFORM[3].xyz+=(EMISSION_TRANSFORM*vec4((r-.5)*.08,.025,(s-.5)*1.25,0)).xyz;
 TRANSFORM[3].xyz-=skier_velocity*hash(id+31.0)/60.0;
 VELOCITY=skier_velocity*.12+(EMISSION_TRANSFORM*vec4((r-.5)*3.0,1.0+s*2.2,-.8,0)).xyz;
 CUSTOM=vec4(0,r,0,mix(.018,.035,s));
 COLOR=vec4(1,.64,.12,1);
}
void process() {
 CUSTOM.x+=DELTA/LIFETIME;
 if(CUSTOM.x>=1.0) ACTIVE=false;
 VELOCITY+=vec3(0,-9.81,0)*DELTA;
 TRANSFORM[3].xyz+=VELOCITY*DELTA;
 TRANSFORM[0].xyz=vec3(CUSTOM.w,0,0);
 TRANSFORM[1].xyz=vec3(0,CUSTOM.w*3.0,0);
 TRANSFORM[2].xyz=vec3(0,0,CUSTOM.w);
 COLOR=vec4(mix(vec3(1,.72,.18),vec3(1,.19,.015),CUSTOM.x),pow(1.0-CUSTOM.x,1.5));
}
