/* Native closures and call frames for the HolyC Lua runtime. */

#include "lua_state.hc"

class LuaClosure {
  LuaRuntime *runtime;
  U0 (*function)(LuaState *state, I64 *result);
  LuaString *name;
};

class LuaCallFrame {
  LuaClosure *closure;
  I64 base;
  I64 top;
};

class LuaCallStack {
  LuaRuntime *runtime;
  LuaCallFrame *frames;
  I64 count;
  I64 capacity;
};

U0 LuaClosureInit(LuaClosure *closure, LuaRuntime *runtime,
    U0 (*function)(LuaState *state, I64 *result), LuaString *name) {
  closure->runtime = runtime;
  closure->function = function;
  closure->name = name;
  LuaStringRetain(name);
}

U0 LuaClosureClose(LuaClosure *closure) {
  LuaStringRelease(closure->name);
  closure->name = NULL;
  closure->function = NULL;
}

U0 LuaCallStackInit(LuaCallStack *calls, LuaRuntime *runtime) {
  calls->runtime = runtime;
  calls->frames = NULL;
  calls->count = 0;
  calls->capacity = 0;
}

Bool LuaCallStackPush(LuaCallStack *calls, LuaClosure *closure,
    I64 base, I64 top) {
  I64 old_size;
  I64 new_capacity;
  LuaCallFrame *fresh;
  if (calls->count >= calls->capacity) {
    new_capacity = calls->capacity * 2;
    if (!new_capacity) new_capacity = 4;
    old_size = calls->capacity * sizeof(LuaCallFrame);
    fresh = LuaRuntimeRealloc(calls->runtime, calls->frames(U8 *), old_size,
        new_capacity * sizeof(LuaCallFrame))(LuaCallFrame *);
    if (!fresh) return FALSE;
    calls->frames = fresh;
    calls->capacity = new_capacity;
  }
  calls->frames[calls->count].closure = closure;
  calls->frames[calls->count].base = base;
  calls->frames[calls->count].top = top;
  calls->count++;
  return TRUE;
}

U0 LuaCallStackPop(LuaCallStack *calls) {
  if (calls->count) calls->count--;
}

U0 LuaCallStackClose(LuaCallStack *calls) {
  if (calls->frames)
    LuaRuntimeFree(calls->runtime, calls->frames(U8 *),
        calls->capacity * sizeof(LuaCallFrame));
  calls->frames = NULL;
  calls->count = 0;
  calls->capacity = 0;
}

class LuaCallContext {
  LuaClosure *closure;
  LuaState *state;
  I64 result;
};

U0 LuaCallInvoke(U0 *userdata) {
  LuaCallContext *context;
  context = userdata(LuaCallContext *);
  context->closure->function(context->state, &context->result);
}

I64 LuaCall(LuaCallStack *calls, LuaState *state, LuaClosure *closure) {
  LuaCallContext context;
  I64 status;
  if (!LuaCallStackPush(calls, closure, 0, state->top)) return -1;
  context.closure = closure;
  context.state = state;
  context.result = 0;
  status = LuaPlatformRunProtected(&LuaCallInvoke, &context);
  LuaCallStackPop(calls);
  if (status) return status;
  return context.result;
}
