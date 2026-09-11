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
  result = LuaMiniEval("abs(-8) + sqrt(9) + len(\"abc\")");
  if (result != 14) throw(4);
  result = LuaMiniRun("if 3 > 2 then return 9 end");
  if (result != 9) throw(5);
  result = LuaMiniRun("if 1 > 2 then return 9 else return 6 end");
  if (result != 6) throw(6);
}
