#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/defs.hpp>
using namespace godot;
void register_skier_body_fit();
void register_skier_anatomy();
void initialize_skier(ModuleInitializationLevel level) {
    if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
    register_skier_body_fit();
    register_skier_anatomy();
}
void uninitialize_skier(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT alpine_skier_init(GDExtensionInterfaceGetProcAddress get_proc,
    GDExtensionClassLibraryPtr library, GDExtensionInitialization* initialization) {
    GDExtensionBinding::InitObject init(get_proc, library, initialization);
    init.register_initializer(initialize_skier);
    init.register_terminator(uninitialize_skier);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
