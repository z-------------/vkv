# Copyright (C) 2024 Zack Guard
# Licensed under GNU General Public License version 3 or later; see LICENSE

import ./common
import std/[
  json,
  macros,
  strformat,
  tables,
  unicode,
]
from std/strutils import parseBiggestInt, parseInt, parseFloat

export common

type
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

proc consumeOrEof(s: string; i: var int; c: char) =
  if i < s.len:
    if s[i] != c:
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

proc parseHook*[T: SomeInteger](s: string; i: var int; v: out T; opts: set[KeyvaluesParseOption]) =
  var str: string
  parseHook(s, i, str, opts)
  v = T(parseBiggestInt(str))

proc parseHook*[T: SomeFloat](s: string; i: var int; v: out T; opts: set[KeyvaluesParseOption]) =
  var str: string
  parseHook(s, i, str, opts)
  v = T(parseFloat(str))

proc parseHook*(s: string; i: var int; v: out bool; opts: set[KeyvaluesParseOption]) =
  var str: string
  parseHook(s, i, str, opts)
  v = parseInt(str) != 0

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
    consumeOrEof(s, i, '}')

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
      consumeOrEof(s, i, '}')
    else:
      var str: string
      parseHook(s, i, str, opts - {TopLevel})
      v = newJString(str)

template parseHookArrayImpl(s, i, v, opts, checkIdx: untyped) =
  skipJunk(s, i)
  if TopLevel notin opts:
    consume(s, i, '{')
  while i < s.len and s[i] != '}':
    var key: string
    parseHook(s, i, key, opts - {TopLevel})
    let idx {.inject.} = parseInt(key)
    checkIdx
    parseHook(s, i, v[idx], opts - {TopLevel})
    skipJunk(s, i)
  if TopLevel notin opts:
    consumeOrEof(s, i, '}')

proc parseHook*[T](s: string; i: var int; v: out seq[T]; opts: set[KeyvaluesParseOption]) =
  v = newSeq[T]()
  parseHookArrayImpl(s, i, v, opts):
    if idx < 0:
      raise (ref KeyvaluesError)(msg: "index must be at least 0, got " & $idx)
    if idx > v.high:
      v.setLen(idx + 1)

proc parseHook*[L: static int; T](s: string; i: var int; v: out array[L, T]; opts: set[KeyvaluesParseOption]) =
  v = default array[L, T]
  parseHookArrayImpl(s, i, v, opts):
    if idx notin v.low .. v.high:
      raise (ref KeyvaluesError)(msg: &"index must be in {v.low}..{v.high}, got {idx}")

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
      const name =
        when fieldValue.hasCustomPragma(common.name):
          fieldValue.getCustomPragmaVal(common.name)
        else:
          fieldName
      if name == key or (CaseInsensitive in opts and eqIgnoreCase(name, key)):
        found = true
        parseHook(s, i, fieldValue, opts - {TopLevel})
        break
    if not found:
      # TODO more efficient way to skip value?
      var node: JsonNode
      parseHook(s, i, node, opts - {TopLevel})
    skipJunk(s, i)
  if TopLevel notin opts:
    consumeOrEof(s, i, '}')

proc fromKeyvalues*(t: typedesc; s: string; opts: set[KeyvaluesParseOption] = {}): t =
  result = default(t)
  var i = 0
  parseHook(s, i, result, opts + {TopLevel})
  skipJunk(s, i)
  if i < s.len:
    raise (ref KeyvaluesError)(msg: &"unexpected trailing content: '{s.toOpenArray(i, s.high)}'")
