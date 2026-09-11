#pragma once
#include "core/object/object.h"
#include "core/object/class_db.h"
#include "core/variant/dictionary.h"
#include "servers/rendering/renderer_rd/effects/fsr2.h"

class AlpineFidelityFX : public Object {
    GDCLASS(AlpineFidelityFX, Object);
protected:
    static void _bind_methods();
public:
    void set_options(const String &upscaler, bool frame_generation);
    void reset_history();
    Dictionary get_status() const;
};

namespace AlpineFSR {
bool upscale(const RendererRD::FSR2Effect::Parameters &params);
void release(void *&state);
// DX12 swapchain hooks; opaque types keep Windows headers out of shared renderer code.
void *create_swapchain(void *factory, void *queue, void *hwnd, void *description, void **output);
void release_swapchain(void *&state);
void before_present(void *state);
void resized_swapchain(void *state);
void cache_frame(const RendererRD::FSR2Effect::Parameters &params);
void finish_frame(RID render_target);
}
