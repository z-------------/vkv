import std/[
  tables,
  strformat,
]

type
  KeyvaluesError* = object of ValueError

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

proc parseHook*(s: string; i: var int; v: var string; topLevel: static bool = false) =
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

proc parseHook*[K, V](s: string; i: var int; v: var Table[K, V]; topLevel: static bool = false) =
  skipJunk(s, i)
  when not topLevel:
    consume(s, i, '{')
  while i < s.len and s[i] != '}':
    var
      key = default K
      value = default V
    parseHook(s, i, key)
    parseHook(s, i, value)
    v[key] = value
    skipJunk(s, i)
  when not topLevel:
    consume(s, i, '}')

proc parseHook*[T: object](s: string; i: var int; v: var T; topLevel: static bool = false) =
  skipJunk(s, i)
  when not topLevel:
    consume(s, i, '{')
  while i < s.len and s[i] != '}':
    var key: string
    parseHook(s, i, key)
    var found = false
    for fieldName, fieldValue in fieldPairs(v):
      # TODO (optional?) case insensitivity
      if fieldName == key:
        found = true
        parseHook(s, i, fieldValue)
        break
    if not found:
      raise (ref KeyvaluesError)(msg: &"{$T} has no field named '{key}'")
    skipJunk(s, i)
  when not topLevel:
    consume(s, i, '}')

proc fromKeyvalues*(t: typedesc; s: string): t =
  var i = 0
  parseHook(s, i, result, topLevel = true)
  skipJunk(s, i)
  if i < s.len:
    raise (ref KeyvaluesError)(msg: &"unexpected trailing content: '{s.toOpenArray(i, s.high)}'")
