/* TempleOS entry point for the Lua runtime. */

#include "../platform/templeos/lua_state.hc"

U0 LuaTempleOSMain() {
  LuaRuntime runtime;
  LuaState state;
  LuaRuntimeInit(&runtime);
  LuaStateInit(&state, &runtime);
  LuaStatePushInteger(&state, 5);
  LuaPlatformWriteLine("Lua para HolyC: runtime em inicializacao");
  LuaStateClose(&state);
  LuaRuntimeShutdown(&runtime);
}

LuaTempleOSMain();
