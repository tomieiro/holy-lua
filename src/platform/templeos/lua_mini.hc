/* Executable Lua nucleus: general values, expressions, statements, loops. */

#include "lua_state.hc"

Bool LuaMiniNameEqual(U8 *left, U8 *right);

class LuaMiniNative {
  U8 name[32];
  U0 (*function)(F64 argument, F64 *result);
};

class LuaMiniRegistry {
  LuaMiniNative natives[8];
  I64 count;
};

U0 LuaMiniRegistryInit(LuaMiniRegistry *registry) {
  registry->count = 0;
}

U0 LuaMiniRegister(LuaMiniRegistry *registry, U8 *name,
    U0 (*function)(F64 argument, F64 *result)) {
  if (registry->count >= 8) throw(20);
  MemCpy(registry->natives[registry->count].name, name, 31);
  registry->natives[registry->count].name[31] = 0;
  registry->natives[registry->count].function = function;
  registry->count++;
}

LuaMiniNative *LuaMiniFindNative(LuaMiniRegistry *registry, U8 *name) {
  I64 i;
  if (!registry) return NULL;
  for (i = 0; i < registry->count; i++)
    if (LuaMiniNameEqual(registry->natives[i].name, name))
      return &registry->natives[i];
  return NULL;
}

/* A general Lua value for the mini nucleus: nil, boolean, number, or an
   inline (heap-free) string up to 63 bytes. No tables or functions yet. */
#define MINI_NIL 0
#define MINI_BOOL 1
#define MINI_NUMBER 2
#define MINI_STRING 3

class LuaMiniValue {
  U8 type;
  Bool boolean;
  F64 number;
  U8 text[64];
};

LuaMiniValue LuaMiniNil() {
  LuaMiniValue v;
  v.type = MINI_NIL;
  v.boolean = FALSE;
  v.number = 0;
  v.text[0] = 0;
  return v;
}

LuaMiniValue LuaMiniBoolValue(Bool boolean) {
  LuaMiniValue v;
  v.type = MINI_BOOL;
  v.boolean = boolean;
  v.number = 0;
  v.text[0] = 0;
  return v;
}

LuaMiniValue LuaMiniNumberValue(F64 number) {
  LuaMiniValue v;
  v.type = MINI_NUMBER;
  v.boolean = FALSE;
  v.number = number;
  v.text[0] = 0;
  return v;
}

LuaMiniValue LuaMiniStringValue(U8 *text, I64 length) {
  LuaMiniValue v;
  v.type = MINI_STRING;
  v.boolean = FALSE;
  v.number = 0;
  if (length >= 64) length = 63;
  MemCpy(v.text, text, length);
  v.text[length] = 0;
  return v;
}

Bool LuaMiniTruthy(LuaMiniValue value) {
  if (value.type == MINI_NIL) return FALSE;
  if (value.type == MINI_BOOL) return value.boolean;
  return TRUE;
}

/* Structural equality: values of different types are never equal. */
Bool LuaMiniValueEqual(LuaMiniValue left, LuaMiniValue right) {
  if (left.type != right.type) return FALSE;
  if (left.type == MINI_NUMBER) return left.number == right.number;
  if (left.type == MINI_BOOL) return left.boolean == right.boolean;
  if (left.type == MINI_STRING) return LuaMiniNameEqual(left.text, right.text);
  return TRUE; /* both nil */
}

U0 LuaMiniIntToStr(I64 number, U8 *buf) {
  U8 digits[24];
  I64 i;
  I64 j;
  Bool negative;
  i = 0;
  negative = FALSE;
  if (number == 0) {
    buf[0] = '0';
    buf[1] = 0;
    return;
  }
  if (number < 0) {
    negative = TRUE;
    number = -number;
  }
  while (number > 0) {
    digits[i++] = '0' + number % 10;
    number /= 10;
  }
  j = 0;
  if (negative) buf[j++] = '-';
  while (i > 0) buf[j++] = digits[--i];
  buf[j] = 0;
}

/* Formats a number the way Lua prints one: an integer value has no decimal
   point; otherwise up to six fractional digits, trailing zeros trimmed. */
U0 LuaMiniFormatNumber(F64 number, U8 *buf) {
  Bool negative;
  I64 whole;
  F64 fraction;
  I64 scaled;
  I64 position;
  negative = FALSE;
  if (number < 0.0) negative = TRUE;
  if (negative) number = -number;
  whole = number(I64);
  fraction = number - whole;
  position = 0;
  if (negative) buf[position++] = '-';
  LuaMiniIntToStr(whole, buf + position);
  while (buf[position]) position++;
  scaled = (fraction * 1000000 + 0.5)(I64);
  if (scaled > 0) {
    U8 fraction_digits[24];
    I64 length;
    I64 padding;
    I64 significant;
    I64 k;
    LuaMiniIntToStr(scaled, fraction_digits);
    length = 0;
    while (fraction_digits[length]) length++;
    padding = 6 - length;
    significant = length;
    while (significant > 0 && fraction_digits[significant - 1] == '0')
      significant--;
    if (significant > 0) {
      buf[position++] = '.';
      for (k = 0; k < padding; k++) buf[position++] = '0';
      for (k = 0; k < significant; k++) buf[position++] = fraction_digits[k];
    }
  }
  buf[position] = 0;
}

