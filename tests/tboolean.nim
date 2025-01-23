import pkg/vkv
import ./utils
import std/[
  json,
  paths,
  unittest,
  strutils,
]

type
  Root = object
    o {.name: "object".}: Object
  Object = object
    test1_false: bool
    test2_true: bool
    test3_oob: bool

test "deserialize to object":
  let data = readVKVTestFile(Path "boolean.vdf")
  check Root.fromKeyvalues(data) == Root(
    o: Object(
      test1_false: false,
      test2_true: true,
      test3_oob: true,
    ),
  )

test "serialize from JsonNode":
  let j = %*{
    "object": {
      "test1_false": false,
      "test2_true": true,
    },
  }
  let expected = readVKVTestFile(Path "boolean_serialization.vdf")
  # they are not character-for-character equal (extra tabs etc.), so instead check that they are equivalent
  check JsonNode.fromKeyvalues(j.toKeyvalues) == JsonNode.fromKeyvalues(expected)

test "serialize from object":
  let j = Root(
    o: Object(
      test1_false: false,
      test2_true: true,
    ),
  )
  let expected = readVKVTestFile(Path "boolean_serialization.vdf")
  check Root.fromKeyvalues(j.toKeyvalues) == Root.fromKeyvalues(expected)

