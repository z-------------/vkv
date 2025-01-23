import pkg/vkv
import std/[
  json,
  unittest,
]

test "comment on end of line":
  var data = ""
  data.add "\"test_kv\"\n"
  data.add "{\n"
  data.add "//\n"
  data.add "\"test\"\t\"hello\"\n"
  data.add "}\n"

  let j = JsonNode.fromKeyvalues(data)
  check j.len == 1
  check j["test_kv"]["test"].getStr == "hello"
