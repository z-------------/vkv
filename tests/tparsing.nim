import pkg/vkv
import ./utils
import std/[
  tables,
  unittest,
  uri,
  paths,
]

proc parseHook(s: string; i: var int; v: out Uri; opts: set[KeyvaluesParseOption]) =
  var str: string
  parseHook(s, i, str, opts)
  v = parseUri(str)

test "basic":
  check string.fromKeyvalues(""" "hello world" """) == "hello world"
  check Table[string, string].fromKeyvalues(""" "foo" "bar" """) == {"foo": "bar"}.toTable

  type
    Root = object
      AddonInfo: Table[string, string]

  check Root.fromKeyvalues(""" "AddonInfo"
  {
    "foo.vpk" "bar baz"
    "yes no.vpk"    coolio
  }
  """) == Root(AddonInfo: {"foo.vpk": "bar baz", "yes no.vpk": "coolio"}.toTable)

test "parse addonlist":
  type
    Root = object
      AddonList: OrderedTable[string, string]

  let s = readTestFile(Path "addonlist.txt")
  let root = Root.fromKeyvalues(s)
  check root == Root(
    AddonList: {
      "123.vpk": "1",
      "234.vpk": "0",
      "345.vpk": "1",
    }.toOrderedTable,
  )

import std/json

test "parse addonlist to JsonNode":
  let s = readTestFile(Path "addonlist.txt")
  let root = JsonNode.fromKeyvalues(s)
  check root == %*{
    "AddonList": {
      "123.vpk": "1",
      "234.vpk": "0",
      "345.vpk": "1",
    },
  }

test "parse addoninfo":
  type
    Root = object
      AddonInfo: Table[string, string]

  let s = readTestFile(Path "addoninfo.txt")
  let root = Root.fromKeyvalues(s)
  check root == Root(
    AddonInfo: {
      "addonSteamAppID": "550",
      "addontitle": "Some Addon",
      "addonversion": "1.4",
      "addontagline": "Lorem ipsum dolor sit amet.",
      "addonauthor": "The dev team",
      "addonContent_Campaign": "1",
      "addonURL0": "https://example.com/",
      "addonDescription": "Some more text here",
      "addonContent_Script": "1",
      "addonContent_Music": "1",
      "addonContent_Sound": "1",
      "addonContent_prop": "1",
      "addonContent_Prefab": "0",
      "addonContent_BossInfected": "1",
      "addonContent_Skin": "1",
    }.toTable,
  )

test "extra keys":
  type
    Root = object
      AddonInfo: AddonInfo
    AddonInfo = object
      addonSteamAppID: string
      addontitle: string
      addonURL0: string

  let s = readTestFile(Path "addoninfo.txt")
  let root = Root.fromKeyvalues(s)
  check root == Root(
    AddonInfo: AddonInfo(
      addonSteamAppID: "550",
      addontitle: "Some Addon",
      addonURL0: "https://example.com/",
    ),
  )

test "case insensitivity":
  type
    Root = object
      addonInfo: AddonInfo
    AddonInfo = object
      addonSteamAppId: string
      addonTitle: string
      addonUrl0: string

  let s = readTestFile(Path "addoninfo.txt")
  let root = Root.fromKeyvalues(s, {CaseInsensitive})
  check root == Root(
    addonInfo: AddonInfo(
      addonSteamAppId: "550",
      addonTitle: "Some Addon",
      addonUrl0: "https://example.com/",
    ),
  )

test "custom parseHook":
  type
    Root = object
      addonInfo: AddonInfo
    AddonInfo = object
      addonSteamAppId: string
      addonTitle: string
      addonUrl0: Uri

  let s = readTestFile(Path "addoninfo.txt")
  let root = Root.fromKeyvalues(s, {CaseInsensitive})
  check root == Root(
    addonInfo: AddonInfo(
      addonSteamAppId: "550",
      addonTitle: "Some Addon",
      addonUrl0: parseUri"https://example.com/",
    ),
  )
