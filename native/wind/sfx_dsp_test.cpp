#include "sfx_dsp.h"
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <thread>
#include <vector>
using namespace alpine_sfx;
int checks=0,failures=0;
void check(bool ok,const char* label){++checks;if(!ok)++failures;std::cout<<(ok?"PASS ":"FAIL ")<<label<<'\n';}
struct Stats {
    double sum=0,energy=0,high=0;float peak=0,previous=0;uint64_t count=0;bool finite=true;
    void add(Frame f){float v=(f.left+f.right)*.5f;finite&=std::isfinite(v);sum+=v;energy+=double(v)*v;high+=double(v-previous)*(v-previous);previous=v;peak=std::max({peak,std::abs(f.left),std::abs(f.right)});++count;}
    double rms()const{return std::sqrt(energy/std::max<uint64_t>(1,count));}
};
Ski ski(float lateral=0,int condition=2,int material=SNOW){return {25,lateral,.5f,400,.08f,.035f,condition,material,true};}
Stats measure(float hz,Ski c){DSP d(hz);d.set_mix({1,1,1,1,true});d.set_ski(0,c);Stats s;for(int i=0;i<int(hz*3);++i){auto f=d.next();if(i>int(hz))s.add(f);}return s;}
Stats strike(float hz,Event event,uint32_t seed=73){DSP d(hz,seed);d.set_mix({1,1,1,1,true});for(int i=0;i<int(hz*.2f);++i)d.next();d.trigger(event);Stats s;for(int i=0;i<int(hz*.5f);++i)s.add(d.next());return s;}
void little(std::ofstream& f,uint32_t n,int bytes){for(int i=0;i<bytes;++i)f.put(char(n>>(i*8)));}
void wav(const std::filesystem::path& path,const std::vector<Frame>& frames,uint32_t rate){
    std::ofstream f(path,std::ios::binary);auto bytes=uint32_t(frames.size()*4);
    f.write("RIFF",4);little(f,bytes+36,4);f.write("WAVEfmt ",8);little(f,16,4);little(f,1,2);little(f,2,2);little(f,rate,4);little(f,rate*4,4);little(f,4,2);little(f,16,2);f.write("data",4);little(f,bytes,4);
    for(auto v:frames){little(f,uint16_t(int16_t(v.left*32767)),2);little(f,uint16_t(int16_t(v.right*32767)),2);}
}
void equipment_auditions(const std::filesystem::path& out){
    const char* names[]={"binding_rattle","carbon_shaft","metal_clink","mixed_knock"};
    const float strengths[]={.5f,2,8,20};
    for(int profile=0;profile<4;++profile){
        DSP d;d.set_mix({1,1,1,1,true});std::vector<Frame> frames;
        for(int i=0;i<48000*6;++i){for(int j=0;j<4;++j)if(i==12000+j*67200)d.trigger({EQUIPMENT,GENERIC,strengths[j],0,.7f,0,profile});frames.push_back(d.next());}
        wav(out/(std::string(names[profile])+".wav"),frames,48000);
    }
    DSP d;alpine_wind::DSP wind;d.set_mix({1,1,1,1,true});wind.set_controls({0,0,-30,.3f,.15f,1,true});std::vector<Frame> frames;
    for(int i=0;i<48000*10;++i){
        d.set_ski(0,ski(2,0));d.set_ski(1,ski(1,2));
        if(i%72000==12000)d.trigger({EQUIPMENT,GENERIC,5,-.25f,.6f,0,(i/72000)%4});
        if(i==48000*4)d.trigger({IMPACT,ROCK,8,.2f,.5f});
        if(i==48000*7)d.trigger({IMPACT,WOOD,8,-.2f,.5f});
        auto a=d.next(),b=wind.next();frames.push_back({a.left+b.left,a.right+b.right});
    }
    wav(out/"natural_skiing_mix.wav",frames,48000);
}
int main(int argc,char** argv){
    for(float hz:{44100.0f,48000.0f}){
        auto glide=measure(hz,ski());auto skid=measure(hz,ski(12));auto powder=measure(hz,ski(8,0));auto deep=measure(hz,{25,8,.5f,400,.3f,.16f,1,SNOW,true});
        check(skid.rms()>glide.rms()*1.25,"Sideways slip clearly increases contact energy");
        check(deep.rms()>powder.rms(),"Deeper penetration produces a stronger displacement layer");
        auto no_contact=ski();no_contact.supported=false;check(measure(hz,no_contact).rms()==0,"Unsupported ski is silent");
        no_contact=ski();no_contact.forward=0;check(measure(hz,no_contact).rms()==0,"Stationary loaded ski is silent");
        for(int c=0;c<6;++c){auto s=measure(hz,ski(9,c));check(s.finite&&s.peak<=DSP::CEILING&&std::abs(s.sum/s.count)<.0002,"Every snow profile is finite, bounded and DC-free");}
        auto rock=measure(hz,ski(8,2,ROCK));check(rock.high/rock.energy>powder.high/powder.energy,"Rock is spectrally distinct from powder");
        DSP d(hz);d.set_mix({1,1,1,1,true});d.set_ski(0,ski(50,0));d.set_ski(1,ski(50,1));d.set_slide({70,1,1,ROCK,2});
        for(int i=0;i<8;++i)check(d.trigger({NEAR_MISS,WOOD,35,0,1}),"Eight bounded transient slots are usable");
        check(!d.trigger({NEAR_MISS,WOOD,35,0,1})&&d.dropped_voices()==1,"Excess low-priority event is dropped");
        check(d.trigger({IMPACT,ROCK,90,0,1})&&d.active_voices()==8,"Impact replaces lower-priority swish without growing pool");
        Stats stress;for(int i=0;i<int(hz);++i)stress.add(d.next());check(stress.finite&&stress.peak<=DSP::CEILING,"Combined maximum layers remain bounded");
        d.set_mix({1,1,1,1,false});d.release();for(int i=0;i<int(hz*3);++i)d.next();auto silence=d.next();check(std::abs(silence.left)+std::abs(silence.right)<1e-8,"Disable settles to silence and old impacts expire");
        Stats long_silence;for(int i=0;i<int(hz*120);++i)long_silence.add(d.next());check(long_silence.finite&&long_silence.peak<1e-8,"Two-minute silence remains finite without noise or DC buildup");
        DSP transitions(hz);transitions.set_mix({1,1,1,1,true});float last=0,max_step=0;Stats transition_stats;
        for(int i=0;i<int(hz*2);++i){if(i%128==0){auto c=ski((i/128)%2?25:0,(i/128)%6,(i/128)%3==0?ROCK:SNOW);c.supported=(i/128)%5!=0;transitions.set_ski(0,c);transitions.set_ski(1,c);transitions.set_mix({(i/128)%7==0?0.0f:1.0f,1,1,1,true});}auto f=transitions.next();max_step=std::max(max_step,std::abs(f.left-last));last=f.left;transition_stats.add(f);}
        check(transition_stats.finite&&transition_stats.peak<=DSP::CEILING&&max_step<.25f,"Rapid contact/material/gain transitions remain smooth and bounded");
        DSP a(hz,45),b(hz,45),other(hz,46);a.set_mix({1,1,1,1,true});b.set_mix({1,1,1,1,true});other.set_mix({1,1,1,1,true});a.set_ski(0,ski());b.set_ski(0,ski());other.set_ski(0,ski());
        bool same=true,different=false;for(int i=0;i<4096;++i){auto x=a.next(),y=b.next(),z=other.next();same&=x.left==y.left;different|=x.left!=z.left;}check(same&&different,"Private seeds reproduce auditions and isolate resources");
        auto bad=ski();bad.forward=std::numeric_limits<float>::infinity();bad.lateral=std::numeric_limits<float>::quiet_NaN();bad.load=-999;auto invalid=measure(hz,bad);check(invalid.finite&&invalid.peak<=DSP::CEILING,"Invalid scalar inputs cannot poison PCM");
        for(int profile=0;profile<4;++profile){
            Event event{EQUIPMENT,GENERIC,2,.4f,.8f,0,profile};auto quiet=strike(hz,event);event.speed=20;auto hard=strike(hz,event);
            check(quiet.rms()>1e-6&&hard.rms()>quiet.rms()*1.5&&hard.finite&&hard.peak<DSP::CEILING,"Every equipment profile is audible, speed-scaled and has headroom");
            DSP tail(hz);tail.set_mix({1,1,1,1,true});tail.trigger(event);for(int i=0;i<int(hz);++i)tail.next();Stats end;for(int i=0;i<1024;++i)end.add(tail.next());
            check(end.peak<1e-8&&tail.active_voices()==0,"Equipment rings and rattles expire without a stuck tone");
        }
        for(int material:{ROCK,WOOD,GENERIC}){
            auto quiet=strike(hz,{IMPACT,material,1});auto hard=strike(hz,{IMPACT,material,20});
            check(hard.finite&&hard.peak<DSP::CEILING&&hard.rms()>quiet.rms()*2,"Hard-surface impacts scale with closing speed and retain headroom");
        }
        auto rock_hit=strike(hz,{IMPACT,ROCK,8});auto wood_hit=strike(hz,{IMPACT,WOOD,8});
        check(rock_hit.high/rock_hit.energy>wood_hit.high/wood_hit.energy*1.3,"Rock knock/grit is spectrally brighter than tree knock/bark");
        auto clink=strike(hz,{EQUIPMENT,GENERIC,8,0,.5f,0,METAL_CLINK});auto shaft=strike(hz,{EQUIPMENT,GENERIC,8,0,.5f,0,SHAFT_TICK});
        check(std::abs(clink.high/clink.energy-shaft.high/shaft.energy)>.01,"Metal fitting and carbon shaft have different spectra");
        DSP muted(hz);muted.set_mix({1,1,0,1,true});muted.trigger({EQUIPMENT,GENERIC,20,0,1,0,METAL_CLINK});Stats mute;
        for(int i=0;i<int(hz*.5f);++i)mute.add(muted.next());check(mute.peak==0,"Equipment category gain silences modal contacts");
        check(!muted.trigger({IMPACT,ROCK,0})&&!muted.trigger({EQUIPMENT,GENERIC,std::numeric_limits<float>::quiet_NaN()}),"Zero/invalid impact speed cannot create a strike");
        DSP modal_pool(hz);modal_pool.set_mix({1,1,1,1,true});for(int i=0;i<8;++i)modal_pool.trigger({EQUIPMENT,GENERIC,35,0,1,0,METAL_CLINK});
        check(modal_pool.active_voices()==8&&!modal_pool.trigger({EQUIPMENT,GENERIC,35,0,1,0,METAL_CLINK}),"Metallic voices obey the eight-slot budget");
        check(modal_pool.trigger({IMPACT,ROCK,35})&&modal_pool.active_voices()==8,"A collision takes priority over a ringing fitting");
        modal_pool.release();modal_pool.set_mix({1,1,1,1,false});for(int i=0;i<int(hz*.5f);++i)modal_pool.next();
        check(std::abs(modal_pool.next().left)<1e-8,"Release fades modal histories and pending rattle bursts");
    }
    Queue<64> queue;for(int i=0;i<64;++i)queue.push({IMPACT,SNOW,float(i)});check(!queue.push({})&&queue.dropped.load()==1,"64-slot queue rejects overflow");
    Event e;bool ordered=true;for(int i=0;i<64;++i){ordered&=queue.pop(e)&&e.speed==float(i);}check(ordered&&!queue.pop(e),"Queue preserves event order and wraps safely");
    Queue<64> threaded;std::atomic<bool> correct{true};
    std::thread producer([&]{for(int i=0;i<30000;++i){Event event;event.speed=float(i);while(!threaded.push(event))std::this_thread::yield();}});
    for(int i=0;i<30000;++i){while(!threaded.pop(e))std::this_thread::yield();if(e.speed!=float(i))correct.store(false);}producer.join();check(correct.load(),"Concurrent producer/consumer never expose partial events");
    DSP timed;alpine_wind::DSP wind;timed.set_mix({1,1,1,1,true});timed.set_ski(0,ski(15));timed.set_ski(1,ski(15));timed.set_slide({50,1,0,ROCK,2});wind.set_controls({0,0,-65,0,1,1,true});
    std::vector<double> timings;volatile float sink=0;
    for(int block=0;block<1500;++block){auto start=std::chrono::steady_clock::now();timed.set_ski(0,ski(15));timed.set_ski(1,ski(15));timed.set_slide({50,1,0,ROCK,2});wind.set_controls({0,0,-65,0,1,1,true});if(block%5==0)for(int i=0;i<8;++i)timed.trigger({IMPACT,ROCK,20,0,1});for(int i=0;i<512;++i){auto a=timed.next(),b=wind.next();sink=a.left+b.left;}auto ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();if(block>100)timings.push_back(ms);}
    // Include eight simultaneously ringing metal fittings as well as hard hits.
    DSP metallic;metallic.set_mix({1,1,1,1,true});metallic.set_ski(0,ski(15));metallic.set_ski(1,ski(15));
    for(int block=0;block<1000;++block){auto start=std::chrono::steady_clock::now();if(block%24==0)for(int i=0;i<8;++i)metallic.trigger({EQUIPMENT,GENERIC,25,0,1,0,METAL_CLINK});for(int i=0;i<512;++i){auto a=metallic.next(),b=wind.next();sink=a.left+b.left;}auto ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();if(block>100)timings.push_back(ms);}
    std::sort(timings.begin(),timings.end());double p99=timings[size_t((timings.size()-1)*.99)];check(p99<=.5,"Combined worst-case wind and SFX p99 <= 0.5 ms / 512 frames");
    if(argc>1){
        auto out=std::filesystem::path(argv[1]);std::filesystem::create_directories(out);
        std::vector<std::string> names={"glide","carve","skid","powder","deep_powder","packed","wind_packed","ice","groomed","rock_scrape","landings","snow_crash","rock_crash","tree_crash","body_slide","equipment","near_misses","combined"};
        for(size_t scene=0;scene<names.size();++scene){DSP d;alpine_wind::DSP audition_wind;audition_wind.set_controls({0,0,-32,0,.3f,1,true});d.set_mix({1,1,1,1,true});std::vector<Frame> frames;for(int i=0;i<48000*4;++i){float t=float(i)/48000;auto c=ski();c.edge=scene==0?0:.7f;c.lateral=scene>=2?9:0;if(scene>=3&&scene<=8){int ids[]={0,1,2,3,4,5};c.condition=ids[scene-3];c.depth=scene==4?.3f:.08f;c.penetration=c.depth*.6f;}if(scene==9)c.material=ROCK;c.supported=t<3.5f&&scene<10;d.set_ski(0,c);d.set_ski(1,c);if(scene==14)d.set_slide({25,t<3.5f?1.0f:0.0f,0,SNOW,0});if(i%48000==12000&&scene>=10&&scene!=14){int kind=scene==10?LANDING:scene==15?EQUIPMENT:scene==16?NEAR_MISS:IMPACT;int material=scene==12?ROCK:scene==13?WOOD:SNOW;d.trigger({kind,material,4+t*3,(int(t)%2==0?-.65f:.65f),.8f});}if(scene==17){d.set_ski(0,ski(8,0));d.set_ski(1,ski(3,2));if(t>2.5f)d.set_slide({15,1,.3f,SNOW,0});if(i==36000)d.trigger({NEAR_MISS,WOOD,32,.8f,.8f});if(i%24000==0)d.trigger({EQUIPMENT,GENERIC,5,-.2f,.5f});}auto frame=d.next();if(scene==17){auto w=audition_wind.next();frame.left+=w.left;frame.right+=w.right;}frames.push_back(frame);}wav(out/(names[scene]+".wav"),frames,48000);}
        equipment_auditions(out);
        std::ofstream report(out/"dsp.json");report<<"{\"checks\":"<<checks<<",\"failures\":"<<failures<<",\"combined_p99_512_ms\":"<<p99<<",\"auditions\":"<<names.size()+5<<"}";
    }
    std::cout<<"SFX_DSP_RESULT checks="<<checks<<" failures="<<failures<<" combined_p99_512_ms="<<p99<<'\n';return failures?1:0;
}