/* Writes value's display form (as `print` and `..` would render it) into a
   64-byte buffer. */
U0 LuaMiniValueToBuf(LuaMiniValue value, U8 *buf) {
  if (value.type == MINI_NIL) {
    MemCpy(buf, "nil", 4);
    return;
  }
  if (value.type == MINI_BOOL) {
    if (value.boolean) MemCpy(buf, "true", 5);
    else MemCpy(buf, "false", 6);
    return;
  }
  if (value.type == MINI_STRING) {
    I64 length;
    length = 0;
    while (value.text[length]) length++;
    MemCpy(buf, value.text, length + 1);
    return;
  }
  LuaMiniFormatNumber(value.number, buf);
}

LuaMiniValue LuaMiniConcat(LuaMiniValue left, LuaMiniValue right) {
  U8 left_buf[64];
  U8 right_buf[64];
  U8 result[64];
  I64 left_length;
  I64 right_length;
  LuaMiniValue value;
  LuaMiniValueToBuf(left, left_buf);
  LuaMiniValueToBuf(right, right_buf);
  left_length = 0;
  while (left_buf[left_length]) left_length++;
  right_length = 0;
  while (right_buf[right_length]) right_length++;
  if (left_length > 63) left_length = 63;
  if (left_length + right_length > 63) right_length = 63 - left_length;
  MemCpy(result, left_buf, left_length);
  MemCpy(result + left_length, right_buf, right_length);
  result[left_length + right_length] = 0;
  /* hcc's JIT crashes on `return F();` when F returns a struct this big;
     materializing into a local first works around it. */
  value = LuaMiniStringValue(result, left_length + right_length);
  return value;
}

/* A user-defined function: `function name(a, b) ... end` at global scope.
   Only its body's text position is stored; calling it re-enters the
   recursive-descent parser at that position under a fresh local scope. */
class LuaMiniFunctionDef {
  U8 name[32];
  I64 body_position;
  I64 param_count;
  U8 param_names[8][32];
};

class LuaMiniParser {
  U8 *source;
  I64 position;
  I64 binding_count; /* locals form a stack; blocks pop back to a mark */
  LuaMiniRegistry *registry;
  /* Sized for real recursion: each call frame consumes one slot per
     parameter/local and is only popped when the call returns. */
  U8 names[64][32];
  LuaMiniValue values[64];
  I64 global_count;
  U8 global_names[16][32];
  LuaMiniValue global_values[16];
  I64 function_count;
  LuaMiniFunctionDef functions[8];
  I64 call_depth; /* recursion guard, shared with the real HolyC C stack */
  Bool skipping; /* parse without effects: dead branches, finished loops */
  Bool returned;
  Bool breaking;
  Bool jumping; /* an active goto, seeking its label */
  U8 jump_label[32];
  I64 loop_depth;
  LuaMiniValue result;
};

U0 LuaMiniSkip(LuaMiniParser *parser) {
  while (parser->source[parser->position] == ' ' ||
      parser->source[parser->position] == '\t' ||
      parser->source[parser->position] == '\n' ||
      parser->source[parser->position] == '\r')
    parser->position++;
}

LuaMiniValue LuaMiniExpression(LuaMiniParser *parser);
LuaMiniValue LuaMiniComparison(LuaMiniParser *parser);
LuaMiniValue LuaMiniOr(LuaMiniParser *parser);
Bool LuaMiniNameEqual(U8 *left, U8 *right);
Bool LuaMiniWord(LuaMiniParser *parser, U8 *word);
Bool LuaMiniPeekWord(LuaMiniParser *parser, U8 *word);
LuaMiniFunctionDef *LuaMiniFindFunction(LuaMiniParser *parser, U8 *name);
LuaMiniValue LuaMiniCallFunction(LuaMiniParser *parser, LuaMiniFunctionDef *fn,
    LuaMiniValue *args, I64 arg_count);
U0 LuaMiniFunctionDecl(LuaMiniParser *parser);

Bool LuaMiniIsName(U8 ch) {
  return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_';
}

I64 LuaMiniReadName(LuaMiniParser *parser, U8 *name) {
  I64 length;
  LuaMiniSkip(parser);
  if (!LuaMiniIsName(parser->source[parser->position])) throw(5);
  length = 0;
  while (LuaMiniIsName(parser->source[parser->position]) ||
      (parser->source[parser->position] >= '0' &&
       parser->source[parser->position] <= '9')) {
    if (length < 31) name[length++] = parser->source[parser->position];
    parser->position++;
  }
  name[length] = 0;
  return length;
}

Bool LuaMiniNameEqual(U8 *left, U8 *right) {
  I64 i;
  for (i = 0; left[i] || right[i]; i++)
    if (left[i] != right[i]) return FALSE;
  return TRUE;
}

/* Coerces a value to a number for arithmetic; silently 0 while skipping,
   otherwise a type error. */
F64 LuaMiniNum(LuaMiniParser *parser, LuaMiniValue value) {
  /* hcc's JIT does not convert an int literal/I64 to F64 on return; use
     0.0 and an explicit (F64) cast throughout this file. */
  if (value.type == MINI_NUMBER) return value.number;
  if (parser->skipping) return 0.0;
  throw(28);
  return 0.0;
}

