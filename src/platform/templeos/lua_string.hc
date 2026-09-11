/* Lua string object for the HolyC runtime. */

#include "lua_runtime.hc"

class LuaString {
  LuaRuntime *runtime;
  I64 length;
  U64 hash;
  I64 references;
  LuaString *next_interned;
  U8 *data;
};

U64 LuaStringHash(U8 *data, I64 length) {
  U64 hash;
  I64 i;
  hash = 5381;
  for (i = 0; i < length; i++)
    hash = ((hash << 5) + hash) ^ data[i];
  return hash;
}

LuaString *LuaStringNew(LuaRuntime *runtime, U8 *data, I64 length) {
  LuaString *string;
  if (length < 0) return NULL;
  string = LuaRuntimeAlloc(runtime, sizeof(LuaString))(LuaString *);
  if (!string) return NULL;
  string->runtime = runtime;
  string->length = length;
  string->references = 1;
  string->next_interned = NULL;
  string->data = LuaRuntimeAlloc(runtime, length + 1);
  if (!string->data) {
    LuaRuntimeFree(runtime, string(U8 *), sizeof(LuaString));
    return NULL;
  }
  if (length) MemCpy(string->data, data, length);
  string->data[length] = 0;
  string->hash = LuaStringHash(string->data, length);
  return string;
}

LuaString *LuaStringNewZ(LuaRuntime *runtime, U8 *data) {
  return LuaStringNew(runtime, data, StrLen(data));
}

Bool LuaStringEqual(LuaString *left, LuaString *right) {
  I64 i;
  if (!left || !right || left->length != right->length) return FALSE;
  if (left->hash != right->hash) return FALSE;
  for (i = 0; i < left->length; i++)
    if (left->data[i] != right->data[i]) return FALSE;
  return TRUE;
}

U0 LuaStringRetain(LuaString *string) {
  if (string) string->references++;
}

U0 LuaStringRelease(LuaString *string) {
  if (!string) return;
  string->references--;
  if (string->references > 0) return;
  LuaRuntimeFree(string->runtime, string->data, string->length + 1);
  LuaRuntimeFree(string->runtime, string(U8 *), sizeof(LuaString));
}

class LuaStringPool {
  LuaRuntime *runtime;
  LuaString *head;
  I64 count;
};

U0 LuaStringPoolInit(LuaStringPool *pool, LuaRuntime *runtime) {
  pool->runtime = runtime;
  pool->head = NULL;
  pool->count = 0;
}

LuaString *LuaStringIntern(LuaStringPool *pool, U8 *data, I64 length) {
  LuaString *current;
  LuaString *string;
  I64 i;
  U64 hash;
  hash = LuaStringHash(data, length);
  for (current = pool->head; current; current = current->next_interned) {
    if (current->length != length || current->hash != hash) continue;
    for (i = 0; i < length; i++)
      if (current->data[i] != data[i]) break;
    if (i == length) {
      LuaStringRetain(current);
      return current;
    }
  }
  string = LuaStringNew(pool->runtime, data, length);
  if (!string) return NULL;
  LuaStringRetain(string); /* reference held by pool */
  string->next_interned = pool->head;
  pool->head = string;
  pool->count++;
  return string;
}

LuaString *LuaStringInternZ(LuaStringPool *pool, U8 *data) {
  return LuaStringIntern(pool, data, StrLen(data));
}

U0 LuaStringPoolClose(LuaStringPool *pool) {
  LuaString *current;
  LuaString *next;
  for (current = pool->head; current; current = next) {
    next = current->next_interned;
    current->next_interned = NULL;
    LuaStringRelease(current);
  }
  pool->head = NULL;
  pool->count = 0;
}
