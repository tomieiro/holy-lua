/* Lua platform boundary for TempleOS. Keep OS-specific names here. */

#include "/usr/local/include/tos.HH"

U0 LuaPlatformInit() { }
U0 LuaPlatformShutdown() { }

U8 *LuaPlatformAlloc(I64 size) {
  if (size <= 0) return NULL;
  return MAlloc(size);
}

U8 *LuaPlatformRealloc(U8 *old, I64 old_size, I64 new_size) {
  U8 *fresh;
  I64 copy_size;
  if (new_size <= 0) {
    if (old) Free(old);
    return NULL;
  }
  fresh = MAlloc(new_size);
  if (!fresh) return NULL;
  if (old) {
    copy_size = old_size;
    if (new_size < copy_size) copy_size = new_size;
    MemCpy(fresh, old, copy_size);
    Free(old);
  }
  return fresh;
}

U0 LuaPlatformFree(U8 *ptr) {
  if (ptr) Free(ptr);
}

U0 LuaPlatformWrite(U8 *text) {
  if (text) printf("%s", text);
}

U0 LuaPlatformWriteLine(U8 *text) {
  LuaPlatformWrite(text);
  printf("\n");
}

U8 *LuaPlatformReadFile(U8 *name, I64 *size) {
  return FileRead(name, size);
}

Bool LuaPlatformWriteFile(U8 *name, U8 *data, I64 size) {
  return FileWrite(name, data, size);
}

I64 LuaPlatformTicks() {
  return NowMilliseconds();
}