/* String length for `len(...)` and `#`; silently 0 while skipping. */
F64 LuaMiniLen(LuaMiniParser *parser, LuaMiniValue value) {
  I64 length;
  if (value.type != MINI_STRING) {
    if (parser->skipping) return 0.0;
    throw(28);
  }
  length = 0;
  while (value.text[length]) length++;
  return length(F64);
}

LuaMiniValue LuaMiniLookup(LuaMiniParser *parser, U8 *name) {
  I64 i;
  LuaMiniValue nil;
  for (i = parser->binding_count - 1; i >= 0; i--)
    if (LuaMiniNameEqual(parser->names[i], name)) return parser->values[i];
  for (i = 0; i < parser->global_count; i++)
    if (LuaMiniNameEqual(parser->global_names[i], name))
      return parser->global_values[i];
  /* hcc's JIT crashes on `return F();` when F returns a struct this big;
     materializing into a local first works around it. */
  nil = LuaMiniNil();
  if (parser->skipping) return nil;
  throw(6);
  return nil;
}

/* Declares a new local in the current scope, shadowing outer names. */
U0 LuaMiniDeclare(LuaMiniParser *parser, U8 *name, LuaMiniValue value) {
  if (parser->skipping) return;
  if (parser->binding_count >= 64) throw(7);
  MemCpy(parser->names[parser->binding_count], name, 32);
  parser->values[parser->binding_count++] = value;
}

/* Assigns the innermost visible local, otherwise a global. */
U0 LuaMiniAssign(LuaMiniParser *parser, U8 *name, LuaMiniValue value) {
  I64 i;
  if (parser->skipping) return;
  for (i = parser->binding_count - 1; i >= 0; i--) {
    if (LuaMiniNameEqual(parser->names[i], name)) {
      parser->values[i] = value;
      return;
    }
  }
  for (i = 0; i < parser->global_count; i++) {
    if (LuaMiniNameEqual(parser->global_names[i], name)) {
      parser->global_values[i] = value;
      return;
    }
  }
  if (parser->global_count >= 16) throw(7);
  MemCpy(parser->global_names[parser->global_count], name, 32);
  parser->global_values[parser->global_count++] = value;
}

F64 LuaMiniNumber(LuaMiniParser *parser) {
  U8 *start;
  U8 *end;
  F64 value;
  LuaMiniSkip(parser);
  start = parser->source + parser->position;
  value = strtod(start, &end);
  if (end == start) throw(1);
  parser->position += end - start;
  return value;
}

/* Parses a double-quoted string literal, translating \n, \t, \\ and \";
   any other escaped character passes through literally. */
LuaMiniValue LuaMiniStringParse(LuaMiniParser *parser) {
  U8 buf[64];
  I64 length;
  U8 ch;
  LuaMiniValue value;
  LuaMiniSkip(parser);
  if (parser->source[parser->position] != '"') throw(10);
  parser->position++;
  length = 0;
  while (parser->source[parser->position] &&
      parser->source[parser->position] != '"') {
    ch = parser->source[parser->position];
    if (ch == '\\' && parser->source[parser->position + 1]) {
      parser->position++;
      ch = parser->source[parser->position];
      if (ch == 'n') ch = '\n';
      else if (ch == 't') ch = '\t';
    }
    if (length < 63) buf[length++] = ch;
    parser->position++;
  }
  if (parser->source[parser->position] != '"') throw(11);
  parser->position++;
  buf[length] = 0;
  /* hcc's JIT crashes on `return F();` when F returns a struct this big;
     materializing into a local first works around it. */
  value = LuaMiniStringValue(buf, length);
  return value;
}

