#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/quaternion.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <cmath>
using namespace godot;

// Replay 7's bounded numeric validation. The script owns header/identity/clock,
// decompression, content validation, crash semantics and cache publication.
// Inputs are immutable, so separate payload workers may share this stateless kernel.
class AlpineReplayValidation : public RefCounted {
    GDCLASS(AlpineReplayValidation, RefCounted)
    static constexpr int snapshot_width = 90, pose_width = 224, input_width = 9;
    static constexpr int frame_start = 74, facing_yaw = 86, pole_start = 87;
    static constexpr double pi = 3.14159265358979323846;
    static bool bounded(const float *v, int count) {
        for (int i = 0; i < count; ++i)
            if (!std::isfinite(v[i]) || std::abs(double(v[i])) > 10000.0) return false;
        return true;
    }
    static bool bit(float v) { return v == 0.0f || v == 1.0f; }
    static Vector3 vector(const float *v) { return Vector3(v[0], v[1], v[2]); }
    static bool unit_quaternion(const float *v) {
        return std::abs(double(Quaternion(v[0], v[1], v[2], v[3]).length_squared()) - 1.0) <= .01;
    }
    static bool snapshot(const PackedFloat32Array &frame) {
        if (frame.size() != snapshot_width) return false;
        const float *v = frame.ptr();
        if (!bounded(v, snapshot_width)) return false;
        if (std::abs(double(v[5])) > pi || v[6] < 0 || v[6] > 1 || !bit(v[10])) return false;
        if (std::abs(double(vector(v + 7).length()) - 1.0) > .15) return false;
        for (int i = frame_start; i < frame_start + 12; i += 4)
            if (!unit_quaternion(v + i)) return false;
        for (int i = 11; i < 56; ++i) if (std::abs(double(v[i])) > 3.0) return false;
        for (int i = 56; i < 74; i += 9) {
            if (vector(v + i).length() > 3.0) return false;
            if (std::abs(double(vector(v + i + 3).length()) - 1.0) > .15) return false;
            if (std::abs(double(v[i + 6])) > pi + .01 || std::abs(double(v[i + 7])) > pi || !bit(v[i + 8])) return false;
        }
        for (int i = pole_start; i < snapshot_width; ++i) if (v[i] < 0 || v[i] > 1) return false;
        return std::abs(double(v[facing_yaw])) <= pi + .01;
    }
    static bool pose(const PackedFloat32Array &frame) {
        if (frame.size() != pose_width) return false;
        const float *v = frame.ptr();
        if (!bounded(v, pose_width)) return false;
        for (int i = 0; i < 29; ++i) {
            int start = i * 7;
            if (!unit_quaternion(v + start + 3)) return false;
            if (i > 0 && vector(v + start).length() > 8.0) return false;
        }
        for (int start = 203; start < 223; start += 10) {
            if (!bit(v[start]) || !bit(v[start + 1])) return false;
            for (int i = 2; i <= 3; ++i)
                if (double(v[start + i]) < .01 || v[start + i] > 4) return false;
            if (v[start + 4] < 0 || v[start + 4] > 1 || v[start + 5] < 0 || v[start + 5] > 1) return false;
            if (v[start + 6] < 0 || v[start + 6] > 4 || double(vector(v + start + 7).length()) > 1.1) return false;
        }
        return v[223] >= .5 && v[223] <= 3.0;
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("validate", "samples", "poses", "inputs", "tick_kinds"), &AlpineReplayValidation::validate);
    }
public:
    bool validate(const Array &samples, const Array &poses, const PackedFloat32Array &inputs, const PackedByteArray &kinds) const {
        // Keep this public entry point bounded even when invoked outside the decoder.
        if (samples.size() < 2 || samples.size() > 18514 || poses.size() != samples.size() || kinds.size() > 72000 || inputs.size() != kinds.size() * input_width) return false;
        for (int64_t i = 0; i < samples.size(); ++i) {
            if (samples[i].get_type() != Variant::PACKED_FLOAT32_ARRAY || poses[i].get_type() != Variant::PACKED_FLOAT32_ARRAY) return false;
            if (!snapshot(samples[i]) || !pose(poses[i])) return false;
        }
        const float *v = inputs.ptr();
        for (int64_t i = 0; i < inputs.size(); ++i) {
            const int field = int(i % input_width);
            const bool signed_field = field == 0 || field == 4 || field == 5 || field == 7;
            if (!std::isfinite(v[i]) || v[i] > 1.0f || v[i] < (signed_field ? -1.0f : 0.0f)) return false;
            if ((field == 3 || field == 6 || field == 8) && !bit(v[i])) return false;
        }
        for (int64_t i = 0; i < kinds.size(); ++i) if (kinds[i] > 1) return false;
        return true;
    }
};

void register_replay_validation() { GDREGISTER_CLASS(AlpineReplayValidation); }
