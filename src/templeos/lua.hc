/* TempleOS entry point for the Lua runtime. */

#include "../platform/templeos/lua_runtime.hc"

U0 LuaTempleOSMain() {
  LuaRuntime runtime;
  LuaRuntimeInit(&runtime);
  LuaPlatformWriteLine("Lua para HolyC: runtime em inicializacao");
  LuaRuntimeShutdown(&runtime);
}

LuaTempleOSMain();
