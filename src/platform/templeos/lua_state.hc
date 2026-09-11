/* Minimal HolyC representation of Lua values and the Lua stack. */

#include "lua_runtime.hc"
#include "lua_string.hc"

#define LUA_HC_NIL 0
#define LUA_HC_BOOLEAN 1
#define LUA_HC_INTEGER 2
#define LUA_HC_NUMBER 3
#define LUA_HC_STRING 4

class LuaValue {
  U8 type;
  Bool boolean;
  I64 integer;
  F64 number;
  LuaString *string;
};

class LuaState {
  LuaRuntime *runtime;
  LuaValue *stack;
  I64 top;
  I64 capacity;
};

Bool LuaStateGrow(LuaState *state, I64 wanted);

U0 LuaValueNil(LuaValue *value) {
  value->type = LUA_HC_NIL;
  value->boolean = FALSE;
  value->integer = 0;
  value->number = 0;
  value->string = NULL;
}

U0 LuaValueRelease(LuaValue *value) {
  if (value->type == LUA_HC_STRING)
    LuaStringRelease(value->string);
  LuaValueNil(value);
}

U0 LuaValueSetString(LuaValue *value, LuaString *string) {
  LuaValueRelease(value);
  value->type = LUA_HC_STRING;
  value->string = string;
  LuaStringRetain(string);
}

Bool LuaStatePushString(LuaState *state, LuaString *string) {
  if (!LuaStateGrow(state, state->top + 1)) return FALSE;
  LuaValueNil(&state->stack[state->top]);
  LuaValueSetString(&state->stack[state->top], string);
  state->top++;
  return TRUE;
}

U0 LuaStateInit(LuaState *state, LuaRuntime *runtime) {
  state->runtime = runtime;
  state->stack = NULL;
  state->top = 0;
  state->capacity = 0;
}

Bool LuaStateGrow(LuaState *state, I64 wanted) {
  I64 old_size;
  I64 new_capacity;
  LuaValue *fresh;
  if (wanted <= state->capacity) return TRUE;
  new_capacity = state->capacity;
  if (new_capacity < 8) new_capacity = 8;
  while (new_capacity < wanted) new_capacity *= 2;
  old_size = state->capacity * sizeof(LuaValue);
  fresh = LuaRuntimeRealloc(state->runtime, state->stack(U8 *), old_size,
      new_capacity * sizeof(LuaValue))(LuaValue *);
  if (!fresh) return FALSE;
  state->stack = fresh;
  state->capacity = new_capacity;
  return TRUE;
}

Bool LuaStatePushInteger(LuaState *state, I64 integer) {
  if (!LuaStateGrow(state, state->top + 1)) return FALSE;
  state->stack[state->top].type = LUA_HC_INTEGER;
  state->stack[state->top].integer = integer;
  state->top++;
  return TRUE;
}

Bool LuaStatePushNumber(LuaState *state, F64 number) {
  if (!LuaStateGrow(state, state->top + 1)) return FALSE;
  state->stack[state->top].type = LUA_HC_NUMBER;
  state->stack[state->top].number = number;
  state->top++;
  return TRUE;
}

Bool LuaStatePop(LuaState *state, LuaValue *value) {
  if (state->top <= 0) return FALSE;
  state->top--;
  *value = state->stack[state->top];
  LuaValueNil(&state->stack[state->top]);
  return TRUE;
}

U0 LuaStateClose(LuaState *state) {
  I64 i;
  for (i = 0; i < state->top; i++)
    LuaValueRelease(&state->stack[i]);
  if (state->stack)
    LuaRuntimeFree(state->runtime, state->stack(U8 *),
        state->capacity * sizeof(LuaValue));
  state->stack = NULL;
  state->top = 0;
  state->capacity = 0;
}
