# vkv

Serialize/deserialize to/from Valve KeyValues format, JSONy-style. Currently supports only the subset that I need for my other projects.

## Example

```nim
import pkg/vkv/parsing
import std/uri

type
  Root = object
    addonInfo: AddonInfo
  AddonInfo = object
    addonSteamAppId: string
    addonTitle: string
    addonUrl0: Uri

proc parseHook(s: string; i: var int; v: out Uri; opts: set[KeyvaluesParseOption]) =
  var str: string
  parseHook(s, i, str, opts)
  v = parseUri(str)

let s = readFile("addoninfo.txt")
let root = Root.fromKeyvalues(s, {CaseInsensitive})
doAssert root == Root(
  addonInfo: AddonInfo(
    addonSteamAppId: "550",
    addonTitle: "Some Addon",
    addonUrl0: parseUri"https://example.com/",
  ),
)
```
