import pkg/vkv
import ./utils
import std/[
  json,
  paths,
  unittest,
]

type
  Root = object
    testData {.name: "test data".}: TestData
  TestData = object
    Numbers: seq[string]

const Numbers = @[
  "zero",
  "one",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight",
  "nine",
  "ten",
  "eleven",
  "twelve",
  "thirteen",
]

test "parse seq":
  let data = readVKVTestFile(Path "list_of_values.vdf")
  check Root.fromKeyvalues(data).testData.Numbers == Numbers

test "parse seq with skipped indexes":
  let data = readVKVTestFile(Path "list_of_values_skipping_keys.vdf")
  check Root.fromKeyvalues(data).testData.Numbers == @[
    "zero",
    "",
    "",
    "three",
    "four",
    "",
    "",
    "seven",
    "eight",
    "nine",
    "",
    "",
    "",
    "thirteen",
  ]

test "parse seq with empty key":
  let data = readVKVTestFile(Path "list_of_values_empty_key.vdf")
  expect(ValueError):
    discard Root.fromKeyvalues(data)

test "serialize seq":
  let r = Root(
    testData: TestData(
      Numbers: Numbers,
    ),
  )
  let data = readVKVTestFile(Path "list_of_values.vdf")
  check Root.fromKeyvalues(r.toKeyvalues) == Root.fromKeyvalues(data)

test "serialize JSON array":
  let j = %*{
    "test data": {
      "Numbers": Numbers,
    },
  }
  let data = readVKVTestFile(Path "list_of_values.vdf")
  let j2 = JsonNode.fromKeyvalues(j.toKeyvalues)
  check j2["test data"]["Numbers"].kind == JObject
  check j2 == JsonNode.fromKeyvalues(data)
