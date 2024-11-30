import std/[
  json,
  strformat,
  tables,
]

type
  KeyvaluesError* = object of ValueError
  KeyvaluesParseOption* = enum
    TopLevel

proc hasString(s: string; i: int; str: string): bool =
  i + str.len <= s.len and s.toOpenArray(i, i + str.high) == str

proc skipToNextLine(s: string; i: var int) =
  while i < s.len:
    if s[i] == '\n':
      inc i
      break
    elif hasString(s, i, "\r\n"):
      inc i, 2
      break
    else:
      inc i

proc skipJunk(s: string; i: var int) =
  while i < s.len:
    if hasString(s, i, "//"):
      skipToNextLine(s, i)
    elif s[i] notin {' ', '\t', '\n'} and not hasString(s, i, "\r\n"):
      break
    else:
      inc i

proc consume(s: string; i: var int; c: char) =
  if i >= s.len:
    raise (ref KeyvaluesError)(msg: &"expected '{c}', got end of input")
  elif s[i] != c:
    raise (ref KeyvaluesError)(msg: &"expected '{c}', got '{s[i]}'")
  inc i

proc parseHook*(s: string; i: var int; v: out string; opts: set[KeyvaluesParseOption]) =
  v = ""
  skipJunk(s, i)
  if i >= s.high:
    raise (ref KeyvaluesError)(msg: "expected string, got end of input")
  let quoted = s[i] == '"'
  if quoted:
    inc i
  var ended = false
  while i < s.len:
    if quoted:
      if s[i] == '"':
        inc i
        ended = true
        break
    else:
      if s[i] in {' ', '\t', '\n', '\r', '"', '}'}:
        if v == "":
          raise (ref KeyvaluesError)(msg: "expected a string")
        ended = true
        break
    v.add s[i]
    inc i
  if quoted and not ended:
    raise (ref KeyvaluesError)(msg: "expected end of string, got end of input")

type SomeTable[K, V] = Table[K, V] or OrderedTable[K, V]

proc parseHook*[K, V; T: SomeTable[K, V]](s: string; i: var int; v: out T; opts: set[KeyvaluesParseOption]) =
  v = default T
  skipJunk(s, i)
  if TopLevel notin opts:
    consume(s, i, '{')
  while i < s.len and s[i] != '}':
    var
      key = default K
      value = default V
    parseHook(s, i, key, opts - {TopLevel})
    parseHook(s, i, value, opts - {TopLevel})
    v[key] = value
    skipJunk(s, i)
  if TopLevel notin opts:
    consume(s, i, '}')

proc parseHook*(s: string; i: var int; v: out JsonNode; opts: set[KeyvaluesParseOption]) =
  template parseEntries(): untyped =
    while i < s.len and s[i] != '}':
      var
        key: string
        value: JsonNode
      parseHook(s, i, key, opts - {TopLevel})
      parseHook(s, i, value, opts - {TopLevel})
      v[key] = value
      skipJunk(s, i)

  # if top level, assume it is an object
  # otherwise, decide what it is based on whether the first char is '{'
  skipJunk(s, i)
  if TopLevel in opts:
    v = newJObject()
    parseEntries()
  else:
    if i >= s.len:
      raise (ref KeyvaluesError)(msg: "expected value, got end of input")
    case s[i]
    of '{':
      consume(s, i, '{')
      v = newJObject()
      parseEntries()
      consume(s, i, '}')
    else:
      var str: string
      parseHook(s, i, str, opts - {TopLevel})
      v = newJString(str)

proc parseHook*[T: object](s: string; i: var int; v: out T; opts: set[KeyvaluesParseOption]) =
  v = default T
  skipJunk(s, i)
  if TopLevel notin opts:
    consume(s, i, '{')
  while i < s.len and s[i] != '}':
    var key: string
    parseHook(s, i, key, opts - {TopLevel})
    var found = false
    for fieldName, fieldValue in fieldPairs(v):
      # TODO (optional?) case insensitivity
      if fieldName == key:
        found = true
        parseHook(s, i, fieldValue, opts - {TopLevel})
        break
    if not found:
      raise (ref KeyvaluesError)(msg: &"{$T} has no field named '{key}'")
    skipJunk(s, i)
  if TopLevel notin opts:
    consume(s, i, '}')

proc fromKeyvalues*(t: typedesc; s: string; opts = {TopLevel}): t =
  result = default(t)
  var i = 0
  parseHook(s, i, result, opts)
  skipJunk(s, i)
  if i < s.len:
    raise (ref KeyvaluesError)(msg: &"unexpected trailing content: '{s.toOpenArray(i, s.high)}'")