LuaMiniValue LuaMiniPrimary(LuaMiniParser *parser) {
  LuaMiniValue value;
  U8 name[32];
  LuaMiniSkip(parser);
  /* Below, every branch stores into `value` and falls through to a shared
     `return value;`: hcc's JIT crashes on `return F();` when F returns a
     struct this big, but assign-then-return works around it. */
  if (parser->source[parser->position] == '-') {
    parser->position++;
    value = LuaMiniPrimary(parser);
    value = LuaMiniNumberValue(-LuaMiniNum(parser, value));
    return value;
  }
  if (parser->source[parser->position] == '#') {
    parser->position++;
    value = LuaMiniPrimary(parser);
    value = LuaMiniNumberValue(LuaMiniLen(parser, value));
    return value;
  }
  if (parser->source[parser->position] == '(') {
    parser->position++;
    value = LuaMiniOr(parser);
    LuaMiniSkip(parser);
    if (parser->source[parser->position] != ')') throw(2);
    parser->position++;
    return value;
  }
  if (LuaMiniIsName(parser->source[parser->position])) {
    LuaMiniReadName(parser, name);
    LuaMiniSkip(parser);
    if (LuaMiniNameEqual(name, "true")) {
      value = LuaMiniBoolValue(TRUE);
      return value;
    }
    if (LuaMiniNameEqual(name, "false")) {
      value = LuaMiniBoolValue(FALSE);
      return value;
    }
    if (LuaMiniNameEqual(name, "nil")) {
      value = LuaMiniNil();
      return value;
    }
    if (parser->source[parser->position] == '(') {
      LuaMiniFunctionDef *fn;
      parser->position++;
      fn = LuaMiniFindFunction(parser, name);
      if (fn) {
        LuaMiniValue args[8];
        I64 arg_count;
        arg_count = 0;
        LuaMiniSkip(parser);
        if (parser->source[parser->position] != ')') {
          while (TRUE) {
            LuaMiniValue arg;
            arg = LuaMiniOr(parser);
            if (arg_count < 8) args[arg_count++] = arg;
            LuaMiniSkip(parser);
            if (parser->source[parser->position] == ',') {
              parser->position++;
              continue;
            }
            break;
          }
        }
        if (parser->source[parser->position] != ')') throw(2);
        parser->position++;
        if (parser->skipping) value = LuaMiniNil();
        else value = LuaMiniCallFunction(parser, fn, args, arg_count);
        return value;
      }
      if (LuaMiniNameEqual(name, "len")) {
        value = LuaMiniOr(parser);
        value = LuaMiniNumberValue(LuaMiniLen(parser, value));
      } else if (LuaMiniNameEqual(name, "print")) {
        value = LuaMiniOr(parser);
        if (!parser->skipping) {
          U8 buf[64];
          LuaMiniValueToBuf(value, buf);
          "%s\n", buf;
        }
        value = LuaMiniNil();
      } else if (LuaMiniNameEqual(name, "type")) {
        value = LuaMiniOr(parser);
        if (value.type == MINI_NIL) value = LuaMiniStringValue("nil", 3);
        else if (value.type == MINI_BOOL)
          value = LuaMiniStringValue("boolean", 7);
        else if (value.type == MINI_STRING)
          value = LuaMiniStringValue("string", 6);
        else value = LuaMiniStringValue("number", 6);
      } else {
        LuaMiniNative *native = LuaMiniFindNative(parser->registry, name);
        /* An unrecognized name is reported before parsing its (possibly
           absent, possibly malformed) argument, rather than falling
           through into a confusing "bad number" error. */
        if (native == NULL && !LuaMiniNameEqual(name, "abs") &&
            !LuaMiniNameEqual(name, "sqrt") && !parser->skipping)
          throw(12);
        value = LuaMiniOr(parser);
        if (LuaMiniNameEqual(name, "abs"))
          value = LuaMiniNumberValue(fabs(LuaMiniNum(parser, value)));
        else if (LuaMiniNameEqual(name, "sqrt"))
          value = LuaMiniNumberValue(sqrt(LuaMiniNum(parser, value)));
        else if (native != NULL && !parser->skipping) {
          F64 argument;
          F64 native_result;
          argument = LuaMiniNum(parser, value);
          native->function(argument, &native_result);
          value = LuaMiniNumberValue(native_result);
        }
      }
      LuaMiniSkip(parser);
      if (parser->source[parser->position] != ')') throw(2);
      parser->position++;
      return value;
    }
    value = LuaMiniLookup(parser, name);
    return value;
  }
  if (parser->source[parser->position] == '"') {
    value = LuaMiniStringParse(parser);
    return value;
  }
  value = LuaMiniNumberValue(LuaMiniNumber(parser));
  return value;
}

LuaMiniValue LuaMiniTerm(LuaMiniParser *parser) {
  LuaMiniValue left_value;
  F64 left;
  F64 right;
  U8 operation;
  left_value = LuaMiniPrimary(parser);
  while (TRUE) {
    LuaMiniSkip(parser);
    operation = parser->source[parser->position];
    if (operation != '*' && operation != '/' && operation != '%')
      return left_value;
    parser->position++;
    left = LuaMiniNum(parser, left_value);
    right = LuaMiniNum(parser, LuaMiniPrimary(parser));
    if (operation == '/') {
      if (right == 0.0) {
        if (!parser->skipping) throw(3);
      } else left /= right;
    } else if (operation == '*') left *= right;
    else {
      /* Lua's % is floored modulo: result has the divisor's sign. */
      if (right == 0.0) {
        if (!parser->skipping) throw(3);
      } else left -= floor(left / right) * right;
    }
    left_value = LuaMiniNumberValue(left);
  }
}

LuaMiniValue LuaMiniExpression(LuaMiniParser *parser) {
  LuaMiniValue left_value;
  LuaMiniValue right_value;
  F64 left;
  F64 right;
  U8 operation;
  left_value = LuaMiniTerm(parser);
  while (TRUE) {
    LuaMiniSkip(parser);
    if (parser->source[parser->position] == '.' &&
        parser->source[parser->position + 1] == '.') {
      parser->position += 2;
      right_value = LuaMiniTerm(parser);
      left_value = LuaMiniConcat(left_value, right_value);
      continue;
    }
    operation = parser->source[parser->position];
    if (operation != '+' && operation != '-') return left_value;
    parser->position++;
    left = LuaMiniNum(parser, left_value);
    right = LuaMiniNum(parser, LuaMiniTerm(parser));
    if (operation == '-') left -= right;
    else left += right;
    left_value = LuaMiniNumberValue(left);
  }
}

/* An expression, optionally followed by one comparison (<, <=, >, >=, ==,
   ~=), producing a value: a comparison yields a boolean, anything else
   passes through unchanged. This is the general "expression" grammar level
   used everywhere a value is expected; LuaMiniExpression (arithmetic and
   concatenation) sits just below it. */
