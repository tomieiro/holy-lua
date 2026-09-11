/* Smoke test for HolyC closures and protected calls. */

#include "../src/platform/templeos/lua_call.hc"

U0 ReturnSeven(LuaState *state, I64 *result) {
  if (!LuaStatePushInteger(state, 7)) throw(9);
  *result = 1;
}

U0 main() {
  LuaRuntime runtime;
  LuaState state;
  LuaCallStack calls;
  LuaClosure closure;
  LuaValue value;
  I64 result;

  LuaRuntimeInit(&runtime);
  LuaStateInit(&state, &runtime);
  LuaCallStackInit(&calls, &runtime);
  LuaClosureInit(&closure, &runtime, &ReturnSeven, NULL);
  result = LuaCall(&calls, &state, &closure);
  if (result != 1) throw(1);
  if (!LuaStatePop(&state, &value) || value.integer != 7) throw(2);
  LuaValueRelease(&value);
  LuaClosureClose(&closure);
  LuaCallStackClose(&calls);
  LuaStateClose(&state);
  LuaRuntimeShutdown(&runtime);
}
