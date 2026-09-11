// Verify the signed SDK against the actual DX12 device, independently of Godot.
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_6.h>
#include <wrl/client.h>
#include <ffx_api_loader.h>
#include <dx12/ffx_api_dx12.h>
#include <ffx_upscale.h>
#include <ffx_framegeneration.h>
#include <cstdio>
#include <vector>
#include <string>
using Microsoft::WRL::ComPtr;

static void message(uint32_t type, const wchar_t *text) {
    std::fwprintf(stderr, L"SDK[%u]: %ls\n", type, text);
}

int wmain() {
    wchar_t path[32768]{};
    GetModuleFileNameW(nullptr, path, 32768);
    std::wstring directory(path);
    directory.resize(directory.find_last_of(L"\\/") + 1);
    HMODULE loader = LoadLibraryExW((directory + L"amd_fidelityfx_loader_dx12.dll").c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS);
    if (!loader) { std::printf("LOADER_FAILED %lu\n", GetLastError()); return 1; }
    ffxFunctions api{};
    ffxLoadFunctions(&api, loader);
    if (!api.CreateContext || !api.Query || !api.DestroyContext || !api.Dispatch || !api.Configure) return 2;
    ComPtr<IDXGIFactory6> factory;
    if (FAILED(CreateDXGIFactory2(0, IID_PPV_ARGS(&factory)))) return 3;
    ComPtr<IDXGIAdapter1> adapter;
    ComPtr<ID3D12Device> device;
    for (UINT index = 0; factory->EnumAdapterByGpuPreference(index, DXGI_GPU_PREFERENCE_HIGH_PERFORMANCE,
         IID_PPV_ARGS(&adapter)) != DXGI_ERROR_NOT_FOUND; ++index) {
        DXGI_ADAPTER_DESC1 desc{};
        adapter->GetDesc1(&desc);
        if (!(desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) &&
            SUCCEEDED(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_12_0, IID_PPV_ARGS(&device)))) {
            char name[256]{};
            WideCharToMultiByte(CP_UTF8, 0, desc.Description, -1, name, 256, nullptr, nullptr);
            std::printf("ADAPTER %s vendor=0x%04x device=0x%04x\n", name, desc.VendorId, desc.DeviceId);
            break;
        }
        adapter.Reset();
    }
    if (!device) return 4;
    D3D12_FEATURE_DATA_SHADER_MODEL sm{D3D_SHADER_MODEL_6_6};
    HRESULT hr = device->CheckFeatureSupport(D3D12_FEATURE_SHADER_MODEL, &sm, sizeof(sm));
    std::printf("SHADER_MODEL query=0x%08lx highest=0x%x\n", hr, sm.HighestShaderModel);
    int failures = 0;
    for (auto type : {uint64_t(FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE), uint64_t(FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION)}) {
        uint64_t count = 0;
        ffxQueryDescGetVersions query{};
        query.header.type = FFX_API_QUERY_DESC_TYPE_GET_VERSIONS;
        query.createDescType = type;
        query.device = device.Get();
        query.outputCount = &count;
        auto result = api.Query(nullptr, &query.header);
        std::printf("EFFECT 0x%llx query=%u count=%llu\n", type, result, count);
        if (result || !count || count > 128) { ++failures; continue; }
        std::vector<uint64_t> ids(count);
        std::vector<const char *> names(count);
        query.versionIds = ids.data(); query.versionNames = names.data();
        result = api.Query(nullptr, &query.header);
        if (result) { ++failures; continue; }
        for (size_t i = 0; i < count; ++i) {
            std::printf("PROVIDER 0x%llx %s\n", ids[i], names[i] ? names[i] : "unknown");
            ffxOverrideVersion version{};
            version.header.type = FFX_API_DESC_TYPE_OVERRIDE_VERSION;
            version.versionId = ids[i];
            ffxCreateBackendDX12Desc backend{};
            backend.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_BACKEND_DX12;
            backend.header.pNext = &version.header;
            backend.device = device.Get();
            ffxContext context{};
            ffxCreateContextDescUpscale upscale_create{};
            ffxCreateContextDescFrameGeneration fg_create{};
            ffxCreateContextDescUpscaleVersion upscale_api{};
            upscale_api.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE_VERSION;
            upscale_api.header.pNext = &backend.header;
            upscale_api.version = FFX_UPSCALER_VERSION;
            ffxCreateContextDescFrameGenerationVersion fg_api{};
            fg_api.header.type = FFX_API_CREATE_CONTEXT_DESC_TYPE_FRAMEGENERATION_VERSION;
            fg_api.header.pNext = &backend.header;
            fg_api.version = FFX_FRAMEGENERATION_VERSION;
            if (type == FFX_API_CREATE_CONTEXT_DESC_TYPE_UPSCALE) {
                auto &create = upscale_create;
                create.header.type = type; create.header.pNext = &upscale_api.header;
                create.flags = FFX_UPSCALE_ENABLE_HIGH_DYNAMIC_RANGE | FFX_UPSCALE_ENABLE_DEPTH_INVERTED | FFX_UPSCALE_ENABLE_AUTO_EXPOSURE;
                create.maxRenderSize = {960, 540}; create.maxUpscaleSize = {1280, 720};
                create.fpMessage = message;
                result = api.CreateContext(&context, &create.header, nullptr);
            } else {
                auto &create = fg_create;
                create.header.type = type; create.header.pNext = &fg_api.header;
                create.flags = FFX_FRAMEGENERATION_ENABLE_DEPTH_INVERTED;
                create.displaySize = {1280, 720}; create.maxRenderSize = {960, 540};
                create.backBufferFormat = FFX_API_SURFACE_FORMAT_R8G8B8A8_UNORM;
                result = api.CreateContext(&context, &create.header, nullptr);
            }
            std::printf("CREATE %s result=%u\n", names[i] ? names[i] : "unknown", result);
            if (context) {
                ffxQueryGetProviderVersion active{};
                active.header.type = FFX_API_QUERY_DESC_TYPE_GET_PROVIDER_VERSION;
                auto queried = api.Query(&context, &active.header);
                std::printf("ACTIVE query=%u %s\n", queried, active.versionName ? active.versionName : "unknown");
                api.DestroyContext(&context, nullptr);
            } else { ++failures; }
        }
    }
    std::printf("PROBE_COMPLETE context_failures=%d\n", failures);
    return failures ? 5 : 0;
}
