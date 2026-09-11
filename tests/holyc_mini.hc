/* End-to-end smoke test for the first executable Lua nucleus. */

#include "../src/platform/templeos/lua_mini.hc"

U0 Triple(F64 argument, F64 *result) {
  *result = argument * 3;
}

U0 main() {
  F64 result;
  LuaMiniRegistry registry;
  LuaMiniRegistryInit(&registry);
  LuaMiniRegister(&registry, "triple", &Triple);
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
  result = LuaMiniEvalWithRegistry("triple(4)", &registry);
  if (result != 12) throw(7);
  result = LuaMiniRunWithRegistry("return triple(5)", &registry);
  if (result != 15) throw(8);
  result = LuaMiniRun("local s = 0; for i = 1, 10 do s = s + i end return s");
  if (result != 55) throw(9);
  result = LuaMiniRun("n = 1; while n < 100 do n = n * 2 end return n");
  if (result != 128) throw(10);
  result = LuaMiniRun("s = 0; for i = 10, 1, -3 do s = s + i end return s");
  if (result != 22) throw(11);
  result = LuaMiniRun(
      "s = 0; for i = 1, 5 do if i >= 3 then s = s + i else s = s - 1 end end "
      "return s");
  if (result != 10) throw(12);
  result = LuaMiniRun("for i = 1, 9 do if i == 4 then return i * 10 end end "
      "return 0");
  if (result != 40) throw(13);
  result = LuaMiniRun("for i = 5, 1 do return 1 / 0 end return 7");
  if (result != 7) throw(14);
  result = LuaMiniRun("if 1 ~= 1 then return 1 end if 2 <= 2 then return 2 end "
      "return 3");
  if (result != 2) throw(15);
  result = LuaMiniRun("x = 5; if x < 3 then return 1 elseif x < 6 then "
      "return 2 elseif x < 9 then return 3 else return 4 end");
  if (result != 2) throw(16);
  result = LuaMiniRun("x = 9; if x < 3 then return 1 elseif x < 6 then "
      "return 2 else return 4 end");
  if (result != 4) throw(17);
  result = LuaMiniRun("s = 0; for i = 1, 100 do if i > 4 then break end "
      "s = s + i end return s");
  if (result != 10) throw(18);
  result = LuaMiniRun("n = 0; while 1 < 2 do n = n + 1; if n == 7 then "
      "break end end return n");
  if (result != 7) throw(19);
  result = LuaMiniRun("t = 0; for i = 1, 3 do for j = 1, 10 do if j > i then "
      "break end t = t + 1 end end return t");
  if (result != 6) throw(20);
  result = LuaMiniRun("local x = 1; if x > 0 then local x = 5; x = x + 1 end "
      "return x");
  if (result != 1) throw(21);
  result = LuaMiniRun("x = 1; if x > 0 then x = 5 end return x");
  if (result != 5) throw(22);
  result = LuaMiniRun("i = 100; for i = 1, 3 do end return i");
  if (result != 100) throw(23);
  result = LuaMiniRun("s = 0; for i = 1, 20 do local d = i * 2; s = s + d end "
      "return s");
  if (result != 420) throw(24);
  result = LuaMiniEval("17 % 5");
  if (result != 2) throw(25);
  result = LuaMiniEval("return -1 % 5");
  if (result != 4) throw(26);
  result = LuaMiniRun("m = 0; for i = 1, 20 do m = i % 3 end return m");
  if (result != 2) throw(27);
  result = LuaMiniRun("n = 0; repeat n = n + 1 until n >= 5 return n");
  if (result != 5) throw(28);
  result = LuaMiniRun("n = 0; repeat n = n + 1 until 1 == 1 return n");
  if (result != 1) throw(29);
  result = LuaMiniRun(
      "s = 0; i = 0; repeat i = i + 1; if i > 3 then break end s = s + i "
      "until i >= 100 return s");
  if (result != 6) throw(30);
  result = LuaMiniRun("n = 0; repeat n = n + 1; if n == 4 then return n end "
      "until 1 == 2 return -1");
  if (result != 4) throw(31);
  result = LuaMiniRun(
      "n = 0; ::top:: n = n + 1; if n < 5 then goto top end return n");
  if (result != 5) throw(32);
  result = LuaMiniRun("n = 5; goto skip n = 100 ::skip:: return n");
  if (result != 5) throw(33);
  result = LuaMiniRun("s = 0; for i = 1, 10 do if i == 5 then goto done end "
      "s = s + i end ::done:: return s");
  if (result != 10) throw(34);
}
