import std/[
  paths,
  strutils,
]

let dataPath = currentSourcePath().Path.parentDir / "data".Path

proc readTestFile*(filename: Path): string =
  let path = dataPath / filename
  readFile(string path)

proc readVKVTestFile*(filename: Path): string =
  var data = readTestFile("ValveKeyValue/ValveKeyValue/ValveKeyValue.Test/Test Data/Text".Path / filename)
  # TODO is this the correct solution? should we instead modify the parser to handle it?
  data.removePrefix("\xEF\xBB\xBF")
  data
