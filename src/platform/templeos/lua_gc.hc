/* Root-aware collection facade for the first HolyC Lua runtime. */

#include "lua_table.hc"

class LuaGc {
  LuaRuntime *runtime;
  LuaStringPool strings;
  LuaState *state_root;
  LuaTable *table_root;
};

U0 LuaGcInit(LuaGc *gc, LuaRuntime *runtime) {
  gc->runtime = runtime;
  LuaStringPoolInit(&gc->strings, runtime);
  gc->state_root = NULL;
  gc->table_root = NULL;
}

U0 LuaGcSetRoots(LuaGc *gc, LuaState *state, LuaTable *table) {
  gc->state_root = state;
  gc->table_root = table;
}

I64 LuaGcCollect(LuaGc *gc) {
  /* Stack and table values retain their strings; the pool owns the other root. */
  return LuaStringPoolCollect(&gc->strings);
}

U0 LuaGcClose(LuaGc *gc) {
  LuaStringPoolClose(&gc->strings);
  gc->state_root = NULL;
  gc->table_root = NULL;
}

