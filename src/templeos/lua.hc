/* TempleOS entry point for the Lua runtime. */

#include "../platform/templeos/lua_gc.hc"

U0 LuaTempleOSMain() {
  LuaRuntime runtime;
  LuaState state;
  LuaTable table;
  LuaGc gc;
  LuaRuntimeInit(&runtime);
  LuaStateInit(&state, &runtime);
  LuaStatePushInteger(&state, 5);
  LuaTableInit(&table, &runtime);
  LuaGcInit(&gc, &runtime);
  LuaGcSetRoots(&gc, &state, &table);
  LuaPlatformWriteLine("Lua para HolyC: runtime em inicializacao");
  LuaStateClose(&state);
  LuaTableClose(&table);
  LuaGcClose(&gc);
  LuaRuntimeShutdown(&runtime);
}

LuaTempleOSMain();
