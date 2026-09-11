/* Integer-key table used as the first table implementation of the HolyC VM. */

#include "lua_state.hc"

class LuaTableEntry {
  Bool used;
  I64 key;
  LuaValue value;
};

class LuaTable {
  LuaRuntime *runtime;
  LuaTableEntry *entries;
  I64 capacity;
  I64 count;
};

I64 LuaTableHash(I64 key, I64 capacity) {
  return (key & 0x7fffffffffffffff) % capacity;
}

U0 LuaTableEntriesInit(LuaTableEntry *entries, I64 capacity) {
  I64 i;
  for (i = 0; i < capacity; i++) {
    entries[i].used = FALSE;
    entries[i].key = 0;
    LuaValueNil(&entries[i].value);
  }
}

U0 LuaTableInit(LuaTable *table, LuaRuntime *runtime) {
  table->runtime = runtime;
  table->entries = NULL;
  table->capacity = 0;
  table->count = 0;
}

Bool LuaTableRehash(LuaTable *table, I64 new_capacity) {
  LuaTableEntry *old_entries;
  LuaTableEntry *fresh;
  I64 old_capacity;
  I64 i;
  I64 slot;

  fresh = LuaRuntimeRealloc(table->runtime, NULL, 0,
      new_capacity * sizeof(LuaTableEntry))(LuaTableEntry *);
  if (!fresh) return FALSE;
  LuaTableEntriesInit(fresh, new_capacity);

  old_entries = table->entries;
  old_capacity = table->capacity;
  table->entries = fresh;
  table->capacity = new_capacity;

  for (i = 0; i < old_capacity; i++) {
    if (!old_entries[i].used) continue;
    slot = LuaTableHash(old_entries[i].key, new_capacity);
    while (fresh[slot].used) slot = (slot + 1) % new_capacity;
    fresh[slot] = old_entries[i];
  }
  if (old_entries)
    LuaPlatformFree(old_entries(U8 *));
  return TRUE;
}

Bool LuaTableSetInteger(LuaTable *table, I64 key, LuaValue *value) {
  I64 slot;
  if (table->capacity == 0 && !LuaTableRehash(table, 8)) return FALSE;
  if ((table->count + 1) * 10 >= table->capacity * 7) {
    if (!LuaTableRehash(table, table->capacity * 2)) return FALSE;
  }
  slot = LuaTableHash(key, table->capacity);
  while (table->entries[slot].used && table->entries[slot].key != key)
    slot = (slot + 1) % table->capacity;
  if (!table->entries[slot].used) {
    table->entries[slot].used = TRUE;
    table->entries[slot].key = key;
    table->count++;
  }
  table->entries[slot].value = *value;
  return TRUE;
}

Bool LuaTableGetInteger(LuaTable *table, I64 key, LuaValue *value) {
  I64 slot;
  I64 probes;
  if (!table->capacity) return FALSE;
  slot = LuaTableHash(key, table->capacity);
  for (probes = 0; probes < table->capacity; probes++) {
    if (!table->entries[slot].used) return FALSE;
    if (table->entries[slot].key == key) {
      *value = table->entries[slot].value;
      return TRUE;
    }
    slot = (slot + 1) % table->capacity;
  }
  return FALSE;
}

U0 LuaTableClose(LuaTable *table) {
  if (table->entries)
    LuaPlatformFree(table->entries(U8 *));
  table->entries = NULL;
  table->capacity = 0;
  table->count = 0;
}

