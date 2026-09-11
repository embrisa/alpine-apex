#include "register_types.h"
#include "alpine_fsr.h"
#include "core/config/engine.h"

static AlpineFidelityFX *instance = nullptr;
void initialize_alpine_fsr_module(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    GDREGISTER_CLASS(AlpineFidelityFX);
    instance = memnew(AlpineFidelityFX);
    Engine::get_singleton()->add_singleton(Engine::Singleton("AlpineFidelityFX", instance));
}
void uninitialize_alpine_fsr_module(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    Engine::get_singleton()->remove_singleton("AlpineFidelityFX");
    memdelete(instance);
    instance = nullptr;
}
