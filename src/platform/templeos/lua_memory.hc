/* Allocator used by the HolyC Lua runtime. */

#include "templeos_api.hc"

class LuaMemory {
  I64 bytes;
  I64 allocations;
};

U0 LuaMemoryInit(LuaMemory *memory) {
  memory->bytes = 0;
  memory->allocations = 0;
}

U8 *LuaMemoryAlloc(LuaMemory *memory, I64 size) {
  U8 *ptr;
  if (size <= 0) return NULL;
  ptr = LuaPlatformAlloc(size);
  if (ptr) {
    memory->bytes += size;
    memory->allocations++;
  }
  return ptr;
}

U8 *LuaMemoryRealloc(LuaMemory *memory, U8 *ptr, I64 old_size, I64 new_size) {
  U8 *fresh;
  fresh = LuaPlatformRealloc(ptr, old_size, new_size);
  if (new_size <= 0) {
    if (ptr) {
      memory->bytes -= old_size;
      memory->allocations--;
    }
  } else if (fresh) {
    memory->bytes += new_size - old_size;
    if (!ptr) memory->allocations++;
  }
  return fresh;
}

U0 LuaMemoryFree(LuaMemory *memory, U8 *ptr, I64 size) {
  if (!ptr) return;
  LuaPlatformFree(ptr);
  memory->bytes -= size;
  memory->allocations--;
}

I64 LuaMemoryBytes(LuaMemory *memory) {
  return memory->bytes;
}
