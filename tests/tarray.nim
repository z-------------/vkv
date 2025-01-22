import pkg/vkv
import ./utils
import std/[
  unittest,
  paths,
]

type
  Root = object
    testData {.name: "test data".}: TestData
  TestData = object
    Numbers: seq[string]

test "array":
  let data = readVKVTestFile(Path "list_of_values.vdf")
  check Root.fromKeyvalues(data).testData.Numbers == @[
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

test "array with skipped indexes":
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

test "array with empty key":
  let data = readVKVTestFile(Path "list_of_values_empty_key.vdf")
  expect(ValueError):
    discard Root.fromKeyvalues(data)
