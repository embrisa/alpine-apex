#include "alpine_fsr.h"
#include "core/config/engine.h"
#include "core/os/os.h"
#include "drivers/d3d12/rendering_device_driver_d3d12.h"
#include "servers/rendering/renderer_rd/effects/copy_effects.h"
#include "servers/rendering/renderer_rd/storage_rd/texture_storage.h"
#include <ffx_api_loader.h>
#include <dx12/ffx_api_dx12.h>
#include <ffx_upscale.h>
#include <ffx_framegeneration.h>
#include <dx12/ffx_api_framegeneration_dx12.h>
#include <atomic>
#include <mutex>
#include <vector>

namespace {
std::atomic<int> requested_mode{0}; // 0 built-in, 1 auto, 2 FSR3, 3 FSR4
std::atomic<bool> requested_fg{false};
std::atomic<uint64_t> history_epoch{1};
std::atomic<uint64_t> dispatched{0};
std::atomic<uint64_t> generated{0};
std::atomic<bool> fg_active{false};
std::atomic<bool> fg_supported{false};
std::atomic<bool> fg_capabilities_queried{false};
std::atomic<bool> capabilities_queried{false};
std::atomic<uint64_t> presented_real{0};
std::atomic<uint64_t> presented_dxgi{0};
std::atomic<bool> present_counter_available{false};
std::mutex status_mutex;
String active_version;
String failure;
bool supports_fsr3 = false;
bool supports_fsr4 = false;
ffxFunctions api{};
bool load_attempted = false;
std::mutex fg_mutex;

struct SwapState {
    ffxContext swap_context = nullptr;
    ffxContext fg_context = nullptr;
    IDXGISwapChain4 *swapchain = nullptr;
    ID3D12CommandQueue *queue = nullptr;
    ffxCreateContextDescFrameGenerationSwapChainForHwndDX12 swap_create{};
    ffxCreateContextDescFrameGenerationSwapChainVersionDX12 swap_api_version{};
    DXGI_SWAP_CHAIN_DESC1 swap_desc{};
    ffxCreateContextDescFrameGeneration create{};
    ffxCreateContextDescFrameGenerationVersion fg_api_version{};
    ffxCreateContextDescFrameGenerationHudless hudless_desc{};
    ffxCreateBackendDX12Desc backend{};
    ffxOverrideVersion version{};
    ffxConfigureDescFrameGeneration config{};
    RID hudless[3];
    Size2i output;
    uint64_t frame_id = 0;
    uint64_t epoch = 0;
    bool prepared = false;
    bool enabled = false;
    bool reset = true;
    bool failed = false;
};
SwapState *primary_swap = nullptr;
RendererRD::FSR2Effect::Parameters cached_frame{};
bool has_cached_frame = false;

void report_error(const String &text) {
    std::lock_guard<std::mutex> lock(status_mutex);
    failure = text;
    ERR_PRINT(text);
}
bool load_api() {
    if (load_attempted) return api.Dispatch != nullptr;
    load_attempted = true;
    const String path = OS::get_singleton()->get_executable_path().get_base_dir().path_join("amd_fidelityfx_loader_dx12.dll");
    HMODULE dll = LoadLibraryExW((const wchar_t *)path.utf16().get_data(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (!dll) { report_error("AMD FSR loader could not be loaded beside the custom engine."); return false; }
    ffxLoadFunctions(&api, dll);
    if (!api.CreateContext || !api.DestroyContext || !api.Query || !api.Configure || !api.Dispatch) {
        api = {};
        report_error("AMD FSR loader is missing required API functions.");
        return false;
    }
    return true;
}
uint64_t generation_version(ID3D12Device *device) {
    uint64_t count = 0;
    ffxQueryDescGetVersions versions{};
    versions.header.type = FFX_API_QUERY_DESC_TYPE_GET_VERSIONS;
    versions.createDescType = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION;
    versions.device = device;
    versions.outputCount = &count;
    if (api.Query(nullptr, &versions.header) || !count || count > 128) return 0;
    std::vector<uint64_t> ids(count);
    std::vector<const char *> names(count);
    versions.versionIds = ids.data(); versions.versionNames = names.data();
    if (api.Query(nullptr, &versions.header)) return 0;
    for (uint64_t i = 0; i < count; ++i) {
        if (names[i] && String::utf8(names[i]).begins_with("3.1.")) return ids[i];
    }
    return 0;
}
void debug_message(uint32_t type, const wchar_t *text) {
    String value = String::utf16((const char16_t *)text);
    if (type == FFX_API_MESSAGE_TYPE_ERROR) report_error(value);
    else WARN_PRINT(value);
}
struct State {
    ffxContext context = nullptr;
    ffxCreateContextDescUpscale create{};
    ffxCreateContextDescUpscaleVersion api_version{};
    ffxCreateBackendDX12Desc backend{};
    ffxOverrideVersion override_version{};
    Size2i input;
    Size2i output;
    int mode = 0;
    uint64_t epoch = 0;
    RID reactive;
    bool first = true;
    bool failed = false;
};
struct Packet {
    State *state;
    ffxDispatchDescUpscale desc;
};
ID3D12Resource *native_texture(RID rid) {
    return rid.is_valid() ? (ID3D12Resource *)RD::get_singleton()->get_driver_resource(RD::DRIVER_RESOURCE_TEXTURE, rid) : nullptr;
}
FfxApiResource read_texture(RID rid) {
    return ffxApiGetResourceDX12(native_texture(rid), FFX_API_RESOURCE_STATE_PIXEL_COMPUTE_READ);
}
void dispatch(RenderingDeviceDriver *driver, RenderingDeviceDriver::CommandBufferID command, void *userdata) {
    Packet *packet = static_cast<Packet *>(userdata);
    auto *dx12 = static_cast<RenderingDeviceDriverD3D12 *>(driver);
    packet->desc.commandList = dx12->alpine_external_begin(command);
    auto code = api.Dispatch(&packet->state->context, &packet->desc.header);
    dx12->alpine_external_end(command);
    if (code == FFX_API_RETURN_OK) ++dispatched;
    else {
        packet->state->failed = true;
        {
            std::lock_guard<std::mutex> lock(status_mutex);
            active_version = "2.2.1";
        }
        report_error(vformat("AMD FSR dispatch failed (%d).", code));
    }
    memdelete(packet);
}
bool create_state(State &state) {
    auto *device = (ID3D12Device *)RD::get_singleton()->get_driver_resource(RD::DRIVER_RESOURCE_LOGICAL_DEVICE);
    uint64_t count = 0;
    ffxQueryDescGetVersions query{};
    query.header.type = FFX_API_QUERY_DESC_TYPE_GET_VERSIONS;
    query.createDescType = FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE;
    query.device = device;
    query.outputCount = &count;
    if (api.Query(nullptr, &query.header) != FFX_API_RETURN_OK || !count || count > 128) return false;
    std::vector<uint64_t> ids(count);
    std::vector<const char *> names(count);
    query.versionIds = ids.data(); query.versionNames = names.data();
    if (api.Query(nullptr, &query.header) != FFX_API_RETURN_OK) return false;
    capabilities_queried = true;
    uint64_t selected = 0;
    uint64_t version3 = 0;
    uint64_t version4 = 0;
    {
        std::lock_guard<std::mutex> lock(status_mutex);
        for (uint64_t i = 0; i < count; ++i) {
            String name = names[i] ? String::utf8(names[i]) : String();
            if (name.begins_with("3.1.")) { supports_fsr3 = true; if (!version3) version3 = ids[i]; }
            if (name.begins_with("4.1.")) { supports_fsr4 = true; if (!version4) version4 = ids[i]; }
        }
    }
    selected = state.mode == 2 ? version3 : state.mode == 3 ? version4 : version4 ? version4 : version3;
    if (!selected) return false;
    state.override_version.header.type = FFX_API_DESC_TYPE_OVERRIDE_VERSION;
    state.override_version.versionId = selected;
    state.backend.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12;
    state.backend.header.pNext = &state.override_version.header;
    state.backend.device = device;
    state.create.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE;
    state.create.header.pNext = &state.api_version.header;
    state.api_version.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE_VERSION;
    state.api_version.header.pNext = &state.backend.header;
    state.api_version.version = FFX_UPSCALER_VERSION;
    state.create.flags = FFX_UPSCALE_ENABLE_HIGH_DYNAMIC_RANGE | FFX_UPSCALE_ENABLE_DEPTH_INVERTED | FFX_UPSCALE_ENABLE_AUTO_EXPOSURE;
    state.create.maxRenderSize = {uint32_t(state.input.x), uint32_t(state.input.y)};
    state.create.maxUpscaleSize = {uint32_t(state.output.x), uint32_t(state.output.y)};
    state.create.fpMessage = debug_message;
    auto result = api.CreateContext(&state.context, &state.create.header, nullptr);
    if (result != FFX_API_RETURN_OK && state.mode == 1 && version3 && selected != version3) {
        if (state.context) api.DestroyContext(&state.context, nullptr);
        state.context = nullptr;
        state.override_version.versionId = version3;
        result = api.CreateContext(&state.context, &state.create.header, nullptr);
    }
    if (result != FFX_API_RETURN_OK) return false;
    ffxQueryGetProviderVersion active{};
    active.header.type = FFX_API_QUERY_DESC_TYPE_GET_PROVIDER_VERSION;
    if (api.Query(&state.context, &active.header) != FFX_API_RETURN_OK) return false;
    {
        std::lock_guard<std::mutex> lock(status_mutex);
        active_version = active.versionName ? String::utf8(active.versionName) : "unknown";
        failure = String();
        print_line("ALPINE_FSR_PROVIDER " + active_version);
    }
    // Godot's reactive texture is an alpha-swizzled view of HDR color. Materialize
    // it before passing a raw DX12 resource: the SDK cannot inherit Godot's SRV swizzle.
    RD::TextureFormat format;
    format.format = RD::DATA_FORMAT_R16G16B16A16_SFLOAT;
    format.width = state.input.x; format.height = state.input.y;
    format.usage_bits = RD::TEXTURE_USAGE_SAMPLING_BIT | RD::TEXTURE_USAGE_STORAGE_BIT;
    state.reactive = RD::get_singleton()->texture_create(format, RD::TextureView());
    return state.reactive.is_valid();
}
}

void AlpineFidelityFX::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_options", "upscaler", "frame_generation"), &AlpineFidelityFX::set_options);
    ClassDB::bind_method(D_METHOD("reset_history"), &AlpineFidelityFX::reset_history);
    ClassDB::bind_method(D_METHOD("get_status"), &AlpineFidelityFX::get_status);
}
void AlpineFidelityFX::set_options(const String &upscaler, bool frame_generation) {
    int mode = upscaler == "auto" ? 1 : upscaler == "fsr3" ? 2 : upscaler == "fsr4" ? 3 : 0;
    const bool changed_mode = requested_mode.exchange(mode) != mode;
    const bool changed_fg = requested_fg.exchange(frame_generation) != frame_generation;
    if (changed_mode || changed_fg) ++history_epoch;
}
void AlpineFidelityFX::reset_history() { ++history_epoch; }
Dictionary AlpineFidelityFX::get_status() const {
    std::lock_guard<std::mutex> lock(status_mutex);
    Dictionary result;
    result["engine_integration"] = true;
    result["fsr3_supported"] = supports_fsr3;
    result["fsr4_supported"] = supports_fsr4;
    result["capabilities_queried"] = capabilities_queried.load();
    result["active_upscaler_version"] = requested_mode.load() ? active_version : String();
    result["upscale_dispatches"] = int64_t(dispatched.load());
    result["frame_generation_supported"] = fg_supported.load();
    result["frame_generation_capabilities_queried"] = fg_capabilities_queried.load();
    result["frame_generation_active"] = fg_active.load();
    result["frame_generation_version"] = fg_active.load() ? "3.1.6" : "";
    result["generated_frames"] = int64_t(generated.load());
    result["rendered_present_calls"] = int64_t(presented_real.load());
    result["dxgi_present_count"] = int64_t(presented_dxgi.load());
    result["present_counter_available"] = present_counter_available.load();
    result["error"] = failure;
    return result;
}
void AlpineFSR::release(void *&opaque) {
    if (!opaque) return;
    // Finish recorded callbacks and GPU consumers before releasing SDK allocations.
    // Used only for a resize, mode change, viewport destruction or shutdown.
    RD::get_singleton()->alpine_flush_and_stall();
    auto *state = static_cast<State *>(opaque);
    if (state->context) api.DestroyContext(&state->context, nullptr);
    if (state->reactive.is_valid()) RD::get_singleton()->free_rid(state->reactive);
    memdelete(state);
    opaque = nullptr;
}
bool AlpineFSR::upscale(const RendererRD::FSR2Effect::Parameters &p) {
    int mode = requested_mode.load();
    if (!mode || OS::get_singleton()->get_current_rendering_driver_name() != "d3d12" || !load_api()) return false;
    RD *rd = RD::get_singleton();
    auto format = rd->texture_get_format(p.output);
    Size2i output(format.width, format.height);
    auto *state = static_cast<State *>(p.context->alpine_fsr_context);
    if (state && (state->mode != mode || state->input != p.internal_size || state->output != output)) {
        release(p.context->alpine_fsr_context);
        state = nullptr;
    }
    if (!state) {
        state = memnew(State);
        p.context->alpine_fsr_context = state;
        state->input = p.internal_size; state->output = output; state->mode = mode;
        if (!create_state(*state)) {
            state->failed = true;
            {
                std::lock_guard<std::mutex> lock(status_mutex);
                active_version = "2.2.1";
            }
            report_error("Requested AMD FSR provider could not be created; using built-in FSR2.");
        }
    }
    if (state->failed) return false;
    RendererRD::CopyEffects::get_singleton()->copy_to_rect(p.reactive, state->reactive, Rect2i(Vector2i(), p.internal_size));
    Packet *packet = memnew(Packet);
    packet->state = state;
    auto &d = packet->desc;
    d = {};
    d.header.type = FFX_API_DISPATCH_DESC_TYPE_UPSCALE;
    d.color = read_texture(p.color); d.depth = read_texture(p.depth); d.motionVectors = read_texture(p.velocity);
    d.reactive = read_texture(state->reactive);
    d.output = ffxApiGetResourceDX12(native_texture(p.output), FFX_API_RESOURCE_STATE_UNORDERED_ACCESS);
    d.jitterOffset = {float(p.jitter.x), float(p.jitter.y)};
    d.motionVectorScale = {float(p.internal_size.x), float(p.internal_size.y)};
    d.renderSize = state->create.maxRenderSize; d.upscaleSize = state->create.maxUpscaleSize;
    d.enableSharpening = p.sharpness > 0; d.sharpness = p.sharpness;
    d.frameTimeDelta = p.delta_time * 1000.0f;
    d.preExposure = 1.0f;
    d.reset = state->first || state->epoch != history_epoch.load() || p.reset_accumulation;
    d.cameraNear = p.z_near; d.cameraFar = p.z_far; d.cameraFovAngleVertical = Math::deg_to_rad(p.fovy);
    d.viewSpaceToMetersFactor = 1.0f;
    state->epoch = history_epoch.load(); state->first = false;
    RD::CallbackResource resources[] = {
        {p.color, RD::CALLBACK_RESOURCE_TYPE_TEXTURE, RD::CALLBACK_RESOURCE_USAGE_TEXTURE_SAMPLE},
        {p.depth, RD::CALLBACK_RESOURCE_TYPE_TEXTURE, RD::CALLBACK_RESOURCE_USAGE_TEXTURE_SAMPLE},
        {p.velocity, RD::CALLBACK_RESOURCE_TYPE_TEXTURE, RD::CALLBACK_RESOURCE_USAGE_TEXTURE_SAMPLE},
        {state->reactive, RD::CALLBACK_RESOURCE_TYPE_TEXTURE, RD::CALLBACK_RESOURCE_USAGE_TEXTURE_SAMPLE},
        {p.output, RD::CALLBACK_RESOURCE_TYPE_TEXTURE, RD::CALLBACK_RESOURCE_USAGE_STORAGE_IMAGE_READ_WRITE},
    };
    if (rd->driver_callback_add(dispatch, packet, {resources, 5}) != OK) { memdelete(packet); return false; }
    return true;
}

namespace {
void disable_generation(SwapState *state) {
    if (!state || !state->fg_context || !state->enabled) return;
    // Disabling waits for SDK presentation work. Do not hold fg_mutex while waiting.
    state->config.frameGenerationEnabled = false;
    state->config.HUDLessColor = {};
    state->config.presentCallback = nullptr;
    const auto result = api.Configure(&state->fg_context, &state->config.header);
    if (result) report_error(vformat("FSR frame generation disable failed (%d).", result));
    state->enabled = false;
    state->reset = true;
    fg_active = false;
}
void destroy_generation(SwapState *state) {
    disable_generation(state);
    std::lock_guard<std::mutex> lock(fg_mutex);
    if (state->fg_context) api.DestroyContext(&state->fg_context, nullptr);
    state->fg_context = nullptr;
    for (auto &rid : state->hudless) {
        if (rid.is_valid()) RD::get_singleton()->free_rid(rid);
        rid = RID();
    }
    state->prepared = false;
}
ffxReturnCode_t generate_frame(ffxDispatchDescFrameGeneration *desc, void *userdata) {
    auto *state = static_cast<SwapState *>(userdata);
    std::lock_guard<std::mutex> lock(fg_mutex);
    desc->backbufferTransferFunction = FFX_API_BACKBUFFER_TRANSFER_FUNCTION_SRGB;
    desc->minMaxLuminance[0] = 0.0f;
    desc->minMaxLuminance[1] = 1000.0f;
    const auto result = api.Dispatch(&state->fg_context, &desc->header);
    if (!result) generated.fetch_add(desc->numGeneratedFrames);
    else report_error(vformat("FSR frame generation dispatch failed (%d).", result));
    return result;
}
struct FramePacket {
    SwapState *state;
    ffxDispatchDescFrameGenerationPrepareV2 prepare;
    FfxApiResource hudless;
};
void prepare_generation(RenderingDeviceDriver *driver, RenderingDeviceDriver::CommandBufferID command, void *userdata) {
    auto *packet = static_cast<FramePacket *>(userdata);
    auto *state = packet->state;
    auto *dx12 = static_cast<RenderingDeviceDriverD3D12 *>(driver);
    state->config = {};
    state->config.header.type = FFX_API_CONFIGURE_DESC_TYPE_FRAMEGENERATION;
    state->config.swapChain = state->swapchain;
    state->config.frameGenerationEnabled = true;
    state->config.allowAsyncWorkloads = false;
    state->config.frameGenerationCallback = generate_frame;
    state->config.frameGenerationCallbackUserContext = state;
    state->config.HUDLessColor = packet->hudless;
    state->config.generationRect = {0, 0, state->output.x, state->output.y};
    state->config.frameID = packet->prepare.frameID;
    auto result = api.Configure(&state->fg_context, &state->config.header);
    if (!result) {
        std::lock_guard<std::mutex> lock(fg_mutex);
        state->enabled = true;
        packet->prepare.commandList = dx12->alpine_external_begin(command);
        result = api.Dispatch(&state->fg_context, &packet->prepare.header);
        dx12->alpine_external_end(command);
    }
    state->prepared = result == FFX_API_RETURN_OK;
    fg_active = state->prepared;
    if (result) {
        state->failed = true;
        report_error(vformat("FSR frame preparation failed (%d).", result));
    }
    memdelete(packet);
}
bool create_generation(SwapState *state, RID source) {
    ID3D12Device *device = nullptr;
    if (FAILED(state->queue->GetDevice(IID_PPV_ARGS(&device)))) return false;
    state->backend.device = device;
    device->Release(); // The queue owns the device throughout this context's lifetime.
    const uint64_t selected = generation_version(device);
    if (!selected) return false;
    state->version.header.type = FFX_API_DESC_TYPE_OVERRIDE_VERSION;
    state->version.versionId = selected;
    state->hudless_desc.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION_HUDLESS;
    state->hudless_desc.header.pNext = &state->version.header;
    state->hudless_desc.hudlessBackBufferFormat = ffxApiGetSurfaceFormatDX12(native_texture(source)->GetDesc().Format);
    state->backend.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12;
    state->backend.header.pNext = &state->hudless_desc.header;
    state->create.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION;
    state->create.header.pNext = &state->fg_api_version.header;
    state->fg_api_version.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION_VERSION;
    state->fg_api_version.header.pNext = &state->backend.header;
    state->fg_api_version.version = FFX_FRAMEGENERATION_VERSION;
    state->create.flags = FFX_FRAMEGENERATION_ENABLE_DEPTH_INVERTED;
    state->create.displaySize = {uint32_t(state->output.x), uint32_t(state->output.y)};
    state->create.maxRenderSize = state->create.displaySize;
    DXGI_SWAP_CHAIN_DESC1 swap_desc{};
    state->swapchain->GetDesc1(&swap_desc);
    state->create.backBufferFormat = ffxApiGetSurfaceFormatDX12(swap_desc.Format);
    if (api.CreateContext(&state->fg_context, &state->create.header, nullptr)) return false;
    auto format = RD::get_singleton()->texture_get_format(source);
    format.usage_bits = RD::TEXTURE_USAGE_SAMPLING_BIT | RD::TEXTURE_USAGE_CAN_COPY_TO_BIT;
    format.samples = RD::TEXTURE_SAMPLES_1;
    for (auto &rid : state->hudless) {
        rid = RD::get_singleton()->texture_create(format, RD::TextureView());
        if (rid.is_null()) return false;
        RD::get_singleton()->set_resource_name(rid, "FidelityFX HUDless presentation input");
    }
    fg_supported = true;
    print_line("ALPINE_FSR_FRAMEGEN_PROVIDER 3.1.6");
    return true;
}
}

void *AlpineFSR::create_swapchain(void *factory, void *queue, void *hwnd, void *description, void **output) {
    if (primary_swap || Engine::get_singleton()->is_editor_hint() || !load_api()) return nullptr;
    const auto format = static_cast<DXGI_SWAP_CHAIN_DESC1 *>(description)->Format;
    if (format != DXGI_FORMAT_R8G8B8A8_UNORM && format != DXGI_FORMAT_B8G8R8A8_UNORM) return nullptr;
    auto *state = memnew(SwapState);
    state->queue = static_cast<ID3D12CommandQueue *>(queue);
    ID3D12Device *device = nullptr;
    if (FAILED(state->queue->GetDevice(IID_PPV_ARGS(&device)))) { memdelete(state); return nullptr; }
    fg_supported = generation_version(device) != 0;
    fg_capabilities_queried = true;
    device->Release();
    if (!fg_supported.load()) { memdelete(state); return nullptr; }
    state->swap_desc = *static_cast<DXGI_SWAP_CHAIN_DESC1 *>(description);
    state->swap_create.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATIONSWAPCHAIN_FOR_HWND_DX12;
    state->swap_create.header.pNext = &state->swap_api_version.header;
    state->swap_api_version.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATIONSWAPCHAIN_VERSION_DX12;
    state->swap_api_version.version = FFX_FRAMEGENERATION_SWAPCHAIN_DX12_VERSION;
    state->swap_create.swapchain = &state->swapchain;
    state->swap_create.hwnd = static_cast<HWND>(hwnd);
    state->swap_create.desc = &state->swap_desc;
    state->swap_create.dxgiFactory = static_cast<IDXGIFactory *>(factory);
    state->swap_create.gameQueue = state->queue;
    if (api.CreateContext(&state->swap_context, &state->swap_create.header, nullptr)) {
        memdelete(state);
        WARN_PRINT("FSR swapchain unavailable; retaining the normal DX12 swapchain.");
        return nullptr;
    }
    *output = state->swapchain;
    primary_swap = state;
    print_line("ALPINE_FSR_SWAPCHAIN_READY");
    return state;
}
void AlpineFSR::release_swapchain(void *&opaque) {
    if (!opaque) return;
    auto *state = static_cast<SwapState *>(opaque);
    destroy_generation(state);
    api.DestroyContext(&state->swap_context, nullptr);
    if (primary_swap == state) primary_swap = nullptr;
    has_cached_frame = false;
    memdelete(state);
    opaque = nullptr;
}
void AlpineFSR::resized_swapchain(void *opaque) {
    if (!opaque) return;
    auto *state = static_cast<SwapState *>(opaque);
    destroy_generation(state);
    state->failed = false;
    state->reset = true;
    has_cached_frame = false;
}
void AlpineFSR::before_present(void *opaque) {
    if (!opaque) return;
    auto *state = static_cast<SwapState *>(opaque);
    if (!state->prepared || !requested_fg.load() || state->failed) disable_generation(state);
    has_cached_frame = false;
    state->prepared = false;
    ++state->frame_id;
    ++presented_real;
    UINT count = 0;
    if (SUCCEEDED(state->swapchain->GetLastPresentCount(&count))) {
        presented_dxgi = count;
        present_counter_available = true;
    }
}
void AlpineFSR::cache_frame(const RendererRD::FSR2Effect::Parameters &params) {
    if (!primary_swap || !requested_fg.load()) return;
    auto format = RD::get_singleton()->texture_get_format(params.output);
    DXGI_SWAP_CHAIN_DESC1 desc{};
    primary_swap->swapchain->GetDesc1(&desc);
    // This integration is for the one primary game window, not preview viewports.
    if (format.width != desc.Width || format.height != desc.Height) return;
    cached_frame = params;
    has_cached_frame = true;
}
void AlpineFSR::finish_frame(RID render_target) {
    auto *state = primary_swap;
    if (!state || !has_cached_frame || !requested_fg.load() || state->failed) return;
    has_cached_frame = false;
    RD *rd = RD::get_singleton();
    RID source = RendererRD::TextureStorage::get_singleton()->render_target_get_rd_texture(render_target);
    auto format = rd->texture_get_format(source);
    DXGI_SWAP_CHAIN_DESC1 desc{};
    state->swapchain->GetDesc1(&desc);
    if (format.width != desc.Width || format.height != desc.Height || format.array_layers != 1) return;
    state->output = Size2i(desc.Width, desc.Height);
    if (!state->fg_context && !create_generation(state, source)) {
        state->failed = true;
        report_error("FSR3 frame generation could not create a context for this device and output.");
        return;
    }
    RID hud = state->hudless[state->frame_id % 3];
    if (rd->texture_copy(source, hud, Vector3(), Vector3(), Vector3(format.width, format.height, 1), 0, 0, 0, 0) != OK) return;
    auto *packet = memnew(FramePacket);
    packet->state = state;
    // The SDK presentation queue uses legacy ResourceBarrier commands. Godot
    // uses enhanced barriers: crossing between them is legal only at COMMON.
    packet->hudless = ffxApiGetResourceDX12(native_texture(hud), FFX_API_RESOURCE_STATE_COMMON);
    auto &p = cached_frame;
    auto &d = packet->prepare;
    d = {};
    d.header.type = FFX_API_DISPATCH_DESC_TYPE_FRAMEGENERATION_PREPARE_V2;
    d.frameID = state->frame_id;
    d.renderSize = {uint32_t(p.internal_size.x), uint32_t(p.internal_size.y)};
    d.jitterOffset = {float(p.jitter.x), float(p.jitter.y)};
    d.motionVectorScale = {float(p.internal_size.x), float(p.internal_size.y)};
    d.frameTimeDelta = p.delta_time * 1000.0f;
    d.reset = state->reset || state->epoch != history_epoch.load() || p.reset_accumulation;
    d.cameraNear = p.z_near; d.cameraFar = p.z_far; d.cameraFovAngleVertical = Math::deg_to_rad(p.fovy);
    d.viewSpaceToMetersFactor = 1.0f;
    d.depth = read_texture(p.depth); d.motionVectors = read_texture(p.velocity);
    for (int i = 0; i < 3; ++i) {
        d.cameraPosition[i] = p.alpine_camera_transform.origin[i];
        d.cameraUp[i] = p.alpine_camera_transform.basis.get_column(1)[i];
        d.cameraRight[i] = p.alpine_camera_transform.basis.get_column(0)[i];
        d.cameraForward[i] = -p.alpine_camera_transform.basis.get_column(2)[i];
    }
    state->reset = false;
    state->epoch = history_epoch.load();
    RD::CallbackResource resources[] = {
        {p.depth, RD::CALLBACK_RESOURCE_TYPE_TEXTURE, RD::CALLBACK_RESOURCE_USAGE_TEXTURE_SAMPLE},
        {p.velocity, RD::CALLBACK_RESOURCE_TYPE_TEXTURE, RD::CALLBACK_RESOURCE_USAGE_TEXTURE_SAMPLE},
        {hud, RD::CALLBACK_RESOURCE_TYPE_TEXTURE, RD::CALLBACK_RESOURCE_USAGE_GENERAL}
    };
    if (rd->driver_callback_add(prepare_generation, packet, {resources, 3}) != OK) memdelete(packet);
}
