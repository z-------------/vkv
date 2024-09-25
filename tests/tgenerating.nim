import pkg/vkv
import ./utils
import std/[
  tables,
  unittest,
  paths,
]

test "generate addonlist":
  type
    Root = object
      AddonInfo: OrderedTable[string, string]

  let root = Root(
    AddonInfo: {
      "foo.vpk": "1",
      "bar baz.vpk": "0",
      "foo \"bar\"\n": "1",
    }.toOrderedTable,
  )
  let s = root.toKeyvalues
  check s == readTestFile(Path "expected_addoninfo.txt")
