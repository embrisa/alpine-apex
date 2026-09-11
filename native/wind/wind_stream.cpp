#include "wind_dsp.h"
#include <godot_cpp/classes/audio_stream.hpp>
#include <godot_cpp/classes/audio_stream_playback.hpp>
#include <godot_cpp/classes/audio_server.hpp>
#include <godot_cpp/classes/audio_frame.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <array>
#include <atomic>
#include <chrono>
#include <vector>

using namespace godot;
using alpine_wind::Controls;
static_assert(std::atomic<float>::is_always_lock_free);
static_assert(std::atomic<uint64_t>::is_always_lock_free);

// Independent atomic scalars: bounded handoff; sample smoothing tolerates an
// adjacent-frame field during a simultaneous publish. No audio-thread retries.
struct WindMailbox {
    std::atomic<float> x{0}, y{0}, z{0}, tuck{0}, gust{0}, gain{1};
    std::atomic<bool> enabled{false};
    Controls read() const {
        return {x.load(), y.load(), z.load(), tuck.load(), gust.load(), gain.load(), enabled.load()};
    }
    void write(Vector3 air, float t, float g, float volume, bool on) {
        x.store(air.x); y.store(air.y); z.store(air.z);
        tuck.store(t); gust.store(g); gain.store(volume); enabled.store(on);
    }
};

class AlpineWindStream;
class AlpineWindPlayback : public AudioStreamPlayback {
    GDCLASS(AlpineWindPlayback, AudioStreamPlayback)
    alpine_wind::DSP dsp;
    Ref<AlpineWindStream> owner;
    std::atomic<bool> playing{false};
    std::atomic<uint64_t> position_frames{0};
    float sample_rate = 48000;
protected:
    static void _bind_methods() {}
public:
    void configure(const Ref<AlpineWindStream>& stream, float rate, uint32_t seed);
    void _start(double /*from_pos*/ = 0) override { position_frames.store(0); playing.store(true); }
    void _stop() override { playing.store(false); }
    bool _is_playing() const override { return playing.load(); }
    double _get_playback_position() const override { return double(position_frames.load()) / sample_rate; }
    int32_t _get_loop_count() const override { return 0; }
    int32_t _mix(AudioFrame* buffer, float rate_scale, int32_t frames) override;
};

class AlpineWindStream : public AudioStream {
    GDCLASS(AlpineWindStream, AudioStream)
    mutable std::atomic<uint32_t> next_seed{0xabc67123};
    std::array<std::atomic<uint32_t>, 8192> timings{};
    std::atomic<uint64_t> blocks{0}, frames_mixed{0};
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("set_controls", "air_m_s", "tuck", "gust", "gain", "enabled"), &AlpineWindStream::set_controls);
        ClassDB::bind_method(D_METHOD("diagnostics"), &AlpineWindStream::diagnostics);
    }
public:
    WindMailbox mailbox;
    void set_controls(Vector3 air, double tuck, double gust, double gain, bool enabled) {
        mailbox.write(air, float(tuck), float(gust), float(gain), enabled);
    }
    Ref<AudioStreamPlayback> _instantiate_playback() const override {
        Ref<AlpineWindPlayback> playback;
        playback.instantiate();
        playback->configure(Ref<AlpineWindStream>(const_cast<AlpineWindStream*>(this)),
            float(AudioServer::get_singleton()->get_mix_rate()), next_seed.fetch_add(0x9e3779b9));
        return playback;
    }
    String _get_stream_name() const override { return "Alpine procedural wind"; }
    double _get_length() const override { return 0; }
    bool _is_monophonic() const override { return false; }
    void measured(uint64_t ns, int32_t frames) {
        // Normalize to 512 frames, so callback block-size differences compare fairly.
        auto n = blocks.load();
        timings[n % timings.size()].store(uint32_t(std::min<uint64_t>(ns * 512 / std::max(1, frames), UINT32_MAX)));
        frames_mixed.fetch_add(frames); blocks.store(n + 1);
    }
    Dictionary diagnostics() const {
        const auto n = blocks.load();
        std::vector<uint32_t> values;
        for (size_t i = 0; i < std::min<uint64_t>(n, timings.size()); ++i) values.push_back(timings[i].load());
        std::sort(values.begin(), values.end());
        Dictionary result;
        result["blocks"] = int64_t(n); result["frames"] = int64_t(frames_mixed.load());
        result["p99_512_ms"] = values.empty() ? 0.0 : double(values[size_t((values.size()-1)*.99)]) / 1e6;
        result["max_512_ms"] = values.empty() ? 0.0 : double(values.back()) / 1e6;
        result["history_blocks"] = int64_t(values.size());
        return result;
    }
};

void AlpineWindPlayback::configure(const Ref<AlpineWindStream>& stream, float rate, uint32_t seed) {
    owner = stream; sample_rate = rate; dsp = alpine_wind::DSP(rate, seed);
}
int32_t AlpineWindPlayback::_mix(AudioFrame* buffer, float /*rate_scale*/, int32_t frames) {
    if (!playing.load()) {
        for (int32_t i = 0; i < frames; ++i) buffer[i] = AudioFrame{0, 0};
        return 0;
    }
    const auto begin = std::chrono::steady_clock::now();
    dsp.set_controls(owner->mailbox.read());
    for (int32_t i = 0; i < frames; ++i) {
        const auto frame = dsp.next(); buffer[i] = AudioFrame{frame.left, frame.right};
    }
    position_frames.fetch_add(frames);
    owner->measured(std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now() - begin).count(), frames);
    return frames;
}

void register_sfx_types();
void initialize_wind(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    ClassDB::register_class<AlpineWindStream>(); ClassDB::register_class<AlpineWindPlayback>();
    register_sfx_types();
}
void uninitialize_wind(ModuleInitializationLevel) {}
extern "C" {
GDExtensionBool GDE_EXPORT alpine_wind_init(GDExtensionInterfaceGetProcAddress get_proc,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization* initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize_wind); init.register_terminator(uninitialize_wind);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
