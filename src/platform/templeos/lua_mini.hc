/* Executable Lua nucleus: numeric expressions and return statements. */

#include "lua_state.hc"

class LuaMiniParser {
  U8 *source;
  I64 position;
};

U0 LuaMiniSkip(LuaMiniParser *parser) {
  while (parser->source[parser->position] == ' ' ||
      parser->source[parser->position] == '\t' ||
      parser->source[parser->position] == '\n' ||
      parser->source[parser->position] == '\r')
    parser->position++;
}

F64 LuaMiniExpression(LuaMiniParser *parser);

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
  LuaMiniSkip(parser);
  if (parser->source[parser->position] == '(') {
    parser->position++;
    value = LuaMiniExpression(parser);
    LuaMiniSkip(parser);
    if (parser->source[parser->position] != ')') throw(2);
    parser->position++;
    return value;
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