LuaMiniValue LuaMiniComparison(LuaMiniParser *parser) {
  LuaMiniValue left_value;
  LuaMiniValue right_value;
  LuaMiniValue result;
  F64 left;
  F64 right;
  U8 operation;
  Bool or_equal;
  left_value = LuaMiniExpression(parser);
  LuaMiniSkip(parser);
  operation = parser->source[parser->position];
  if (operation != '<' && operation != '>' && operation != '=' &&
      operation != '~')
    return left_value;
  /* A bare '=' or '~' (not doubled) belongs to something else (assignment,
     an unsupported operator) and is not part of this expression. */
  if ((operation == '=' || operation == '~') &&
      parser->source[parser->position + 1] != '=')
    return left_value;
  parser->position++;
  or_equal = parser->source[parser->position] == '=';
  if (or_equal) parser->position++;
  right_value = LuaMiniExpression(parser);
  if (operation == '=' || operation == '~') {
    Bool equal;
    equal = LuaMiniValueEqual(left_value, right_value);
    if (operation == '~') equal = !equal;
    result = LuaMiniBoolValue(equal);
    return result;
  }
  left = LuaMiniNum(parser, left_value);
  right = LuaMiniNum(parser, right_value);
  /* hcc types F64 comparisons as F64, so they cannot mix with && or be
     stored in Bool; branch on them instead. */
  if (left == right) {
    result = LuaMiniBoolValue(or_equal);
    return result;
  }
  if (operation == '>') {
    if (left > right) result = LuaMiniBoolValue(TRUE);
    else result = LuaMiniBoolValue(FALSE);
    return result;
  }
  if (left < right) result = LuaMiniBoolValue(TRUE);
  else result = LuaMiniBoolValue(FALSE);
  return result;
}

/* `and`/`or`, above comparison: short-circuiting, and each yields an
   operand's value rather than a plain boolean, matching real Lua. The
   untaken operand is still parsed (to advance position) but with effects
   suppressed via parser->skipping, the same mechanism dead branches use. */
LuaMiniValue LuaMiniAnd(LuaMiniParser *parser) {
  LuaMiniValue left;
  LuaMiniValue right;
  Bool saved;
  left = LuaMiniComparison(parser);
  while (LuaMiniPeekWord(parser, "and")) {
    LuaMiniWord(parser, "and");
    saved = parser->skipping;
    if (!LuaMiniTruthy(left)) parser->skipping = TRUE;
    right = LuaMiniComparison(parser);
    parser->skipping = saved;
    if (LuaMiniTruthy(left)) left = right;
  }
  return left;
}

LuaMiniValue LuaMiniOr(LuaMiniParser *parser) {
  LuaMiniValue left;
  LuaMiniValue right;
  Bool saved;
  left = LuaMiniAnd(parser);
  while (LuaMiniPeekWord(parser, "or")) {
    LuaMiniWord(parser, "or");
    saved = parser->skipping;
    if (LuaMiniTruthy(left)) parser->skipping = TRUE;
    right = LuaMiniAnd(parser);
    parser->skipping = saved;
    if (!LuaMiniTruthy(left)) left = right;
  }
  return left;
}

/* if/while/until conditions accept any expression's truthiness (nil and
   false are the only falsy values, matching real Lua), not just a bare
   comparison. */
Bool LuaMiniCondition(LuaMiniParser *parser) {
  return LuaMiniTruthy(LuaMiniOr(parser));
}

Bool LuaMiniWord(LuaMiniParser *parser, U8 *word) {
  U8 actual[32];
  LuaMiniReadName(parser, actual);
  return LuaMiniNameEqual(actual, word);
}

Bool LuaMiniPeekWord(LuaMiniParser *parser, U8 *word) {
  U8 actual[32];
  I64 saved;
  LuaMiniSkip(parser);
  if (!LuaMiniIsName(parser->source[parser->position])) return FALSE;
  saved = parser->position;
  LuaMiniReadName(parser, actual);
  parser->position = saved;
  return LuaMiniNameEqual(actual, word);
}

/* Coerces the final expression result to a number; used by the F64-typed
   convenience API, which predates general values. */
F64 LuaMiniValueAsNumber(LuaMiniValue value) {
  if (value.type == MINI_NUMBER) return value.number;
  throw(28);
  return 0.0;
}

LuaMiniValue LuaMiniEvalWithRegistryValue(U8 *source, LuaMiniRegistry *registry) {
  LuaMiniParser parser;
  LuaMiniValue result;
  parser.source = source;
  parser.position = 0;
  parser.binding_count = 0;
  parser.global_count = 0;
  parser.function_count = 0;
  parser.call_depth = 0;
  parser.registry = registry;
  parser.skipping = FALSE;
  parser.returned = FALSE;
  parser.breaking = FALSE;
  parser.jumping = FALSE;
  parser.loop_depth = 0;
  LuaMiniSkip(&parser);
  if (source[parser.position] == 'r' && source[parser.position + 1] == 'e' &&
      source[parser.position + 2] == 't' && source[parser.position + 3] == 'u' &&
      source[parser.position + 4] == 'r' && source[parser.position + 5] == 'n')
    parser.position += 6;
  result = LuaMiniOr(&parser);
  LuaMiniSkip(&parser);
  if (source[parser.position] != 0) throw(4);
  return result;
}

