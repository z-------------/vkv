import std/paths

template readTestFile*(filename: Path): string =
  let path = currentSourcePath().Path.parentDir / "data".Path / filename
  readFile(string path)
