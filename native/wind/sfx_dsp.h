#pragma once
#include "wind_dsp.h"
#include <array>
#include <atomic>

// Audio-only units and random state. No Godot, clocks, heap or simulation access.
namespace alpine_sfx {
using alpine_wind::bounded;
using alpine_wind::Noise;
using alpine_wind::Pole;
using alpine_wind::Frame;
constexpr float PI = 3.14159265359f;
enum Material { SNOW, ROCK, WOOD, GENERIC };
enum EventKind { LANDING, IMPACT, EQUIPMENT, NEAR_MISS };
enum EquipmentProfile { BINDING_RATTLE, SHAFT_TICK, METAL_CLINK, MIXED_KNOCK };
struct Ski {
    float forward = 0, lateral = 0, edge = 0, load = 0, depth = 0, penetration = 0;
    int condition = 2, material = SNOW;
    bool supported = false;
};
struct Slide { float speed = 0, intensity = 0, pan = 0; int material = SNOW, condition = 2; };
struct Mix { float snow = 1, impacts = 1, equipment = 1, near_miss = 1; bool enabled = false; };
struct Event {
    int kind = IMPACT, material = SNOW;
    float speed = 0, pan = 0, detail = 0;
    uint64_t generation = 0;
    int equipment_profile = BINDING_RATTLE;
};
// Exactly one producer and one consumer. Reset invalidates by generation, never
// writes the consumer cursor from the main thread or races slot reuse.
template<size_t Capacity> struct Queue {
    std::array<Event, Capacity> events{};
    std::atomic<uint64_t> write{0}, read{0}, dropped{0};
    bool push(Event event) {
        auto w = write.load(std::memory_order_relaxed);
        if (w - read.load(std::memory_order_acquire) >= Capacity) { dropped.fetch_add(1); return false; }
        events[w % Capacity] = event;
        write.store(w + 1, std::memory_order_release); return true;
    }
    bool pop(Event& event) {
        auto r = read.load(std::memory_order_relaxed);
        if (r == write.load(std::memory_order_acquire)) return false;
        event = events[r % Capacity]; read.store(r + 1, std::memory_order_release); return true;
    }
};

class DSP {
    // Damped, inharmonic equipment modes. Coefficients are set once per strike;
    // no per-sample trig, heap, or continuous excitation of a musical note.
    struct Resonance {
        float x=0,y=0,c=0,s=0,initial=0;
        void excite(float hz,float t60,float amplitude,float rate) {
            float w=2*PI*std::min(hz,rate*.4f)/rate;
            float r=std::exp(-6.907755f/(t60*rate));
            c=r*std::cos(w);s=r*std::sin(w);initial=amplitude;x=amplitude;y=0;
        }
        void strike(float scale) { x+=initial*scale; }
        float next() {
            float nx=c*x-s*y;y=s*x+c*y;x=nx;
            return y;
        }
    };
    struct SurfaceVoice {
        Noise noise;
        Pole low, high, grain_filter;
        float amplitude = 0, target = 0, cutoff = 0, target_cutoff = 0, grain = 0, grain_decay = 0;
        float grain_rate = 0, grain_amount = 0, pan = 0;
        explicit SurfaceVoice(uint32_t seed = 1) : noise(seed) {}
    };
    struct Transient {
        Noise noise{1};
        Pole low;
        float age = 0, duration = 0, amplitude = 0, pan = 0, phase = 0;
        float frequency = 0, filter = 0, tonal = 0, noise_gain = 0;
        float last_output = 0, tail = 0, tail_pan = 0;
        int kind = IMPACT;
        int priority = 0;
        bool natural = false;
        Pole body_low,body_high,knock_low,knock_high,texture_low,texture_high;
        float body_lo=0,body_hi=0,knock_lo=0,knock_hi=0,texture_lo=0,texture_hi=0;
        float body_env=1,knock_env=1,texture_env=1;
        float body_decay=0,knock_decay=0,texture_decay=0;
        float body_gain=0,knock_gain=0,texture_gain=0,attack=.001f;
        std::array<Resonance,8> modes{};
        int mode_count=0,rattle_count=0,rattle_index=0;
        std::array<float,3> rattle_times{};
        float rattle_scale=1;
    };
    float rate, smooth, dc_coefficient, steal_decay, gate = 0;
    Mix mix;
    float snow_gain=0,impact_gain=0,equipment_gain=0,near_gain=0;
    std::array<SurfaceVoice, 3> surfaces;
    std::array<Transient, 8> voices{};
    Noise rng;
    Pole dc_left, dc_right;
    uint64_t dropped = 0, started = 0;
    float coefficient(float hz) const { return 1 - std::exp(-2 * PI * std::min(hz, rate * .4f) / rate); }
    static void pan_add(Frame& f, float v, float pan) {
        // A shared centre and restrained width preserve mono energy.
        f.left += v * (.70710678f - .24f * pan);
        f.right += v * (.70710678f + .24f * pan);
    }
public:
    static constexpr float CEILING = .5011872336f;
    explicit DSP(float hz = 48000, uint32_t seed = 571)
        : rate(bounded(hz, 8000, 192000)),
          surfaces{SurfaceVoice(seed), SurfaceVoice(seed ^ 0x475bac71), SurfaceVoice(seed ^ 0x1abc8741)}, rng(seed ^ 0xdef741) {
        smooth = coefficient(9);
        dc_coefficient = coefficient(12);
        steal_decay=std::exp(-1.0f/(rate*.0015f));
        for (auto& s : surfaces) s.grain_decay = std::exp(-1.0f / (.007f * rate));
    }
    void set_mix(Mix value) {
        value.snow = bounded(value.snow,0,1); value.impacts = bounded(value.impacts,0,1);
        value.equipment = bounded(value.equipment,0,1); value.near_miss = bounded(value.near_miss,0,1);
        mix = value;
    }
    void set_ski(int index, Ski c) {
        if (index < 0 || index > 1) return;
        auto& s = surfaces[index];
        float forward = bounded(std::abs(c.forward),0,150), lateral = bounded(std::abs(c.lateral),0,100);
        float speed = std::sqrt(forward*forward + lateral*lateral);
        float moving = std::clamp((speed-.12f)/1.5f,0.0f,1.0f);
        float pressure = 1 - std::exp(-bounded(c.load,0,5000)/400);
        float carve = std::abs(std::sin(bounded(c.edge,-PI,PI))) * (1-std::exp(-speed/16));
        float skid = 1-std::exp(-lateral/5);
        float depth = bounded(c.depth,0,.6f), penetration = bounded(c.penetration,0,depth);
        int condition = std::clamp(c.condition,0,5);
        constexpr float softness[] = {1,1.2f,.12f,.35f,.02f,.20f};
        constexpr float brightness[] = {1500,1000,3300,2900,4900,2600};
        bool rock = c.material == ROCK;
        float loose = softness[condition] * std::sqrt(depth/.18f);
        s.target = (c.supported ? 1.0f : 0.0f)*moving*pressure*
            (.023f*(1-std::exp(-speed/15)) + .043f*carve + .12f*skid + .05f*loose*(.15f+skid+penetration/.3f));
        if (rock) s.target = (c.supported ? 1.0f : 0.0f)*moving*pressure*(.04f+.11f*skid+.04f*carve);
        s.target_cutoff = coefficient(rock ? 5700 : brightness[condition]+1400*skid+600*carve);
        s.grain_rate = (rock ? 160 : 35+210*loose+100*skid) / rate;
        s.grain_amount = rock ? .8f : .15f+loose*.8f+skid*.4f;
        s.pan = index == 0 ? -.32f : .32f;
    }
    void set_slide(Slide c) {
        auto& s = surfaces[2];
        float speed = bounded(c.speed,0,150), intensity = bounded(c.intensity,0,1);
        s.target = intensity*std::clamp((speed-.15f)/2,0.0f,1.0f)*(.025f+.12f*(1-std::exp(-speed/18)));
        bool soft = c.material == SNOW;
        s.target_cutoff = coefficient(soft ? (c.condition <= 1 ? 1200 : 2400) : 4700);
        s.grain_rate = (soft ? 170.0f : 90.0f)/rate;
        s.grain_amount = soft ? .8f : 1.2f;
        s.pan = bounded(c.pan,-1,1);
    }
    bool trigger(Event e) {
        if (!mix.enabled || e.kind < LANDING || e.kind > NEAR_MISS) return false;
        e.speed = bounded(e.speed,0,150); e.pan = bounded(e.pan,-1,1); e.detail = bounded(e.detail,0,1);
        if(e.speed<=0) return false;
        e.equipment_profile=std::clamp(e.equipment_profile,int(BINDING_RATTLE),int(MIXED_KNOCK));
        int priority = e.kind <= IMPACT ? 3 : (e.kind == EQUIPMENT ? 1 : 0);
        Transient* chosen = nullptr;
        for (auto& v : voices) if (v.age >= v.duration) { chosen=&v; break; }
        if (!chosen) {
            for (auto& v : voices) {
                if (v.priority >= priority) continue;
                if (!chosen || v.amplitude*(1-v.age/v.duration) < chosen->amplitude*(1-chosen->age/chosen->duration)) chosen=&v;
            }
        }
        if (!chosen) { ++dropped; return false; }
        auto& v = *chosen;
        float tail=v.age<v.duration ? v.last_output : 0,tail_pan=v.pan;
        v = Transient{}; v.noise.state = uint32_t((rng.next()+1)*2000000000.0f)+1;
        v.tail=tail;v.tail_pan=tail_pan;
        v.kind = e.kind; v.priority = priority; v.pan = e.pan;
        float severity = 1-std::exp(-e.speed/(e.kind==NEAR_MISS ? 30.0f : 7.0f));
        float variation = 1 + .14f*rng.next();
        if (e.kind == NEAR_MISS) {
            v.duration = .16f+.12f*e.detail; v.amplitude = .12f*severity*(.3f+.7f*e.detail);
            v.frequency=0; v.filter=coefficient(e.material==WOOD ? 2100 : 1300); v.noise_gain=2; v.tonal=0;
        } else if (e.kind == EQUIPMENT) {
            v.natural=true;
            bool metal=e.equipment_profile==METAL_CLINK;
            bool shaft=e.equipment_profile==SHAFT_TICK;
            bool rattle=e.equipment_profile==BINDING_RATTLE;
            v.duration=metal ? .26f : rattle ? .43f : .18f;
            v.amplitude=(metal ? .070f : shaft ? .060f : rattle ? .055f : .075f)*(1-std::exp(-e.speed/3.5f));
            v.body_lo=coefficient(shaft ? 850 : 500);v.body_hi=coefficient(180);
            v.knock_lo=coefficient((shaft ? 4100 : 6900)*( .7f+.3f*severity));v.knock_hi=coefficient(shaft ? 650 : 1700);
            v.texture_lo=coefficient(4200);v.texture_hi=coefficient(1300);
            // Metal is carried by ringing modes, with only a tiny contact tick.
            // A broad noise burst here reads as a snare brush rather than metal.
            v.body_gain=metal || rattle ? .12f : shaft ? 1.3f : .7f;
            v.knock_gain=metal || rattle ? .20f : 1.2f;v.texture_gain=metal || rattle ? 0.0f : .035f;
            v.body_decay=std::exp(-1/(rate*.006f));v.knock_decay=std::exp(-1/(rate*.0025f));v.texture_decay=std::exp(-1/(rate*.009f));
            if(metal || rattle) v.knock_decay=std::exp(-1/(rate*.0008f));
            v.attack=.0007f;
            if(metal || rattle || e.equipment_profile==MIXED_KNOCK) {
                // Guided by spectral/envelope measurements of the user's small
                // carabiner reference. Only scalar resonances, never sampled PCM.
                constexpr float frequencies[]={5840,6730,7125,8320,10220,11344,13406,14438};
                constexpr float weights[]={.162f,.079f,.115f,.077f,.144f,.202f,.093f,.128f};
                constexpr float decays[]={.199f,.175f,.119f,.165f,.125f,.160f,.169f,.104f};
                v.mode_count=8;
                for(int i=0;i<8;++i) {
                    float hz=frequencies[i]*(1+.012f*rng.next());
                    float decay=decays[i]*(metal ? 1.0f : rattle ? .7f : .45f)*(1+.16f*rng.next());
                    v.modes[i].excite(hz,decay,weights[i]*(metal ? 1.5f : rattle ? 1.0f : .55f)*(1+.2f*rng.next()),rate);
                }
            }
            if(rattle) {
                v.rattle_count=2+(e.detail>.65f ? 1 : 0);
                float when=0;
                for(int i=0;i<v.rattle_count;++i) { when+=.035f+.035f*(rng.next()+1)*.5f;v.rattle_times[i]=when; }
            }
        } else if(e.material!=SNOW) {
            // A clothed rider/equipment striking an intact object: broadband
            // compression, a short knock, then contact grit/bark. No oscillator.
            v.natural=true;
            bool wood=e.material==WOOD;
            v.duration=.22f+.08f*severity;v.amplitude=(e.kind==LANDING ? .30f : .42f)*severity;
            v.body_lo=coefficient((wood ? 260 : 340)*variation);v.body_hi=coefficient(48);
            v.knock_lo=coefficient((wood ? 1900 : 4700)*(.65f+.35f*severity)*variation);
            v.knock_hi=coefficient(wood ? 330 : 740);
            v.texture_lo=coefficient(wood ? 2400 : 6600);v.texture_hi=coefficient(wood ? 550 : 1500);
            v.body_gain=wood ? 5.0f : 4.3f;v.knock_gain=wood ? 1.5f : 1.25f;v.texture_gain=wood ? .37f : .45f;
            v.body_decay=std::exp(-1/(rate*(wood ? .030f : .022f)*variation));
            v.knock_decay=std::exp(-1/(rate*(wood ? .010f : .006f)*variation));
            v.texture_decay=std::exp(-1/(rate*(.025f+.025f*severity)*variation));
            v.attack=.0015f;
        } else {
            bool soft = e.material==SNOW;
            v.duration=(soft ? .27f : .16f)+.12f*severity;
            v.amplitude=(e.kind==LANDING ? .25f : .34f)*severity;
            v.frequency=(soft ? 75.0f : e.material==WOOD ? 145.0f : 240.0f)*variation;
            v.filter=coefficient(soft ? 1200 : e.material==WOOD ? 2600 : 5500);
            v.noise_gain=soft ? 1.0f : 1.7f; v.tonal=soft ? .55f : .25f;
        }
        ++started; return true;
    }
    // Keep filter histories through reset so lifecycle fades remain continuous.
    void release() {
        for (auto& s : surfaces) s.target=0;
        for (auto& v : voices) v.duration=std::min(v.duration,v.age+.012f);
    }
    Frame next() {
        Frame f{};
        gate += smooth*((mix.enabled ? 1.0f : 0.0f)-gate);
        if(gate<1e-20f)gate=0;
        snow_gain+=smooth*(mix.snow-snow_gain);impact_gain+=smooth*(mix.impacts-impact_gain);
        equipment_gain+=smooth*(mix.equipment-equipment_gain);near_gain+=smooth*(mix.near_miss-near_gain);
        for (auto& s : surfaces) {
            s.amplitude += smooth*(s.target-s.amplitude);
            if(s.amplitude<1e-20f)s.amplitude=0;
            s.cutoff+=smooth*(s.target_cutoff-s.cutoff);
            float noise=s.noise.next();
            if (s.noise.next() > 1-2*s.grain_rate) s.grain += s.noise.next();
            s.grain *= s.grain_decay;
            float sample=s.low.tick(noise,s.cutoff);
            sample -= s.high.tick(sample,dc_coefficient*4);
            sample += s.grain_filter.tick(s.grain,s.cutoff)*s.grain_amount*.32f;
            pan_add(f,sample*s.amplitude*snow_gain,s.pan);
        }
        for (auto& v : voices) {
            if (v.age >= v.duration) continue;
            float age=v.age/std::max(.001f,v.duration);
            float gain=v.kind==NEAR_MISS ? near_gain : v.kind==EQUIPMENT ? equipment_gain : impact_gain;
            if(v.natural) {
                if(v.rattle_index<v.rattle_count && v.age>=v.rattle_times[v.rattle_index]) {
                    ++v.rattle_index;v.rattle_scale*=.62f+.16f*(v.noise.next()+1)*.5f;
                    v.body_env=v.rattle_scale;v.knock_env=v.rattle_scale;v.texture_env=v.rattle_scale;
                    for(int i=0;i<v.mode_count;++i)v.modes[i].strike(v.rattle_scale);
                }
                float white=v.noise.next();
                float body=v.body_low.tick(white,v.body_lo);body-=v.body_high.tick(body,v.body_hi);
                float knock=v.knock_low.tick(white,v.knock_lo);knock-=v.knock_high.tick(knock,v.knock_hi);
                float texture=v.texture_low.tick(v.noise.next(),v.texture_lo);texture-=v.texture_high.tick(texture,v.texture_hi);
                float modal=0;for(int i=0;i<v.mode_count;++i)modal+=v.modes[i].next();
                float sample=body*v.body_gain*v.body_env+knock*v.knock_gain*v.knock_env+texture*v.texture_gain*v.texture_env+modal;
                // An explicit final fade also makes release()/voice stealing safe.
                float envelope=std::min(v.age/v.attack,1.0f)*std::min((v.duration-v.age)/.012f,1.0f);
                v.last_output=sample*envelope*v.amplitude*gain;
                v.body_env*=v.body_decay;v.knock_env*=v.knock_decay;v.texture_env*=v.texture_decay;
            } else {
                float envelope = v.kind==NEAR_MISS ? std::sin(PI*age) : std::min(v.age/.003f,1.0f)*std::exp(-6*age)*(1-age);
                float noise=v.low.tick(v.noise.next(),v.filter);
                float modal=std::sin(v.phase)+.22f*std::sin(v.phase*2.37f);
                v.phase += 2*PI*v.frequency/rate;
                v.last_output=(noise*v.noise_gain+modal*v.tonal)*envelope*v.amplitude*gain;
            }
            pan_add(f,v.last_output,v.pan);
            pan_add(f,v.tail,v.tail_pan);v.tail*=steal_decay;
            v.age += 1/rate;
        }
        f.left *= gate; f.right *= gate;
        f.left -= dc_left.tick(f.left,dc_coefficient); f.right -= dc_right.tick(f.right,dc_coefficient);
        f.left=CEILING*std::tanh(f.left/CEILING); f.right=CEILING*std::tanh(f.right/CEILING);
        return f;
    }
    uint64_t dropped_voices() const { return dropped; }
    uint64_t started_events() const { return started; }
    int active_voices() const { int n=0; for (const auto& v:voices) n+=v.age<v.duration; return n; }
};
}
