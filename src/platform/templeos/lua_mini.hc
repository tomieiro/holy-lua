/* Executable Lua nucleus: numeric expressions and return statements. */

#include "lua_state.hc"

class LuaMiniParser {
  U8 *source;
  I64 position;
  I64 binding_count;
  U8 names[8][32];
  F64 values[8];
};

U0 LuaMiniSkip(LuaMiniParser *parser) {
  while (parser->source[parser->position] == ' ' ||
      parser->source[parser->position] == '\t' ||
      parser->source[parser->position] == '\n' ||
      parser->source[parser->position] == '\r')
    parser->position++;
}

F64 LuaMiniExpression(LuaMiniParser *parser);

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
  throw(6);
  return 0;
}

U0 LuaMiniAssign(LuaMiniParser *parser, U8 *name, F64 value) {
  I64 i;
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

F64 LuaMiniPrimary(LuaMiniParser *parser) {
  F64 value;
  U8 name[32];
  LuaMiniSkip(parser);
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
    return LuaMiniLookup(parser, name);
  }
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
      if (right == 0) throw(3);
      left /= right;
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

F64 LuaMiniEval(U8 *source) {
  LuaMiniParser parser;
  F64 result;
  parser.source = source;
  parser.position = 0;
  parser.binding_count = 0;
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

F64 LuaMiniRun(U8 *source) {
  LuaMiniParser parser;
  U8 name[32];
  F64 result;
  parser.source = source;
  parser.position = 0;
  parser.binding_count = 0;
  while (TRUE) {
    LuaMiniSkip(&parser);
    if (parser.source[parser.position] == 0) throw(8);
    if (parser.source[parser.position] == 'r' &&
        parser.source[parser.position + 1] == 'e' &&
        parser.source[parser.position + 2] == 't' &&
        parser.source[parser.position + 3] == 'u' &&
        parser.source[parser.position + 4] == 'r' &&
        parser.source[parser.position + 5] == 'n') {
      parser.position += 6;
      result = LuaMiniExpression(&parser);
      LuaMiniSkip(&parser);
      if (parser.source[parser.position] != 0) throw(4);
      return result;
    }
    LuaMiniReadName(&parser, name);
    LuaMiniSkip(&parser);
    if (parser.source[parser.position++] != '=') throw(9);
    result = LuaMiniExpression(&parser);
    LuaMiniAssign(&parser, name, result);
    LuaMiniSkip(&parser);
    if (parser.source[parser.position] == ';') parser.position++;
  }
}
