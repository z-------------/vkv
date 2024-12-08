import std/[
  json,
  strformat,
  tables,
  unicode,
]

type
  KeyvaluesError* = object of ValueError
  KeyvaluesParseOption* = enum
    TopLevel
    CaseInsensitive

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

type
  KeyvaluesVoid = object

proc `[]=`(kvv: KeyvaluesVoid; key: string; value: KeyvaluesVoid) =
  discard

template parseHookDynamicImpl(s, i, v, opts: untyped; objConstr, strConstr: untyped) =
  # TODO skip allocating keys when v is KeyvaluesVoid?
  template parseEntries(): untyped =
    while i < s.len and s[i] != '}':
      var
        key: string
        value: typeof(v)
      parseHook(s, i, key, opts - {TopLevel})
      parseHook(s, i, value, opts - {TopLevel})
      v[key] = value
      skipJunk(s, i)

  # if top level, assume it is an object
  # otherwise, decide what it is based on whether the first char is '{'
  skipJunk(s, i)
  if TopLevel in opts:
    v = objConstr
    parseEntries()
  else:
    if i >= s.len:
      raise (ref KeyvaluesError)(msg: "expected value, got end of input")
    case s[i]
    of '{':
      consume(s, i, '{')
      v = objConstr
      parseEntries()
      consume(s, i, '}')
    else:
      var str {.inject.}: string
      parseHook(s, i, str, opts - {TopLevel})
      v = strConstr

proc parseHook*(s: string; i: var int; v: out JsonNode; opts: set[KeyvaluesParseOption]) =
  parseHookDynamicImpl(s, i, v, opts, newJObject(), newJString(str))

proc parseHook*(s: string; i: var int; v: out KeyvaluesVoid; opts: set[KeyvaluesParseOption]) =
  parseHookDynamicImpl(s, i, v, opts, KeyvaluesVoid(), KeyvaluesVoid())

proc eqIgnoreCase(a, b: openArray[char]): bool {.raises: [].} =
  cmpRunesIgnoreCase(a, b) == 0

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
      if fieldName == key or (CaseInsensitive in opts and eqIgnoreCase(fieldName, key)):
        found = true
        parseHook(s, i, fieldValue, opts - {TopLevel})
        break
    if not found:
      var nothing: KeyvaluesVoid
      parseHook(s, i, nothing, opts - {TopLevel})
    skipJunk(s, i)
  if TopLevel notin opts:
    consume(s, i, '}')

proc fromKeyvalues*(t: typedesc; s: string; opts: set[KeyvaluesParseOption] = {}): t =
  result = default(t)
  var i = 0
  parseHook(s, i, result, opts + {TopLevel})
  skipJunk(s, i)
  if i < s.len:
    raise (ref KeyvaluesError)(msg: &"unexpected trailing content: '{s.toOpenArray(i, s.high)}'")
