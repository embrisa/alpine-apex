shader_type particles;
render_mode disable_force, disable_velocity;
uniform int kind = 0; // powder, ballistic grains, suspended mist
uniform float emission_ratio = 0.0;
uniform float contact_energy = 0.0;
uniform float ejection_m_s = 1.0;
uniform float throw_side = 1.0;
uniform vec3 skier_velocity = vec3(0);
uniform vec3 wind_velocity = vec3(0);
float hash(float p) { return fract(sin(p*127.1+311.7)*43758.5453); }
void start() {
 float id=float(NUMBER)+float(RANDOM_SEED%10000u);
 float r=hash(id+1.0); float s=hash(id+7.0);
 ACTIVE=hash(id+19.0)<emission_ratio;
 TRANSFORM=EMISSION_TRANSFORM;
 // Spread births along the ski and its most recent GPU step at extreme speed.
 TRANSFORM[3].xyz+=(EMISSION_TRANSFORM*vec4((r-.5)*.09,.025,(s-.5)*1.3,0)).xyz;
 TRANSFORM[3].xyz-=skier_velocity*hash(id+31.0)/60.0;
 vec3 local=vec3(throw_side*mix(.65,1.15,r),mix(.35,.85,s),mix(-.3,.2,hash(id+5.0)));
 VELOCITY=(EMISSION_TRANSFORM*vec4(local,0)).xyz*ejection_m_s*mix(.55,1.0,hash(id+13.0));
 VELOCITY+=skier_velocity*(kind==1 ? .16 : .09);
 float size=kind==1 ? mix(.012,.055,r) : (kind==2 ? mix(.30,.65,r) : mix(.14,.32,r));
 CUSTOM=vec4(0,s,contact_energy,size*(1.0+contact_energy*(kind==1 ? 1.1 : 2.2)));
 COLOR=vec4(1);
}
void process() {
 CUSTOM.x+=DELTA/LIFETIME;
 float age=CUSTOM.x;
 if(age>=1.0) { ACTIVE=false; }
 float drag=kind==1 ? .28 : (kind==2 ? 2.0 : 1.15);
 vec3 gravity=vec3(0,kind==1 ? -9.81 : (kind==2 ? -.25 : -2.8),0);
 VELOCITY=mix(VELOCITY,wind_velocity,1.0-exp(-drag*DELTA))+gravity*DELTA;
 // Slowly varying eddies use each grain's birth seed; no CPU particle updates.
 if(kind!=1) {
  VELOCITY+=vec3(sin(age*6.0+CUSTOM.y*35.0),.15,cos(age*5.0+CUSTOM.y*27.0))*DELTA*.5;
 }
 TRANSFORM[3].xyz+=VELOCITY*DELTA;
 float size=CUSTOM.w*(kind==1 ? 1.0 : 1.0+age*(kind==2 ? 3.0 : 2.4));
 TRANSFORM[0].xyz=vec3(size,0,0);
 TRANSFORM[1].xyz=vec3(0,size,0);
 TRANSFORM[2].xyz=vec3(0,0,size);
 COLOR=vec4(vec3(.97+CUSTOM.y*.03),smoothstep(0.0,.045,age)*pow(1.0-age,kind==2 ? 1.65 : 1.1));
}
