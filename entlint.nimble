version       = "0.1.1"
author        = "carnaverone"
description   = "Tiny entropy linter (Nim). Safe previews, no PCRE."
license       = "MIT"
srcDir        = "src"
bin           = @["entlint"]

requires "nim >= 1.6.0"

task test, "Run tests":
  exec "nim c -r -d:release tests/test_cli.nim"
