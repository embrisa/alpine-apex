#include "sfx_dsp.h"
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector4.hpp>
#include <chrono>
#include <vector>
using namespace godot;
namespace sfx = alpine_sfx;
static_assert(std::atomic<float>::is_always_lock_free);
static_assert(std::atomic<uint64_t>::is_always_lock_free);
struct AtomicSki {
    std::atomic<float> forward{0}, lateral{0}, edge{0}, load{0}, depth{0}, penetration{0};
    std::atomic<int> condition{2}, material{0}; std::atomic<bool> supported{false};
    sfx::Ski read() const { return {forward.load(),lateral.load(),edge.load(),load.load(),depth.load(),penetration.load(),condition.load(),material.load(),supported.load()}; }
};
class AlpineSfxStream;
class AlpineSfxPlayback : public AudioStreamPlayback {
    GDCLASS(AlpineSfxPlayback,AudioStreamPlayback)
    Ref<AlpineSfxStream> owner;
    sfx::DSP dsp;
    std::atomic<bool> playing{false};
    std::atomic<uint64_t> position{0};
    uint64_t generation=0;
    float rate=48000;
protected:
    static void _bind_methods() {}
public:
    void configure(const Ref<AlpineSfxStream>& stream,float hz,uint32_t seed);
    void _start(double =0) override;
    void _stop() override;
    ~AlpineSfxPlayback() override { _stop(); }
    bool _is_playing() const override { return playing.load(); }
    double _get_playback_position() const override { return double(position.load())/rate; }
    int32_t _get_loop_count() const override { return 0; }
    int32_t _mix(AudioFrame* buffer,float,int32_t frames) override;
};
class AlpineSfxStream : public AudioStream {
    GDCLASS(AlpineSfxStream,AudioStream)
    mutable std::atomic<uint32_t> seed{819571};
    std::array<std::atomic<uint32_t>,8192> timings{};
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("set_ski_controls","index","forward_m_s","lateral_m_s","edge_radians","load_n","depth_m","penetration_m","condition","material","supported"),&AlpineSfxStream::set_ski_controls);
        ClassDB::bind_method(D_METHOD("set_slide_controls","speed_m_s","intensity","pan","material","condition"),&AlpineSfxStream::set_slide_controls);
        ClassDB::bind_method(D_METHOD("set_mix","gains","enabled"),&AlpineSfxStream::set_mix);
        ClassDB::bind_method(D_METHOD("push_event","kind","material","speed_m_s","pan","detail"),&AlpineSfxStream::push_event);
        ClassDB::bind_method(D_METHOD("push_equipment_event","profile","speed_m_s","pan","detail"),&AlpineSfxStream::push_equipment_event);
        ClassDB::bind_method(D_METHOD("reset"),&AlpineSfxStream::reset);
        ClassDB::bind_method(D_METHOD("diagnostics"),&AlpineSfxStream::diagnostics);
    }
