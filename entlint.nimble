version       = "0.1.1"
author        = "Carnaverone"
description   = "Entropy linter (Nim). Detect high-entropy blobs/lines (likely secrets). Safe-by-default."
license       = "MIT"
srcDir        = "src"
bin           = @["entlint"]

# Nimble task: tests
task test, "run tests":
  exec "nim c -r -d:release tests/test_cli.nim"
