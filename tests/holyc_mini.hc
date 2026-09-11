/* End-to-end smoke test for the first executable Lua nucleus. */

#include "../src/platform/templeos/lua_mini.hc"

U0 main() {
  F64 result;
  result = LuaMiniEval("return 2 + 3 * (4 - 1)");
  if (result != 11) throw(1);
  result = LuaMiniEval("10 / 2 + 0.5");
  if (result != 5.5) throw(2);
  result = LuaMiniRun("x = 4; y = x * 3; return y + 1");
  if (result != 13) throw(3);
}
