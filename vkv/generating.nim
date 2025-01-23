# Copyright (C) 2024 Zack Guard
# Licensed under GNU General Public License version 3 or later; see LICENSE

import ./common
import std/[
  json,
  macros,
  strutils,
  tables,
]

export common

proc dumpHook*(s: var string; v: string; depth = 0; topLevel: static bool = false) =
  s.add '"'
  for c in v:
    s.add c
  s.add '"'

proc dumpHook*(s: var string; v: SomeInteger; depth = 0; topLevel: static bool = false) =
  dumpHook(s, $v, depth, topLevel)

proc dumpHook*(s: var string; v: SomeFloat; depth = 0; topLevel: static bool = false) =
  dumpHook(s, $v, depth, topLevel)

proc dumpHook*(s: var string; v: bool; depth = 0; topLevel: static bool = false) =
  dumpHook(s, if v: "1" else: "0", depth, topLevel)

template dumpHookTableImpl(s, depth, topLevel: untyped; iter: iterable; checkPragma: static bool) =
  mixin dumpHook
  when not topLevel:
    s.add "\n{\n"
  let indent {.inject.} = '\t'.repeat(depth)
  for fieldName, fieldValue in iter:
    s.add indent
    when checkPragma:
      const name =
        when fieldValue.hasCustomPragma(common.name):
          fieldValue.getCustomPragmaVal(common.name)
        else:
          fieldName
    else:
      let name = fieldName
    dumpHook(s, name, depth + 1)
    s.add '\t'
    dumpHook(s, fieldValue, depth + 1)
    s.add '\n'
  when not topLevel:
    s.add "}"

type SomeTable[K, V] = Table[K, V] or OrderedTable[K, V]

proc dumpHook*[K, V](s: var string; v: SomeTable[K, V]; depth = 0; topLevel: static bool = false) =
  dumpHookTableImpl(s, depth, topLevel, pairs(v), false)

template dumpHookArrayImpl(s, depth, topLevel: untyped; iter: iterable) =
  # similar to the one for tables/objects
  mixin dumpHook
  when not topLevel:
    s.add "\n{\n"
  let indent {.inject.} = '\t'.repeat(depth)
  for idx, val in iter:
    s.add indent
    dumpHook(s, $idx, depth + 1)
    s.add '\t'
    dumpHook(s, val, depth + 1)
    s.add '\n'
  when not topLevel:
    s.add "}"

iterator jArrayPairs(v: JsonNode): (int, JsonNode) =
  assert v.kind == JArray
  var idx = 0
  for item in items(v):
    yield (idx, item)
    inc idx

proc dumpHook*(s: var string; v: JsonNode; depth = 0; topLevel: static bool = false) =
  case v.kind
  of JNull:
    # TODO is this the right thing to do?
    dumpHook(s, "", depth, topLevel)
  of JBool:
    dumpHook(s, v.getBool, depth, topLevel)
  of JInt:
    dumpHook(s, v.getInt, depth, topLevel)
  of JFloat:
    dumpHook(s, v.getFloat, depth, topLevel)
  of JString:
    dumpHook(s, v.getStr, depth, topLevel)
  of JObject:
    dumpHookTableImpl(s, depth, topLevel, pairs(v), false)
  of JArray:
    dumpHookArrayImpl(s, depth, topLevel, jArrayPairs(v))

proc dumpHook*[T](s: var string; v: openArray[T]; depth = 0; topLevel: static bool = false) =
  dumpHookArrayImpl(s, depth, topLevel, pairs(v))

proc dumpHook*[T: object](s: var string; v: T; depth = 0; topLevel: static bool = false) =
  dumpHookTableImpl(s, depth, topLevel, fieldPairs(v), true)

proc toKeyvalues*[T](v: T): string =
  result = ""
  dumpHook(result, v, 0, true)
