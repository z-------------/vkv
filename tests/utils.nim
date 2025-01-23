import std/[
  paths,
]

let dataPath = currentSourcePath().Path.parentDir / "data".Path

proc readTestFile*(filename: Path): string =
  let path = dataPath / filename
  readFile(string path)

proc readVKVTestFile*(filename: Path): string =
  readTestFile("ValveKeyValue/ValveKeyValue/ValveKeyValue.Test/Test Data/Text".Path / filename)
