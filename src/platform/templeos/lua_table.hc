/* Integer-key table used as the first table implementation of the HolyC VM. */

#include "lua_state.hc"

class LuaTableEntry {
  Bool used;
  U8 key_type;
  I64 key;
  LuaString *string_key;
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

I64 LuaTableHashString(LuaString *key, I64 capacity) {
  return key->hash % capacity;
}

U0 LuaTableEntriesInit(LuaTableEntry *entries, I64 capacity) {
  I64 i;
  for (i = 0; i < capacity; i++) {
    entries[i].used = FALSE;
    entries[i].key_type = LUA_HC_NIL;
    entries[i].key = 0;
    entries[i].string_key = NULL;
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
    if (old_entries[i].key_type == LUA_HC_STRING)
      slot = LuaTableHashString(old_entries[i].string_key, new_capacity);
    else
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
    table->entries[slot].key_type = LUA_HC_INTEGER;
    table->entries[slot].key = key;
    table->count++;
  }
  LuaValueAssign(&table->entries[slot].value, value);
  return TRUE;
}

Bool LuaTableSetString(LuaTable *table, LuaString *key, LuaValue *value) {
  I64 slot;
  if (!key) return FALSE;
  if (table->capacity == 0 && !LuaTableRehash(table, 8)) return FALSE;
  if ((table->count + 1) * 10 >= table->capacity * 7) {
    if (!LuaTableRehash(table, table->capacity * 2)) return FALSE;
  }
  slot = LuaTableHashString(key, table->capacity);
  while (table->entries[slot].used &&
      !(table->entries[slot].key_type == LUA_HC_STRING &&
        LuaStringEqual(table->entries[slot].string_key, key)))
    slot = (slot + 1) % table->capacity;
  if (!table->entries[slot].used) {
    table->entries[slot].used = TRUE;
    table->entries[slot].key_type = LUA_HC_STRING;
    table->entries[slot].string_key = key;
    LuaStringRetain(key);
    table->count++;
  }
  LuaValueAssign(&table->entries[slot].value, value);
  return TRUE;
}

Bool LuaTableGetString(LuaTable *table, LuaString *key, LuaValue *value) {
  I64 slot;
  I64 probes;
  if (!key || !table->capacity) return FALSE;
  slot = LuaTableHashString(key, table->capacity);
  for (probes = 0; probes < table->capacity; probes++) {
    if (!table->entries[slot].used) return FALSE;
    if (table->entries[slot].key_type == LUA_HC_STRING &&
        LuaStringEqual(table->entries[slot].string_key, key)) {
      LuaValueAssign(value, &table->entries[slot].value);
      return TRUE;
    }
    slot = (slot + 1) % table->capacity;
  }
  return FALSE;
}

Bool LuaTableGetInteger(LuaTable *table, I64 key, LuaValue *value) {
  I64 slot;
  I64 probes;
  if (!table->capacity) return FALSE;
  slot = LuaTableHash(key, table->capacity);
  for (probes = 0; probes < table->capacity; probes++) {
    if (!table->entries[slot].used) return FALSE;
    if (table->entries[slot].key == key) {
      LuaValueAssign(value, &table->entries[slot].value);
      return TRUE;
    }
    slot = (slot + 1) % table->capacity;
  }
  return FALSE;
}

U0 LuaTableClose(LuaTable *table) {
  I64 i;
  for (i = 0; i < table->capacity; i++) {
    if (!table->entries[i].used) continue;
    LuaValueRelease(&table->entries[i].value);
    if (table->entries[i].key_type == LUA_HC_STRING)
      LuaStringRelease(table->entries[i].string_key);
  }
  if (table->entries)
    LuaPlatformFree(table->entries(U8 *));
  table->entries = NULL;
  table->capacity = 0;
  table->count = 0;
}
