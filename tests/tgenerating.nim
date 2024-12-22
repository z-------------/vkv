import pkg/vkv
import ./utils
import std/[
  tables,
  unittest,
  paths,
]

proc dumpHook(s: var string; v: Path; depth = 0; topLevel: static bool = false) =
  dumpHook(s, string v, depth, topLevel)

proc dumpHook(s: var string; v: int; depth = 0; topLevel: static bool = false) =
  dumpHook(s, $v, depth, topLevel)

test "generate addonlist":
  type
    Root = object
      AddonInfo: OrderedTable[string, string]

  let root = Root(
    AddonInfo: {
      "foo.vpk": "1",
      "bar baz.vpk": "0",
      "foo\\bar": "1",
    }.toOrderedTable,
  )
  let s = root.toKeyvalues
  check s == readTestFile(Path "expected_addoninfo.txt")

test "custom dumpHook":
  type
    Root = object
      AddonInfo: OrderedTable[Path, int]

  let root = Root(
    AddonInfo: {
      Path "foo.vpk": 1,
      Path "bar baz.vpk": 0,
      Path "foo\\bar": 1,
    }.toOrderedTable,
  )
  let s = root.toKeyvalues
  check s == readTestFile(Path "expected_addoninfo.txt")
