"""Apply the narrow native renderer hooks to the pinned, isolated Godot checkout."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / '.tools/godot-fsr'
PIN = 'ed1daf0bf001b61586d9930840f2f1394092c079'
if subprocess.check_output(['git', '-C', str(ENGINE), 'rev-parse', 'HEAD'], text=True).strip() != PIN:
    raise SystemExit('Godot source must be the pinned 4.7.2-stable commit')


def replace(path, before, after):
    target = ENGINE / path
    text = target.read_text(encoding='utf-8')
    if after in text:
        return
    if text.count(before) != 1:
        raise SystemExit(f'Unexpected source at {path}; existing changes preserved')
    target.write_text(text.replace(before, after), encoding='utf-8', newline='\n')


replace('servers/rendering/rendering_device.h', 'uint32_t get_frame_delay() const;',
        'uint32_t get_frame_delay() const;\n\tvoid alpine_flush_and_stall() { _flush_and_stall_for_all_frames(); }')
replace('servers/rendering/renderer_rd/effects/fsr2.h', '\tScratch scratch;',
        '\tvoid *alpine_fsr_context = nullptr;\n\tScratch scratch;')
replace('servers/rendering/renderer_rd/effects/fsr2.h', '\t\tProjection reprojection;',
        '\t\tProjection reprojection;\n\t\tTransform3D alpine_camera_transform;')
replace('servers/rendering/renderer_rd/effects/fsr2.cpp', '#include "fsr2.h"',
        '#include "fsr2.h"\n#include "modules/alpine_fsr/alpine_fsr.h"')
replace('servers/rendering/renderer_rd/effects/fsr2.cpp', 'FSR2Context::~FSR2Context() {',
        'FSR2Context::~FSR2Context() {\n\tAlpineFSR::release(alpine_fsr_context);')
forward = 'servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp'
replace(forward, '#include "render_forward_clustered.h"',
        '#include "render_forward_clustered.h"\n#include "modules/alpine_fsr/alpine_fsr.h"')
replace(forward, 'fsr2_effect->upscale(params);',
        'if (!AlpineFSR::upscale(params)) { fsr2_effect->upscale(params); }')
replace(forward, 'if (!AlpineFSR::upscale(params)) { fsr2_effect->upscale(params); }',
        'params.alpine_camera_transform = p_render_data->scene_data->cam_transform;\n'
        '\t\t\t\tAlpineFSR::cache_frame(params);\n'
        '\t\t\t\tif (!AlpineFSR::upscale(params)) { fsr2_effect->upscale(params); }')
replace(forward, '\t\t_render_buffers_post_process_and_tonemap(p_render_data);',
        '\t\t_render_buffers_post_process_and_tonemap(p_render_data);\n\t\tAlpineFSR::finish_frame(rb->get_render_target());')
replace(forward, 'params.reset_accumulation = false; // FIXME: The engine does not provide a way to reset the accumulation.',
        'params.reset_accumulation = p_render_data->scene_data->prev_cam_transform.origin.distance_to(p_render_data->scene_data->cam_transform.origin) > 10.0f ||\n'
        '\t\t\t\t\tp_render_data->scene_data->prev_cam_transform.basis.get_column(2).dot(p_render_data->scene_data->cam_transform.basis.get_column(2)) < 0.707f;')
driver = 'drivers/d3d12/rendering_device_driver_d3d12'
replace(driver + '.h', '#ifdef DEV_ENABLED\n#define CUSTOM_INFO_QUEUE_ENABLED 0\n#endif',
        '// Surface validation messages in test logs instead of debugger-only output.\n#define CUSTOM_INFO_QUEUE_ENABLED 1')
replace(driver + '.cpp', 'case D3D12_MESSAGE_SEVERITY_INFO:\n\t\t\tprint_line(error_message);',
        'case D3D12_MESSAGE_SEVERITY_INFO:\n\t\t\tprint_verbose(error_message);')
replace(driver + '.cpp', '#include "rendering_device_driver_d3d12.h"',
        '#include "rendering_device_driver_d3d12.h"\n#include "modules/alpine_fsr/alpine_fsr.h"')
replace(driver + '.h', '\t\tMicrosoft::WRL::ComPtr<IDXGISwapChain3> d3d_swap_chain;',
        '\t\tMicrosoft::WRL::ComPtr<IDXGISwapChain3> d3d_swap_chain;\n\t\tvoid *alpine_context = nullptr;')
replace(driver + '.cpp', '\t\tres = swap_chain->d3d_swap_chain->Present(',
        '\t\tAlpineFSR::before_present(swap_chain->alpine_context);\n\t\tres = swap_chain->d3d_swap_chain->Present(')
replace(driver + '.cpp', '\tp_swap_chain->d3d_swap_chain.Reset();',
        '\tAlpineFSR::release_swapchain(p_swap_chain->alpine_context);\n\tp_swap_chain->d3d_swap_chain.Reset();')
replace(driver + '.cpp', '\t\tres = swap_chain->d3d_swap_chain->ResizeBuffers(',
        '\t\tAlpineFSR::resized_swapchain(swap_chain->alpine_context);\n\t\tres = swap_chain->d3d_swap_chain->ResizeBuffers(')
replace(driver + '.cpp', '\t\tComPtr<IDXGISwapChain1> swap_chain_1;\n\t\tif (create_for_composition) {',
        '\t\tComPtr<IDXGISwapChain1> swap_chain_1;\n'
        '\t\tvoid *alpine_swap = nullptr;\n'
        '\t\tif (!create_for_composition) {\n'
        '\t\t\tswap_chain->alpine_context = AlpineFSR::create_swapchain(context_driver->dxgi_factory_get(), command_queue->d3d_queue.Get(), surface->hwnd, &swap_chain_desc, &alpine_swap);\n'
        '\t\t}\n'
        '\t\tif (alpine_swap) {\n'
        '\t\t\tres = static_cast<IDXGISwapChain4 *>(alpine_swap)->QueryInterface(IID_PPV_ARGS(swap_chain_1.GetAddressOf()));\n'
        '\t\t} else if (create_for_composition) {')
replace(driver + '.h', 'virtual CommandBufferID command_buffer_create(CommandPoolID p_cmd_pool) override final;',
        'ID3D12GraphicsCommandList *alpine_external_begin(CommandBufferID command);\n'
        '\tvoid alpine_external_end(CommandBufferID command);\n'
        '\tvirtual CommandBufferID command_buffer_create(CommandPoolID p_cmd_pool) override final;')
replace(driver + '.cpp', 'uint64_t RenderingDeviceDriverD3D12::get_resource_native_handle(',
        '''ID3D12GraphicsCommandList *RenderingDeviceDriverD3D12::alpine_external_begin(CommandBufferID command) {
    auto *info = (CommandBufferInfo *)command.id;
    _resource_transitions_flush(info);
    return info->cmd_list.Get();
}
void RenderingDeviceDriverD3D12::alpine_external_end(CommandBufferID command) {
    auto *info = (CommandBufferInfo *)command.id;
    info->graphics_pso = nullptr;
    info->compute_pso = nullptr;
    info->graphics_root_signature_crc = 0;
    info->compute_root_signature_crc = 0;
    info->descriptor_heaps_set = false;
    info->pending_dyn_params = true;
}

uint64_t RenderingDeviceDriverD3D12::get_resource_native_handle(''')
shutil.copytree(ROOT / 'native/fidelityfx/godot_module', ENGINE / 'modules/alpine_fsr', dirs_exist_ok=True)
patch = subprocess.check_output(['git', '-C', str(ENGINE), 'diff', '--', 'servers', 'drivers'])
(ROOT / 'native/fidelityfx/godot-4.7.2.patch').write_bytes(patch)
print('Prepared pinned Godot source and recorded renderer patch.')
