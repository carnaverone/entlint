version       = "0.2.0"
author        = "carnaverone"
description   = "Local entropy-based secret linter with masked output and CI-friendly JSON/SARIF."
license       = "MIT"
srcDir        = "src"
bin           = @["entlint"]

requires "nim >= 1.6.0"

task test, "Run tests":
  exec "nim c -r -d:release --path:src tests/test_cli.nim"
  exec "nim c -r -d:release --path:src tests/test_detection_corpus.nim"
  exec "nim c -r -d:release --path:src tests/test_review_regressions.nim"
