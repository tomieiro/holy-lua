/* Smoke test for the HolyC Lua string-key table. */

#include "../src/platform/templeos/lua_table.hc"

U0 main() {
  LuaRuntime runtime;
  LuaTable table;
  LuaStringPool pool;
  LuaString *key;
  LuaString *dead;
  LuaValue value;
  LuaValue found;

  LuaRuntimeInit(&runtime);
  LuaTableInit(&table, &runtime);
  LuaStringPoolInit(&pool, &runtime);
  LuaValueNil(&value);
  value.type = LUA_HC_INTEGER;
  value.integer = 42;
  key = LuaStringInternZ(&pool, "answer");
  dead = LuaStringInternZ(&pool, "temporary");
  LuaStringRelease(dead);
  if (LuaStringPoolCollect(&pool) != 1) throw(3);
  if (key == NULL) throw(1);
  if (!LuaTableSetString(&table, key, &value)) throw(1);
  LuaValueNil(&found);
  if (!LuaTableGetString(&table, key, &found)) throw(2);
  if (found.integer != 42) throw(2);
  LuaValueRelease(&found);
  LuaStringRelease(key);
  LuaTableClose(&table);
  LuaStringPoolClose(&pool);
  LuaRuntimeShutdown(&runtime);
}