F64 LuaMiniEvalWithRegistry(U8 *source, LuaMiniRegistry *registry) {
  return LuaMiniValueAsNumber(LuaMiniEvalWithRegistryValue(source, registry));
}

F64 LuaMiniEval(U8 *source) {
  return LuaMiniEvalWithRegistry(source, NULL);
}

LuaMiniValue LuaMiniEvalValue(U8 *source) {
  /* hcc's JIT crashes on `return F();` when F returns a struct this big;
     materializing into a local first works around it. */
  LuaMiniValue value;
  value = LuaMiniEvalWithRegistryValue(source, NULL);
  return value;
}

U0 LuaMiniExpect(LuaMiniParser *parser, U8 *word, I64 error) {
  if (!LuaMiniPeekWord(parser, word)) throw(error);
  LuaMiniWord(parser, word);
}

U0 LuaMiniBlock(LuaMiniParser *parser);

/* Runs a block with effects enabled only when requested; a return inside it
   keeps the rest of the program in skip mode. */
U0 LuaMiniSubBlock(LuaMiniParser *parser, Bool execute) {
  Bool saved;
  I64 mark;
  saved = parser->skipping;
  mark = parser->binding_count;
  parser->skipping = saved || !execute;
  LuaMiniBlock(parser);
  parser->binding_count = mark;
  parser->skipping = saved || parser->returned || parser->breaking ||
      parser->jumping;
}

U0 LuaMiniIf(LuaMiniParser *parser) {
  Bool condition;
  Bool taken;
  Bool saved;
  saved = parser->skipping;
  condition = LuaMiniCondition(parser);
  LuaMiniExpect(parser, "then", 14);
  LuaMiniSubBlock(parser, condition);
  taken = condition;
  while (LuaMiniPeekWord(parser, "elseif")) {
    LuaMiniWord(parser, "elseif");
    /* Conditions after a taken branch are parsed without effects. */
    parser->skipping = parser->skipping || taken;
    condition = LuaMiniCondition(parser);
    parser->skipping = saved || parser->returned || parser->breaking;
    LuaMiniExpect(parser, "then", 14);
    LuaMiniSubBlock(parser, condition && !taken);
    taken = taken || condition;
  }
  condition = taken;
  if (LuaMiniPeekWord(parser, "else")) {
    LuaMiniWord(parser, "else");
    LuaMiniSubBlock(parser, !condition);
  }
  LuaMiniExpect(parser, "end", 15);
}

U0 LuaMiniLoopBody(LuaMiniParser *parser, Bool execute) {
  parser->loop_depth++;
  LuaMiniSubBlock(parser, execute);
  parser->loop_depth--;
  LuaMiniExpect(parser, "end", 17);
}

/* A loop only starts when effects are enabled, so leaving it via break
   restores normal execution. */
U0 LuaMiniEndBreak(LuaMiniParser *parser) {
  parser->breaking = FALSE;
  parser->skipping = FALSE;
}

U0 LuaMiniWhile(LuaMiniParser *parser) {
  I64 start;
  Bool condition;
  start = parser->position;
  while (TRUE) {
    parser->position = start;
    condition = LuaMiniCondition(parser);
    LuaMiniExpect(parser, "do", 21);
    condition = condition && !parser->skipping;
    LuaMiniLoopBody(parser, condition);
    if (parser->jumping) return;
    if (!condition || parser->returned) return;
    if (parser->breaking) {
      LuaMiniEndBreak(parser);
      return;
    }
  }
}

/* Numeric for: each iteration gets a fresh local control variable. */
U0 LuaMiniFor(LuaMiniParser *parser) {
  U8 name[32];
  F64 value;
  F64 limit;
  F64 step;
  I64 body;
  I64 mark;
  Bool running;
  LuaMiniReadName(parser, name);
  LuaMiniSkip(parser);
  if (parser->source[parser->position++] != '=') throw(9);
  value = LuaMiniNum(parser, LuaMiniExpression(parser));
  LuaMiniSkip(parser);
  if (parser->source[parser->position++] != ',') throw(22);
  limit = LuaMiniNum(parser, LuaMiniExpression(parser));
  step = 1;
  LuaMiniSkip(parser);
  if (parser->source[parser->position] == ',') {
    parser->position++;
    step = LuaMiniNum(parser, LuaMiniExpression(parser));
  }
  if (step == 0.0) {
    if (!parser->skipping) throw(23);
  }
  LuaMiniExpect(parser, "do", 21);
  body = parser->position;
  while (TRUE) {
    parser->position = body;
    running = TRUE;
    /* hcc misorders F64 against integer literals; compare with 0.0. */
    if (step > 0.0) { if (value > limit) running = FALSE; }
    else if (value < limit) running = FALSE;
    if (parser->skipping) running = FALSE;
    mark = parser->binding_count;
    if (running) LuaMiniDeclare(parser, name, LuaMiniNumberValue(value));
    LuaMiniLoopBody(parser, running);
    parser->binding_count = mark;
    if (parser->jumping) return;
    if (!running || parser->returned) return;
    if (parser->breaking) {
      LuaMiniEndBreak(parser);
      return;
    }
    value += step;
  }
}

/* repeat runs the body at least once, then loops while the condition
   (parsed after `until`) is false. */
