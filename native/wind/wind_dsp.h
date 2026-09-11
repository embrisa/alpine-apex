#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>

namespace alpine_wind {
struct Controls {
    float x = 0, y = 0, z = 0; // Air velocity relative to head: right/up/forward, m/s.
    float tuck = 0, gust = 0, gain = 1;
    bool enabled = false;
};
struct Frame { float left, right; };
inline float bounded(float v, float lo, float hi) {
    return std::isfinite(v) ? std::clamp(v, lo, hi) : lo;
}
struct Noise {
    uint32_t state;
    explicit Noise(uint32_t seed = 1) : state(seed ? seed : 1) {}
    float next() {
        state ^= state << 13; state ^= state >> 17; state ^= state << 5;
        return float(state >> 8) * (2.0f / 16777216.0f) - 1.0f;
    }
};
struct Pole {
    float state = 0;
    float tick(float input, float coefficient) {
        state += coefficient * (input - state);
        // Avoid denormal slowdowns during very long periods of silence.
        if (std::abs(state) < 1e-20f) state = 0;
        return state;
    }
};
// Smooth random knots, not oscillators: the gust never repeats on a short cycle.
struct Wander {
    Noise rng;
    float from = 0, to = 0, phase = 0, increment = 0;
    explicit Wander(uint32_t seed) : rng(seed) {}
    float tick(float rate, float sample_rate) {
        if (phase >= 1 || increment == 0) {
            from = to; to = rng.next(); phase = 0;
            increment = rate * (0.65f + (rng.next() + 1) * 0.4f) / sample_rate;
        }
        float s = phase * phase * (3 - 2 * phase);
        phase += increment;
        return from + (to - from) * s;
    }
};

// No Godot dependency, heap allocation, global random state, or clock access.
class DSP {
    float sample_rate, smoothing, gate_smoothing;
    Controls target;
    float speed = 0, tuck = 0, gust = 0, side = 0, back = 0, gain = 0;
    Noise body_noise, left_noise, right_noise;
    Wander slow, flutter;
    Pole body_low, body_high, low_cut, rush_low, rush_high;
    Pole l_high, l_low, r_high, r_low, dc_l, dc_r;
    float c35, c160, c100, c1800, c6000, c_dc, rush_cut = 0;
    uint32_t control_count = 0;
    float coefficient(float hz) const { return 1 - std::exp(-6.28318530718f * hz / sample_rate); }
public:
    static constexpr float CEILING = 0.5011872336f; // -6 dBFS, including extremes.
    // Calibrated against assets/wind.wav at 90 km/h; see audio report.
    static constexpr float REFERENCE_GAIN = 0.0765f;
    explicit DSP(float hz = 48000, uint32_t seed = 0xabc67123)
        : sample_rate(bounded(hz, 8000, 192000)),
          body_noise(seed), left_noise(seed ^ 0x72de4831), right_noise(seed ^ 0xea3015b7),
          slow(seed ^ 0x4ab28d71), flutter(seed ^ 0x41f10bc3) {
        smoothing = 1 - std::exp(-1.0f / (sample_rate * 0.09f));
        gate_smoothing = 1 - std::exp(-1.0f / (sample_rate * 0.025f));
        c35 = coefficient(35); c160 = coefficient(180); c100 = coefficient(110);
        c1800 = coefficient(1800); c6000 = coefficient(std::min(6500.0f, sample_rate * .35f));
        c_dc = coefficient(12); rush_cut = coefficient(2200);
    }
    void set_controls(Controls controls) {
        controls.x = bounded(controls.x, -150, 150); controls.y = bounded(controls.y, -150, 150);
        controls.z = bounded(controls.z, -150, 150); controls.tuck = bounded(controls.tuck, 0, 1);
        controls.gust = bounded(controls.gust, 0, 1); controls.gain = bounded(controls.gain, 0, 1);
        target = controls;
    }
    Frame next() {
        float air = std::min(150.0f, std::sqrt(target.x*target.x + target.y*target.y + target.z*target.z));
        speed += smoothing * (air - speed);
        tuck += smoothing * (target.tuck - tuck); gust += smoothing * (target.gust - gust);
        // The windward ear is opposite the direction in which air travels.
        side += smoothing * ((air > .1f ? -target.x / air : 0) - side);
        back += smoothing * ((air > .1f ? std::max(0.0f, target.z / air) : 0) - back);
        gain += gate_smoothing * ((target.enabled ? target.gain : 0) - gain);
        if (gain < 1e-20f) gain = 0;
        if ((control_count++ & 63u) == 0) {
            rush_cut = coefficient((1700 + 2800 * std::min(speed / 65, 1.0f)) * (1 - .35f*tuck));
        }
        float slow_gust = slow.tick(.55f, sample_rate);
        float buffet = flutter.tick(3.5f + speed * .13f, sample_rate);
        float white = body_noise.next();
        float low = body_low.tick(white, c160);
        low = low - low_cut.tick(low, c35);
        float rush = rush_low.tick(white, rush_cut);
        rush = rush - rush_high.tick(rush, c100);
        // A second pole smooths the rush without resonant/whistling peaks.
        rush = body_high.tick(rush, rush_cut);
        float wl = left_noise.next(), wr = right_noise.next();
        float detail_l = l_low.tick(wl - l_high.tick(wl, c1800), c6000);
        float detail_r = r_low.tick(wr - r_high.tick(wr, c1800), c6000);
        float intensity = std::pow(std::min(speed / 25.0f, 6.0f), 1.25f);
        intensity = intensity / (1 + .22f*intensity); // Soft loudness saturation, no speed cap.
        float envelope = (1 + .13f*slow_gust + gust*.07f*slow_gust);
        float pressure = low * (1.6f + .45f*std::min(speed/55, 1.0f)) *
            (1 + buffet*(.14f + gust*.1f)) * (1 - .38f*tuck);
        float center = rush * (.72f - .13f*tuck) + pressure;
        float detail_gain = (.055f + .10f*std::min(speed/65, 1.0f)) * (1 - .55f*tuck) * (1 - .18f*back);
        float amplitude = REFERENCE_GAIN * intensity * envelope * gain;
        float l = (center + detail_l * detail_gain) * (1 - side*.12f) * amplitude;
        float r = (center + detail_r * detail_gain) * (1 + side*.12f) * amplitude;
        l -= dc_l.tick(l, c_dc); r -= dc_r.tick(r, c_dc);
        // Smooth bounded saturation. No hard-clipping edge or AGC pumping.
        l = CEILING * std::tanh(l / CEILING); r = CEILING * std::tanh(r / CEILING);
        return {l, r};
    }
};
}
