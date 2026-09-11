#include "wind_dsp.h"
#include <chrono>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <limits>
#include <vector>
using namespace alpine_wind;
int failures = 0, checks = 0;
void check(bool ok, const char* label) {
    ++checks; if (!ok) ++failures;
    std::cout << (ok ? "PASS " : "FAIL ") << label << '\n';
}
struct Stats {
    double square = 0, sum = 0, left = 0, right = 0, difference = 0;
    float peak = 0; size_t count = 0;
    void add(Frame f, Frame previous) {
        if (!std::isfinite(f.left) || !std::isfinite(f.right)) { peak = 1e9; return; }
        square += (double(f.left)*f.left+double(f.right)*f.right)*.5;
        sum += (f.left+f.right)*.5; left += double(f.left)*f.left; right += double(f.right)*f.right;
        difference += (f.left-previous.left)*(f.left-previous.left);
        peak = std::max({peak, std::abs(f.left), std::abs(f.right)}); ++count;
    }
    double rms() const { return std::sqrt(square / std::max<size_t>(1, count)); }
};
Stats measure(float rate, Controls c, float seconds = 5) {
    DSP dsp(rate); dsp.set_controls(c); Frame prev{}; Stats stats;
    for (int i = 0; i < rate; ++i) prev = dsp.next();
    for (int i = 0; i < int(rate*seconds); ++i) { auto f = dsp.next(); stats.add(f, prev); prev = f; }
    return stats;
}
void little(std::ofstream& file, uint32_t v, int bytes) {
    for (int i = 0; i < bytes; ++i) file.put(char(v >> (8*i)));
}
void wav(const std::filesystem::path& path, const std::vector<Frame>& frames, uint32_t rate) {
    std::ofstream f(path, std::ios::binary); uint32_t bytes = uint32_t(frames.size()*4);
    f.write("RIFF",4); little(f,36+bytes,4); f.write("WAVEfmt ",8); little(f,16,4);
    little(f,1,2); little(f,2,2); little(f,rate,4); little(f,rate*4,4); little(f,4,2); little(f,16,2);
    f.write("data",4); little(f,bytes,4);
    for (auto frame : frames) { little(f,uint16_t(int16_t(frame.left*32767)),2); little(f,uint16_t(int16_t(frame.right*32767)),2); }
}
int main(int argc, char** argv) {
    std::vector<double> levels;
    for (float rate : {44100.0f,48000.0f}) {
        double previous = 0;
        for (float kmh : {0.0f,30.0f,90.0f,150.0f,200.0f,540.0f}) {
            auto s = measure(rate,{0,0,-kmh/3.6f,0,.5f,1,true});
            check(s.peak <= DSP::CEILING,"Output finite and bounded including extreme speed");
            check(std::abs(s.sum/s.count) < .0002,"DC offset below -74 dBFS");
            check(kmh == 0 ? s.rms()==0 : s.rms()>previous,"Airspeed increases level without imposing a physics speed cap");
            previous = s.rms();
            if (rate == 48000) levels.push_back(s.rms());
        }
        auto upright = measure(rate,{0,0,-25,0,0,1,true});
        auto tucked = measure(rate,{0,0,-25,1,0,1,true});
        check(tucked.rms()<upright.rms() && tucked.difference/tucked.square<upright.difference/upright.square,"Tuck reduces level and relative high-frequency energy");
        auto right = measure(rate,{-20,0,-25,0,0,1,true});
        auto left = measure(rate,{20,0,-25,0,0,1,true});
        check(right.right>right.left && left.left>left.right,"Crosswind emphasizes the windward ear");
        DSP dsp(rate); dsp.set_controls({0,0,-50,0,1,1,true});
        for (int i = 0; i < rate; ++i) dsp.next();
        dsp.set_controls({0,0,-50,0,1,1,false});
        for (int i = 0; i < rate*.5f; ++i) dsp.next();
        auto silent = dsp.next(); check(std::abs(silent.left)+std::abs(silent.right)<1e-7,"Mute settles to silence with continuous filter state");
        DSP a(rate,75), b(rate,75), independent(rate,89);
        Controls c{0,0,-25,.3f,.7f,.8f,true}; a.set_controls(c); b.set_controls(c); independent.set_controls(c);
        bool same=true, differs=false; std::vector<Frame> first;
        for (int i=0;i<4096;++i) first.push_back(a.next());
        for (int offset=0;offset<4096;offset+=128) {
            b.set_controls(c);
            for (int i=offset;i<offset+128;++i) { auto f=b.next(); auto other=independent.next(); same &= f.left==first[i].left && f.right==first[i].right; differs |= f.left!=other.left; }
        }
        check(same,"Block sizes and unchanged publications do not change the waveform");
        check(differs,"Separate playback seeds produce independent noise");
        DSP changed(rate,42); changed.set_controls(c);
        for(int i=0;i<int(rate);++i) changed.next();
        DSP steady = changed;
        changed.set_controls({150,150,150,1,1,0,false});
        auto transition = changed.next(), continuation = steady.next();
        check(std::abs(transition.left-continuation.left)<.0002f && std::abs(transition.right-continuation.right)<.0002f,
            "Abrupt airflow, tuck, gust and gate targets cannot make a sample discontinuity");
        a.set_controls({NAN,INFINITY,-INFINITY,NAN,NAN,NAN,true});
        bool finite=true;
        for(int i=0;i<10000;++i) { auto f=a.next(); finite &= std::isfinite(f.left)&&std::abs(f.left)<=DSP::CEILING; }
        check(finite,"Invalid controls cannot poison filter state");
    }
    DSP benchmark(48000); benchmark.set_controls({-8,2,-55,.5f,.8f,1,true});
    std::vector<double> durations; volatile float sink=0;
    for(int block=0;block<6000;++block) {
        auto begin=std::chrono::steady_clock::now();
        for(int i=0;i<512;++i) sink=benchmark.next().left;
        double elapsed=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();
        if(block>100) durations.push_back(elapsed);
    }
    std::sort(durations.begin(),durations.end()); double p99=durations[size_t(durations.size()*.99)];
    std::cout<<"DSP_P99_512_MS "<<p99<<'\n';
    check(p99<.25,"512 frames at 48 kHz below 0.25 ms p99 DSP budget");
    if(argc>1) {
        std::filesystem::path out(argv[1]); std::filesystem::create_directories(out);
        std::ofstream report(out/"dsp.json");
        report<<"{\"checks\":"<<checks<<",\"failures\":"<<failures<<",\"p99_512_ms\":"<<p99<<",\"rms_at_0_30_90_150_200_540_kmh\":[";
        for(size_t i=0;i<levels.size();++i) { if(i)report<<','; report<<levels[i]; } report<<"]}";
        for (int scenario=0;scenario<4;++scenario) {
            DSP dsp(48000,0xabc67123); std::vector<Frame> audio; audio.reserve(48000*24);
            for(int i=0;i<48000*24;++i) {
                float t=float(i)/48000; Controls c{0,0,-25,0,.4f,1,true};
                if(scenario==0) c.z=-(t<2?0:std::min(200.0f,(t-2)*10))/3.6f;
                if(scenario==1) {c.z=-150.0f/3.6f;c.tuck=t>6&&t<15?1.0f:0.0f;}
                if(scenario==2) {c.x=t<8?0:(t<16?-12:12);c.gust=.9f;}
                if(scenario==3) c.z=-(t<8?90.0f:(t<16?150.0f:200.0f))/3.6f;
                if(t>23.5f)c.enabled=false;
                if((i&63)==0)dsp.set_controls(c);
                audio.push_back(dsp.next());
            }
            const char* names[]={"speed_ramp.wav","tuck.wav","crosswind.wav","speed_steps.wav"};
            wav(out/names[scenario],audio,48000);
        }
    }
    std::cout<<"WIND_DSP_RESULT checks="<<checks<<" failures="<<failures<<'\n';
    return failures?1:0;
}