public:
    AtomicSki skis[2];
    std::atomic<float> slide_speed{0},slide_intensity{0},slide_pan{0};
    std::atomic<int> slide_material{0},slide_condition{2};
    std::atomic<float> snow{1},impacts{1},equipment{1},near_miss{1};
    std::atomic<bool> enabled{false},claimed{false};
    std::atomic<uint64_t> epoch{0},blocks{0},frames_mixed{0},voice_drops{0},events_started{0},rejected_playbacks{0};
    std::atomic<int> voices{0};
    sfx::Queue<64> queue;
    void set_ski_controls(int index,double f,double l,double e,double n,double d,double p,int c,int m,bool supported) {
        if (index<0 || index>1) return;
        auto& s=skis[index]; s.forward.store(float(f));s.lateral.store(float(l));s.edge.store(float(e));s.load.store(float(n));s.depth.store(float(d));s.penetration.store(float(p));s.condition.store(c);s.material.store(m);s.supported.store(supported);
    }
    void set_slide_controls(double speed,double intensity,double pan,int material,int condition) {
        slide_speed.store(float(speed));slide_intensity.store(float(intensity));slide_pan.store(float(pan));slide_material.store(material);slide_condition.store(condition);
    }
    void set_mix(Vector4 gains,bool on) { snow.store(gains.x);impacts.store(gains.y);equipment.store(gains.z);near_miss.store(gains.w);enabled.store(on); }
    bool push_event(int kind,int material,double speed,double pan,double detail) {
        if (!enabled.load()) return false;
        return queue.push({kind,material,float(speed),float(pan),float(detail),epoch.load()});
    }
    bool push_equipment_event(int profile,double speed,double pan,double detail) {
        if(!enabled.load() || profile<sfx::BINDING_RATTLE || profile>sfx::MIXED_KNOCK) return false;
        return queue.push({sfx::EQUIPMENT,sfx::GENERIC,float(speed),float(pan),float(detail),epoch.load(),profile});
    }
    void reset() { enabled.store(false);for (auto& s:skis) s.supported.store(false);slide_intensity.store(0);epoch.fetch_add(1); }
    Ref<AudioStreamPlayback> _instantiate_playback() const override {
        Ref<AlpineSfxPlayback> p; p.instantiate();
        p->configure(Ref<AlpineSfxStream>(const_cast<AlpineSfxStream*>(this)),float(AudioServer::get_singleton()->get_mix_rate()),seed.fetch_add(0x9e3779b9));return p;
    }
    String _get_stream_name() const override { return "Alpine procedural skiing and impacts"; }
    double _get_length() const override { return 0; }
    bool _is_monophonic() const override { return true; }
    void measured(uint64_t ns,int frames,const sfx::DSP& dsp) {
        auto n=blocks.load();timings[n%timings.size()].store(uint32_t(std::min<uint64_t>(ns*512/std::max(1,frames),UINT32_MAX)));
        frames_mixed.fetch_add(frames);blocks.store(n+1);voice_drops.store(dsp.dropped_voices());events_started.store(dsp.started_events());voices.store(dsp.active_voices());
    }
    Dictionary diagnostics() const {
        std::vector<uint32_t> t;auto n=blocks.load();
        for(size_t i=0;i<std::min<uint64_t>(n,timings.size());++i)t.push_back(timings[i].load());
        std::sort(t.begin(),t.end()); Dictionary d;
        d["blocks"]=int64_t(n);d["frames"]=int64_t(frames_mixed.load());
        d["p99_512_ms"]=t.empty()?0.0:double(t[size_t((t.size()-1)*.99)])/1e6;
        d["queue_dropped"]=int64_t(queue.dropped.load());d["voice_dropped"]=int64_t(voice_drops.load());
        d["events_started"]=int64_t(events_started.load());d["active_voices"]=voices.load();d["rejected_playbacks"]=int64_t(rejected_playbacks.load());return d;
    }
};
void AlpineSfxPlayback::configure(const Ref<AlpineSfxStream>& stream,float hz,uint32_t seed) { owner=stream;rate=hz;dsp=sfx::DSP(hz,seed); }
void AlpineSfxPlayback::_start(double) {
    if(playing.load())return;
    bool expected=false;
    if(!owner->claimed.compare_exchange_strong(expected,true)){owner->rejected_playbacks.fetch_add(1);return;}
    generation=owner->epoch.load();position.store(0);playing.store(true);
}
void AlpineSfxPlayback::_stop() { if(playing.exchange(false) && owner.is_valid())owner->claimed.store(false); }
int32_t AlpineSfxPlayback::_mix(AudioFrame* buffer,float,int32_t frames) {
    if(!playing.load()){for(int i=0;i<frames;++i)buffer[i]=AudioFrame{0,0};return 0;}
    auto begin=std::chrono::steady_clock::now();
    auto current=owner->epoch.load();if(current!=generation){dsp.release();generation=current;}
    dsp.set_mix({owner->snow.load(),owner->impacts.load(),owner->equipment.load(),owner->near_miss.load(),owner->enabled.load()});
    for(int i=0;i<2;++i)dsp.set_ski(i,owner->skis[i].read());
    dsp.set_slide({owner->slide_speed.load(),owner->slide_intensity.load(),owner->slide_pan.load(),owner->slide_material.load(),owner->slide_condition.load()});
    sfx::Event e;
    for(int i=0;i<64 && owner->queue.pop(e);++i){
        // A reset/re-enable can occur while this block drains. Adopt its epoch
        // before consuming a new event, rather than dropping the first impact.
        auto latest=owner->epoch.load();
        if(latest!=generation){
            dsp.release();generation=latest;
            dsp.set_mix({owner->snow.load(),owner->impacts.load(),owner->equipment.load(),owner->near_miss.load(),owner->enabled.load()});
        }
        if(e.generation==generation)dsp.trigger(e);
    }
    for(int i=0;i<frames;++i){auto f=dsp.next();buffer[i]=AudioFrame{f.left,f.right};}
    position.fetch_add(frames);owner->measured(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-begin).count(),frames,dsp);return frames;
}
void register_sfx_types() { ClassDB::register_class<AlpineSfxStream>();ClassDB::register_class<AlpineSfxPlayback>(); }
