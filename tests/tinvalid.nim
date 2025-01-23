import ./utils
import pkg/vkv
import std/[
  json,
  paths,
  unittest,
]

test "invalid syntax raises error":
  const Names = [
    # "empty",
    "quoteonly",
    "partialname",
    "nameonly",
    # "partial_nodata",
    "partial_opening_key",
    "partial_partialkey",
    "partial_novalue",
    "partial_opening_value",
    "partial_partialvalue",
    # "partial_noclose",
    "invalid_zerobracerepeated",
  ]
  for name in Names:
    checkpoint name
    let data = readVKVTestFile(Path(name & ".vdf"))
    expect KeyvaluesError:
      discard JsonNode.fromKeyvalues(data)
