/* Lua string object for the HolyC runtime. */

#include "lua_runtime.hc"

class LuaString {
  LuaRuntime *runtime;
  I64 length;
  U64 hash;
  I64 references;
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