U0 LuaMiniRepeat(LuaMiniParser *parser) {
  I64 start;
  Bool condition;
  Bool active;
  start = parser->position;
  active = !parser->skipping;
  while (TRUE) {
    parser->position = start;
    parser->loop_depth++;
    LuaMiniSubBlock(parser, active);
    parser->loop_depth--;
    LuaMiniExpect(parser, "until", 17);
    /* Unlike real Lua, the until condition cannot see locals declared in
       the body: SubBlock already popped them back to the loop's mark. */
    condition = LuaMiniCondition(parser);
    if (parser->jumping) return;
    if (parser->returned) return;
    if (parser->breaking) {
      LuaMiniEndBreak(parser);
      return;
    }
    if (!active) return;
    if (condition) return;
  }
}

U0 LuaMiniStatement(LuaMiniParser *parser) {
  U8 name[32];
  LuaMiniValue value;
  if (LuaMiniPeekWord(parser, "return")) {
    LuaMiniWord(parser, "return");
    value = LuaMiniOr(parser);
    if (!parser->skipping) {
      parser->result = value;
      parser->returned = TRUE;
      parser->skipping = TRUE;
    }
  } else if (LuaMiniPeekWord(parser, "break")) {
    LuaMiniWord(parser, "break");
    if (parser->loop_depth == 0) throw(24);
    if (!parser->skipping) {
      parser->breaking = TRUE;
      parser->skipping = TRUE;
    }
  } else if (LuaMiniPeekWord(parser, "if")) {
    LuaMiniWord(parser, "if");
    LuaMiniIf(parser);
  } else if (LuaMiniPeekWord(parser, "while")) {
    LuaMiniWord(parser, "while");
    LuaMiniWhile(parser);
  } else if (LuaMiniPeekWord(parser, "for")) {
    LuaMiniWord(parser, "for");
    LuaMiniFor(parser);
  } else if (LuaMiniPeekWord(parser, "repeat")) {
    LuaMiniWord(parser, "repeat");
    LuaMiniRepeat(parser);
  } else if (LuaMiniPeekWord(parser, "goto")) {
    LuaMiniWord(parser, "goto");
    LuaMiniReadName(parser, name);
    if (!parser->skipping) {
      parser->jumping = TRUE;
      MemCpy(parser->jump_label, name, 32);
      parser->skipping = TRUE;
    }
  } else if (LuaMiniPeekWord(parser, "function")) {
    LuaMiniWord(parser, "function");
    LuaMiniFunctionDecl(parser);
  } else {
    Bool local;
    I64 start;
    local = LuaMiniPeekWord(parser, "local");
    if (local) LuaMiniWord(parser, "local");
    start = parser->position;
    LuaMiniReadName(parser, name);
    LuaMiniSkip(parser);
    if (parser->source[parser->position] == '(') {
      /* A bare call used as a statement, e.g. `print(x)`: rewind and
         re-parse it as an expression, discarding the result. */
      if (local) throw(9);
      parser->position = start;
      value = LuaMiniOr(parser);
    } else {
      if (parser->source[parser->position++] != '=') throw(9);
      value = LuaMiniOr(parser);
      if (local) LuaMiniDeclare(parser, name, value);
      else LuaMiniAssign(parser, name, value);
    }
  }
  LuaMiniSkip(parser);
  if (parser->source[parser->position] == ';') parser->position++;
}

/* Parses statements until end, else, elseif, until, or end of source.
   Labels (::name::) are recorded as seen; an active goto (parser->jumping)
   resolves against a label recorded here, forward or backward, without
   crossing this block's own end/until. An unresolved goto propagates to
   the caller by leaving parser->jumping set when this block returns. */
U0 LuaMiniBlock(LuaMiniParser *parser) {
  U8 label_names[8][32];
  I64 label_positions[8];
  I64 label_marks[8];
  I64 label_count;
  U8 name[32];
  I64 i;
  label_count = 0;
  while (TRUE) {
    LuaMiniSkip(parser);
    if (parser->source[parser->position] == 0) return;
    if (LuaMiniPeekWord(parser, "end") || LuaMiniPeekWord(parser, "else") ||
        LuaMiniPeekWord(parser, "elseif") || LuaMiniPeekWord(parser, "until"))
      return;
    if (parser->source[parser->position] == ':' &&
        parser->source[parser->position + 1] == ':') {
      parser->position += 2;
      LuaMiniReadName(parser, name);
      LuaMiniSkip(parser);
      if (parser->source[parser->position] != ':' ||
          parser->source[parser->position + 1] != ':') throw(26);
      parser->position += 2;
      if (label_count < 8) {
        MemCpy(label_names[label_count], name, 32);
        label_positions[label_count] = parser->position;
        label_marks[label_count] = parser->binding_count;
        label_count++;
      }
      if (parser->jumping && LuaMiniNameEqual(name, parser->jump_label)) {
        parser->jumping = FALSE;
        parser->skipping = FALSE;
      }
      continue;
    }
    LuaMiniStatement(parser);
    if (parser->jumping) {
      for (i = 0; i < label_count; i++) {
        if (LuaMiniNameEqual(label_names[i], parser->jump_label)) {
          parser->position = label_positions[i];
          parser->binding_count = label_marks[i];
          parser->jumping = FALSE;
          parser->skipping = FALSE;
          break;
        }
      }
    }
  }
}

