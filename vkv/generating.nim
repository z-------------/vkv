# Copyright (C) 2024 Zack Guard
# Licensed under GNU General Public License version 3 or later; see LICENSE

# TODO support `name` pragma

import std/[
  strutils,
  tables,
]

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

template dumpHookTableImpl(s, v, depth, topLevel: untyped; iter: iterable) =
  mixin dumpHook
  when not topLevel:
    s.add "\n{\n"
  let indent {.inject.} = '\t'.repeat(depth)
  for fieldName, fieldValue in iter:
    s.add indent
    dumpHook(s, fieldName, depth + 1)
    s.add '\t'
    dumpHook(s, fieldValue, depth + 1)
    s.add '\n'
  when not topLevel:
    s.add "}"

type SomeTable[K, V] = Table[K, V] or OrderedTable[K, V]

proc dumpHook*[K, V](s: var string; v: SomeTable[K, V]; depth = 0; topLevel: static bool = false) =
  dumpHookTableImpl(s, v, depth, topLevel, pairs(v))

proc dumpHook*[T: object](s: var string; v: T; depth = 0; topLevel: static bool = false) =
  dumpHookTableImpl(s, v, depth, topLevel, fieldPairs(v))

proc toKeyvalues*[T](v: T): string =
  result = ""
  dumpHook(result, v, 0, true)
