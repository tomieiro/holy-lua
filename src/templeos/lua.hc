/* TempleOS entry point for the Lua runtime. */

#include "../platform/templeos/lua_table.hc"

U0 LuaTempleOSMain() {
  LuaRuntime runtime;
  LuaState state;
  LuaTable table;
  LuaRuntimeInit(&runtime);
  LuaStateInit(&state, &runtime);
  LuaStatePushInteger(&state, 5);
  LuaTableInit(&table, &runtime);
  LuaPlatformWriteLine("Lua para HolyC: runtime em inicializacao");
  LuaStateClose(&state);
  LuaTableClose(&table);
  LuaRuntimeShutdown(&runtime);
}

LuaTempleOSMain();