LuaMiniFunctionDef *LuaMiniFindFunction(LuaMiniParser *parser, U8 *name) {
  I64 i;
  for (i = 0; i < parser->function_count; i++)
    if (LuaMiniNameEqual(parser->functions[i].name, name))
      return &parser->functions[i];
  return NULL;
}

/* `function name(a, b) ... end`, only at global/top-level scope, parsed as
   a declaration: the body is skipped over (parsed but not executed) and
   only its text position is recorded; LuaMiniCallFunction re-enters the
   parser there on each call. */
U0 LuaMiniFunctionDecl(LuaMiniParser *parser) {
  U8 function_name[32];
  LuaMiniFunctionDef *def;
  Bool saved;
  LuaMiniReadName(parser, function_name);
  LuaMiniSkip(parser);
  if (parser->source[parser->position++] != '(') throw(29);
  def = NULL;
  if (!parser->skipping) {
    if (parser->function_count >= 8) throw(30);
    def = &parser->functions[parser->function_count++];
    MemCpy(def->name, function_name, 32);
    def->param_count = 0;
  }
  LuaMiniSkip(parser);
  if (parser->source[parser->position] != ')') {
    while (TRUE) {
      U8 param_name[32];
      LuaMiniReadName(parser, param_name);
      if (def && def->param_count < 8)
        MemCpy(def->param_names[def->param_count++], param_name, 32);
      LuaMiniSkip(parser);
      if (parser->source[parser->position] == ',') {
        parser->position++;
        continue;
      }
      break;
    }
  }
  if (parser->source[parser->position] != ')') throw(2);
  parser->position++;
  if (def) def->body_position = parser->position;
  /* The body is only ever entered through a call (LuaMiniCallFunction);
     here it is just skipped over structurally. */
  saved = parser->skipping;
  parser->skipping = TRUE;
  LuaMiniBlock(parser);
  parser->skipping = saved;
  LuaMiniExpect(parser, "end", 15);
}

/* Calls a user-defined function by re-entering the parser at its stored
   body position under a fresh local scope, saving and restoring every
   piece of parser state the body could touch. Recursion is ordinary C
   recursion through this function; call_depth bounds it well under the
   real stack limit. */
LuaMiniValue LuaMiniCallFunction(LuaMiniParser *parser, LuaMiniFunctionDef *fn,
    LuaMiniValue *args, I64 arg_count) {
  I64 saved_position;
  I64 saved_binding_count;
  Bool saved_returned;
  Bool saved_breaking;
  Bool saved_jumping;
  I64 saved_loop_depth;
  LuaMiniValue saved_result;
  LuaMiniValue result;
  I64 i;
  if (parser->call_depth >= 200) throw(31);
  parser->call_depth++;
  saved_position = parser->position;
  saved_binding_count = parser->binding_count;
  saved_returned = parser->returned;
  saved_breaking = parser->breaking;
  saved_jumping = parser->jumping;
  saved_loop_depth = parser->loop_depth;
  saved_result = parser->result;
  parser->position = fn->body_position;
  parser->returned = FALSE;
  parser->breaking = FALSE;
  parser->jumping = FALSE;
  parser->loop_depth = 0;
  for (i = 0; i < fn->param_count; i++) {
    LuaMiniValue arg;
    if (i < arg_count) arg = args[i];
    else arg = LuaMiniNil();
    LuaMiniDeclare(parser, fn->param_names[i], arg);
  }
  LuaMiniBlock(parser);
  if (parser->returned) result = parser->result;
  else result = LuaMiniNil();
  parser->position = saved_position;
  parser->binding_count = saved_binding_count;
  parser->returned = saved_returned;
  parser->breaking = saved_breaking;
  parser->jumping = saved_jumping;
  parser->loop_depth = saved_loop_depth;
  parser->result = saved_result;
  parser->skipping = FALSE; /* only called when the call site was live */
  parser->call_depth--;
  return result;
}

LuaMiniValue LuaMiniRunWithRegistryValue(U8 *source, LuaMiniRegistry *registry) {
  LuaMiniParser parser;
  parser.source = source;
  parser.position = 0;
  parser.binding_count = 0;
  parser.global_count = 0;
  parser.function_count = 0;
  parser.call_depth = 0;
  parser.registry = registry;
  parser.skipping = FALSE;
  parser.returned = FALSE;
  parser.breaking = FALSE;
  parser.jumping = FALSE;
  parser.loop_depth = 0;
  parser.result = LuaMiniNil();
  LuaMiniBlock(&parser);
  if (parser.jumping) throw(27);
  if (parser.source[parser.position] != 0) throw(4);
  if (!parser.returned) throw(8);
  return parser.result;
}

F64 LuaMiniRunWithRegistry(U8 *source, LuaMiniRegistry *registry) {
  return LuaMiniValueAsNumber(LuaMiniRunWithRegistryValue(source, registry));
}

F64 LuaMiniRun(U8 *source) {
  return LuaMiniRunWithRegistry(source, NULL);
}

LuaMiniValue LuaMiniRunValue(U8 *source) {
  /* hcc's JIT crashes on `return F();` when F returns a struct this big;
     materializing into a local first works around it. */
  LuaMiniValue value;
  value = LuaMiniRunWithRegistryValue(source, NULL);
  return value;
}
