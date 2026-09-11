/* End-to-end smoke test for the first executable Lua nucleus. */

#include "../src/platform/templeos/lua_mini.hc"

U0 Triple(F64 argument, F64 *result) {
  *result = argument * 3;
}

I64 g_call_count;
U0 CountedTriple(F64 argument, F64 *result) {
  g_call_count++;
  *result = argument * 3;
}

U0 LuaMiniGeneralValues(LuaMiniRegistry *registry);
U0 LuaMiniFunctionTests();

U0 main() {
  F64 result;
  LuaMiniRegistry registry;
  LuaMiniRegistryInit(&registry);
  LuaMiniRegister(&registry, "triple", &Triple);
  LuaMiniRegister(&registry, "countedTriple", &CountedTriple);
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

  LuaMiniGeneralValues(&registry);
  LuaMiniFunctionTests();
}

/* General Lua values: strings, booleans, nil, concatenation, and/or,
   comparisons as expressions, type()/print(), and bare call statements. */
U0 LuaMiniGeneralValues(LuaMiniRegistry *registry) {
  LuaMiniValue value;
  F64 result;

  value = LuaMiniEvalValue("\"hello\" .. \" \" .. \"world\"");
  if (value.type != MINI_STRING) throw(35);
  if (!LuaMiniNameEqual(value.text, "hello world")) throw(35);

  value = LuaMiniEvalValue("\"x=\" .. 5");
  if (value.type != MINI_STRING) throw(36);
  if (!LuaMiniNameEqual(value.text, "x=5")) throw(36);

  value = LuaMiniEvalValue("true");
  if (value.type != MINI_BOOL || !value.boolean) throw(37);
  value = LuaMiniEvalValue("false");
  if (value.type != MINI_BOOL || value.boolean) throw(37);
  value = LuaMiniEvalValue("nil");
  if (value.type != MINI_NIL) throw(38);

  value = LuaMiniEvalValue("1 == 1");
  if (value.type != MINI_BOOL || !value.boolean) throw(39);
  value = LuaMiniEvalValue("\"a\" == \"a\"");
  if (value.type != MINI_BOOL || !value.boolean) throw(39);
  value = LuaMiniEvalValue("\"a\" == \"b\"");
  if (value.type != MINI_BOOL || value.boolean) throw(39);
  value = LuaMiniEvalValue("1 == \"1\"");
  if (value.type != MINI_BOOL || value.boolean) throw(40); /* no coercion */

  value = LuaMiniEvalValue("type(5)");
  if (!LuaMiniNameEqual(value.text, "number")) throw(41);
  value = LuaMiniEvalValue("type(\"x\")");
  if (!LuaMiniNameEqual(value.text, "string")) throw(41);
  value = LuaMiniEvalValue("type(true)");
  if (!LuaMiniNameEqual(value.text, "boolean")) throw(41);
  value = LuaMiniEvalValue("type(nil)");
  if (!LuaMiniNameEqual(value.text, "nil")) throw(41);

  value = LuaMiniEvalValue("#\"hello\"");
  if (value.type != MINI_NUMBER || value.number != 5) throw(42);

  value = LuaMiniEvalValue("true and 5");
  if (value.type != MINI_NUMBER || value.number != 5) throw(43);
  value = LuaMiniEvalValue("false and 5");
  if (value.type != MINI_BOOL || value.boolean) throw(43);
  value = LuaMiniEvalValue("nil or 7");
  if (value.type != MINI_NUMBER || value.number != 7) throw(44);
  value = LuaMiniEvalValue("3 or 7");
  if (value.type != MINI_NUMBER || value.number != 3) throw(44);

  result = LuaMiniEval("(1 == 1 and 2 or 3) + 10");
  if (result != 12) throw(45);
  result = LuaMiniRun("x = 5; if x > 0 and x < 10 then return 1 end return 0");
  if (result != 1) throw(46);
  result = LuaMiniRun("n = 1 == 2 or 3 == 3; if n then return 1 end return 0");
  if (result != 1) throw(47);

  /* `and`/`or` short-circuit: the untaken side's native call must not run. */
  g_call_count = 0;
  value = LuaMiniRunWithRegistryValue(
      "n = false and countedTriple(999); return n", registry);
  if (LuaMiniTruthy(value)) throw(48);
  if (g_call_count != 0) throw(48);
  value = LuaMiniRunWithRegistryValue(
      "n = true or countedTriple(999); return n", registry);
  if (!LuaMiniTruthy(value)) throw(48);
  if (g_call_count != 0) throw(48);
  result = LuaMiniRunWithRegistry("return countedTriple(2)", registry);
  if (result != 6) throw(48);
  if (g_call_count != 1) throw(48);

  result = LuaMiniRun(
      "s = \"\"; for i = 1, 3 do s = s .. i .. \",\" end print(s) return #s");
  if (result != 6) throw(49);

  value = LuaMiniEvalValue("1 <= 1 and 2 >= 2 and 1 ~= 2");
  if (value.type != MINI_BOOL || !value.boolean) throw(50);
}

/* User-defined functions, including real recursion through the host C
   stack, and calling an undefined name as an error. */
U0 LuaMiniFunctionTests() {
  F64 result;
  LuaMiniValue value;

  result = LuaMiniRun("function square(x) return x * x end return square(7)");
  if (result != 49) throw(51);

  result = LuaMiniRun(
      "function fact(n) if n <= 1 then return 1 end "
      "return n * fact(n - 1) end return fact(10)");
  if (result != 3628800) throw(52);

  result = LuaMiniRun(
      "function fib(n) if n < 2 then return n end "
      "return fib(n - 1) + fib(n - 2) end return fib(15)");
  if (result != 610) throw(53);

  result = LuaMiniRun("function add(a, b) return a + b end "
      "return add(3, 4) + add(10, 20)");
  if (result != 37) throw(54);

  value = LuaMiniRunValue("function greet(name) return \"hi \" .. name end "
      "return greet(\"lua\")");
  if (value.type != MINI_STRING) throw(55);
  if (!LuaMiniNameEqual(value.text, "hi lua")) throw(55);

  result = LuaMiniRun("function noargs() return 42 end return noargs()");
  if (result != 42) throw(56);

  /* A function body can assign to globals, and a missing argument reads
     as nil. */
  result = LuaMiniRun("s = 0; function addTo(x) s = s + x end "
      "for i = 1, 5 do addTo(i) end return s");
  if (result != 15) throw(57);
  value = LuaMiniRunValue(
      "function isNil(x) return x == nil end return isNil()");
  if (value.type != MINI_BOOL || !value.boolean) throw(58);

  /* Calling an unrecognized name is a clean error (12), not a parse
     failure from misreading its argument list. */
  {
    Bool caught;
    caught = FALSE;
    try {
      LuaMiniRun("function f() return 1 end return notdefined()");
    } catch {
      caught = TRUE;
    }
    if (!caught) throw(59);
  }
}
