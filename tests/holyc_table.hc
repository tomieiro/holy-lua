/* Smoke test for the HolyC Lua string-key table. */

#include "../src/platform/templeos/lua_table.hc"

U0 main() {
  LuaRuntime runtime;
  LuaTable table;
  LuaString *key;
  LuaValue value;
  LuaValue found;

  LuaRuntimeInit(&runtime);
  LuaTableInit(&table, &runtime);
  LuaValueNil(&value);
  value.type = LUA_HC_INTEGER;
  value.integer = 42;
  key = LuaStringNewZ(&runtime, "answer");
  if (key == NULL) throw(1);
  if (!LuaTableSetString(&table, key, &value)) throw(1);
  LuaValueNil(&found);
  if (!LuaTableGetString(&table, key, &found)) throw(2);
  if (found.integer != 42) throw(2);
  LuaValueRelease(&found);
  LuaStringRelease(key);
  LuaTableClose(&table);
  LuaRuntimeShutdown(&runtime);
}
