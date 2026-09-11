/* Executable Lua nucleus: numeric expressions, statements, and loops. */

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

class LuaMiniParser {
  U8 *source;
  I64 position;
  I64 binding_count;
  LuaMiniRegistry *registry;
  U8 names[8][32];
  F64 values[8];
  Bool skipping; /* parse without effects: dead branches, finished loops */
  Bool returned;
  F64 result;
};

U0 LuaMiniSkip(LuaMiniParser *parser) {
  while (parser->source[parser->position] == ' ' ||
      parser->source[parser->position] == '\t' ||
      parser->source[parser->position] == '\n' ||
      parser->source[parser->position] == '\r')
    parser->position++;
}

F64 LuaMiniExpression(LuaMiniParser *parser);
Bool LuaMiniNameEqual(U8 *left, U8 *right);

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

F64 LuaMiniLookup(LuaMiniParser *parser, U8 *name) {
  I64 i;
  for (i = 0; i < parser->binding_count; i++)
    if (LuaMiniNameEqual(parser->names[i], name)) return parser->values[i];
  if (parser->skipping) return 0;
  throw(6);
  return 0;
}

U0 LuaMiniAssign(LuaMiniParser *parser, U8 *name, F64 value) {
  I64 i;
  if (parser->skipping) return;
  for (i = 0; i < parser->binding_count; i++) {
    if (LuaMiniNameEqual(parser->names[i], name)) {
      parser->values[i] = value;
      return;
    }
  }
  if (parser->binding_count >= 8) throw(7);
  MemCpy(parser->names[parser->binding_count], name, 32);
  parser->values[parser->binding_count++] = value;
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

F64 LuaMiniStringLength(LuaMiniParser *parser) {
  F64 length;
  LuaMiniSkip(parser);
  if (parser->source[parser->position] != '"') throw(10);
  parser->position++;
  length = 0;
  while (parser->source[parser->position] &&
      parser->source[parser->position] != '"') {
    if (parser->source[parser->position] == '\\' &&
        parser->source[parser->position + 1]) parser->position++;
    parser->position++;
    length++;
  }
  if (parser->source[parser->position] != '"') throw(11);
  parser->position++;
  return length;
}

F64 LuaMiniPrimary(LuaMiniParser *parser) {
  F64 value;
  U8 name[32];
  LuaMiniSkip(parser);
  if (parser->source[parser->position] == '-') {
    parser->position++;
    return -LuaMiniPrimary(parser);
  }
  if (parser->source[parser->position] == '(') {
    parser->position++;
    value = LuaMiniExpression(parser);
    LuaMiniSkip(parser);
    if (parser->source[parser->position] != ')') throw(2);
    parser->position++;
    return value;
  }
  if (LuaMiniIsName(parser->source[parser->position])) {
    LuaMiniReadName(parser, name);
    LuaMiniSkip(parser);
    if (parser->source[parser->position] == '(') {
      parser->position++;
      if (LuaMiniNameEqual(name, "len")) {
        value = LuaMiniStringLength(parser);
      } else {
        value = LuaMiniExpression(parser);
        if (LuaMiniNameEqual(name, "abs")) value = fabs(value);
        else if (LuaMiniNameEqual(name, "sqrt")) value = sqrt(value);
        else {
          LuaMiniNative *native = LuaMiniFindNative(parser->registry, name);
          if (!native) {
            if (!parser->skipping) throw(12);
          } else if (!parser->skipping) native->function(value, &value);
        }
      }
      LuaMiniSkip(parser);
      if (parser->source[parser->position] != ')') throw(2);
      parser->position++;
      return value;
    }
    return LuaMiniLookup(parser, name);
  }
  if (parser->source[parser->position] == '"')
    return LuaMiniStringLength(parser);
  return LuaMiniNumber(parser);
}

F64 LuaMiniTerm(LuaMiniParser *parser) {
  F64 left;
  F64 right;
  U8 operation;
  left = LuaMiniPrimary(parser);
  while (TRUE) {
    LuaMiniSkip(parser);
    operation = parser->source[parser->position];
    if (operation != '*' && operation != '/') return left;
    parser->position++;
    right = LuaMiniPrimary(parser);
    if (operation == '/') {
      if (right == 0) {
        if (!parser->skipping) throw(3);
      } else left /= right;
    } else left *= right;
  }
}

F64 LuaMiniExpression(LuaMiniParser *parser) {
  F64 left;
  F64 right;
  U8 operation;
  left = LuaMiniTerm(parser);
  while (TRUE) {
    LuaMiniSkip(parser);
    operation = parser->source[parser->position];
    if (operation != '+' && operation != '-') return left;
    parser->position++;
    right = LuaMiniTerm(parser);
    if (operation == '-') left -= right;
    else left += right;
  }
}

Bool LuaMiniCondition(LuaMiniParser *parser) {
  F64 left;
  F64 right;
  U8 operation;
  Bool or_equal;
  left = LuaMiniExpression(parser);
  LuaMiniSkip(parser);
  operation = parser->source[parser->position++];
  or_equal = parser->source[parser->position] == '=';
  if (or_equal) parser->position++;
  right = LuaMiniExpression(parser);
  /* hcc types F64 comparisons as F64, so they cannot mix with && or be
     stored in Bool; branch on them instead. */
  if (left == right) {
    if (operation == '~' || operation == '=') return operation == '=';
    if (operation == '<' || operation == '>') return or_equal;
  }
  if (operation == '>') { if (left > right) return TRUE; return FALSE; }
  if (operation == '<') { if (left < right) return TRUE; return FALSE; }
  if (operation == '=') return FALSE;
  if (operation == '~' && or_equal) return TRUE;
  throw(13);
  return FALSE;
}

Bool LuaMiniWord(LuaMiniParser *parser, U8 *word) {
  U8 actual[32];
  LuaMiniReadName(parser, actual);
  return LuaMiniNameEqual(actual, word);
}

F64 LuaMiniEvalWithRegistry(U8 *source, LuaMiniRegistry *registry) {
  LuaMiniParser parser;
  F64 result;
  parser.source = source;
  parser.position = 0;
  parser.binding_count = 0;
  parser.registry = registry;
  parser.skipping = FALSE;
  parser.returned = FALSE;
  LuaMiniSkip(&parser);
  if (source[parser.position] == 'r' && source[parser.position + 1] == 'e' &&
      source[parser.position + 2] == 't' && source[parser.position + 3] == 'u' &&
      source[parser.position + 4] == 'r' && source[parser.position + 5] == 'n')
    parser.position += 6;
  result = LuaMiniExpression(&parser);
  LuaMiniSkip(&parser);
  if (source[parser.position] != 0) throw(4);
  return result;
}

F64 LuaMiniEval(U8 *source) {
  F64 result;
  result = LuaMiniEvalWithRegistry(source, NULL);
  return result;
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

U0 LuaMiniExpect(LuaMiniParser *parser, U8 *word, I64 error) {
  if (!LuaMiniPeekWord(parser, word)) throw(error);
  LuaMiniWord(parser, word);
}

U0 LuaMiniBlock(LuaMiniParser *parser);

/* Runs a block with effects enabled only when requested; a return inside it
   keeps the rest of the program in skip mode. */
U0 LuaMiniSubBlock(LuaMiniParser *parser, Bool execute) {
  Bool saved;
  saved = parser->skipping;
  parser->skipping = saved || !execute;
  LuaMiniBlock(parser);
  parser->skipping = saved || parser->returned;
}

U0 LuaMiniIf(LuaMiniParser *parser) {
  Bool condition;
  condition = LuaMiniCondition(parser);
  LuaMiniExpect(parser, "then", 14);
  LuaMiniSubBlock(parser, condition);
  if (LuaMiniPeekWord(parser, "else")) {
    LuaMiniWord(parser, "else");
    LuaMiniSubBlock(parser, !condition);
  }
  LuaMiniExpect(parser, "end", 15);
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
    LuaMiniSubBlock(parser, condition);
    LuaMiniExpect(parser, "end", 17);
    if (!condition || parser->returned) return;
  }
}

/* Numeric for: the control variable lives in the flat binding table. */
U0 LuaMiniFor(LuaMiniParser *parser) {
  U8 name[32];
  F64 value;
  F64 limit;
  F64 step;
  I64 body;
  Bool running;
  LuaMiniReadName(parser, name);
  LuaMiniSkip(parser);
  if (parser->source[parser->position++] != '=') throw(9);
  value = LuaMiniExpression(parser);
  LuaMiniSkip(parser);
  if (parser->source[parser->position++] != ',') throw(22);
  limit = LuaMiniExpression(parser);
  step = 1;
  LuaMiniSkip(parser);
  if (parser->source[parser->position] == ',') {
    parser->position++;
    step = LuaMiniExpression(parser);
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
    if (running) LuaMiniAssign(parser, name, value);
    LuaMiniSubBlock(parser, running);
    LuaMiniExpect(parser, "end", 17);
    if (!running || parser->returned) return;
    value += step;
  }
}

U0 LuaMiniStatement(LuaMiniParser *parser) {
  U8 name[32];
  F64 value;
  if (LuaMiniPeekWord(parser, "return")) {
    LuaMiniWord(parser, "return");
    value = LuaMiniExpression(parser);
    if (!parser->skipping) {
      parser->result = value;
      parser->returned = TRUE;
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
  } else {
    if (LuaMiniPeekWord(parser, "local")) LuaMiniWord(parser, "local");
    LuaMiniReadName(parser, name);
    LuaMiniSkip(parser);
    if (parser->source[parser->position++] != '=') throw(9);
    value = LuaMiniExpression(parser);
    LuaMiniAssign(parser, name, value);
  }
  LuaMiniSkip(parser);
  if (parser->source[parser->position] == ';') parser->position++;
}

/* Parses statements until end, else, or end of source. */
U0 LuaMiniBlock(LuaMiniParser *parser) {
  while (TRUE) {
    LuaMiniSkip(parser);
    if (parser->source[parser->position] == 0) return;
    if (LuaMiniPeekWord(parser, "end") || LuaMiniPeekWord(parser, "else"))
      return;
    LuaMiniStatement(parser);
  }
}

F64 LuaMiniRunWithRegistry(U8 *source, LuaMiniRegistry *registry) {
  LuaMiniParser parser;
  parser.source = source;
  parser.position = 0;
  parser.binding_count = 0;
  parser.registry = registry;
  parser.skipping = FALSE;
  parser.returned = FALSE;
  parser.result = 0;
  LuaMiniBlock(&parser);
  if (parser.source[parser.position] != 0) throw(4);
  if (!parser.returned) throw(8);
  return parser.result;
}

F64 LuaMiniRun(U8 *source) {
  F64 result;
  result = LuaMiniRunWithRegistry(source, NULL);
  return result;
}
