/* Lifetime owner for the HolyC Lua runtime. */

#include "lua_memory.hc"
#include "lua_exceptions.hc"

class LuaRuntime {
  LuaMemory memory;
  Bool initialized;
};

U0 LuaRuntimeInit(LuaRuntime *runtime) {
  LuaMemoryInit(&runtime->memory);
  runtime->initialized = TRUE;
  LuaPlatformInit();
}

U0 LuaRuntimeShutdown(LuaRuntime *runtime) {
  if (!runtime->initialized) return;
  runtime->initialized = FALSE;
  LuaPlatformShutdown();
}

U8 *LuaRuntimeAlloc(LuaRuntime *runtime, I64 size) {
  return LuaMemoryAlloc(&runtime->memory, size);
}

U8 *LuaRuntimeRealloc(LuaRuntime *runtime, U8 *ptr, I64 old_size, I64 new_size) {
  return LuaMemoryRealloc(&runtime->memory, ptr, old_size, new_size);
}

U0 LuaRuntimeFree(LuaRuntime *runtime, U8 *ptr, I64 size) {
  LuaMemoryFree(&runtime->memory, ptr, size);
}

I64 LuaRuntimeRunProtected(LuaRuntime *runtime,
    U0 (*function)(U0 *userdata), U0 *userdata) {
  if (!runtime->initialized) return -1;
  return LuaPlatformRunProtected(function, userdata);
}

I64 LuaRuntimeBytes(LuaRuntime *runtime) {
  return LuaMemoryBytes(&runtime->memory);
}

