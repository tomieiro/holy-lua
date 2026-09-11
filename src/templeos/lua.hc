/* TempleOS entry point for the Lua runtime. */

#include "../platform/templeos/templeos_api.hc"

U0 LuaTempleOSMain() {
  LuaPlatformInit();
  LuaPlatformWriteLine("Lua para HolyC: runtime em inicializacao");
  LuaPlatformShutdown();
}

LuaTempleOSMain();
