import entlint

type
  CorpusCase = object
    name: string
    shouldDetect: bool
    content: string

proc positiveCases(): seq[CorpusCase] =
  @[
    CorpusCase(name: "mixed-generic", shouldDetect: true,
      content: "value=" & ("AbCdEfGh" & "12345678" & "_+-/WXYZ")),
    CorpusCase(name: "jwt-shaped", shouldDetect: true,
      content: "value=" & ("AbCdEf12" & "GhIjKl34" & "." &
                            "MnOpQr56" & "StUvWx78" & "." &
                            "YzABcd90" & "EfGHij12")),
    CorpusCase(name: "base64-like", shouldDetect: true,
      content: "value=" & ("Qx7Lm2Pv" & "9Za4Rt1N" & "+/Ws8Yk3" & "Df6Hu0Ce")),
    CorpusCase(name: "url-safe-opaque", shouldDetect: true,
      content: "value=" & ("qA7_zB2-" & "mC9_xD4-" & "pE6_yF8-" & "rG1_kH3")),
    CorpusCase(name: "dotted-opaque", shouldDetect: true,
      content: "value=" & ("A1b2C3d4" & "." & "E5f6G7h8" & "." &
                            "J9k0L1m2" & "N3p4Q5r6")),
    CorpusCase(name: "alnum-opaque", shouldDetect: true,
      content: "value=" & ("Az7By6Cx" & "5Dw4Ev3F" & "u2Gt1Hs9" & "Jr8Kq0Lp")),
    CorpusCase(name: "single-slash-opaque", shouldDetect: true,
      content: "value=" & ("Ab7Cd8Ef" & "Gh9/Jk0L" & "Mn1Pq2Rs" & "Tu3Vw4Xy")),
    CorpusCase(name: "tilde-dash-opaque", shouldDetect: true,
      content: "value=" & ("Aa1~Bb2-" & "Cc3_Dd4~" & "Ee5-Ff6_" & "Gg7~Hh8-"))
  ]

proc benignCases(): seq[CorpusCase] =
  @[
    CorpusCase(name: "ordinary-text", shouldDetect: false,
      content: "ordinary configuration text"),
    CorpusCase(name: "uuid", shouldDetect: false,
      content: "id=" & ("123e4567" & "-e89b-12d3" & "-a456-4266" & "14174000")),
    CorpusCase(name: "url", shouldDetect: false,
      content: "url=https:" & "//cdn.example.com/assets/" & "v1.2.3/abcdef1234567890"),
    CorpusCase(name: "absolute-path", shouldDetect: false,
      content: "path=/opt/carnaverone/feature/" & "agentic-coding-project-2026/file.txt"),
    CorpusCase(name: "sha256-lowercase", shouldDetect: false,
      content: "digest=" & ("9f86d081" & "884c7d65" & "9a2feaa0" & "c55ad015" &
                              "a3bf4f1b" & "2b0b822c" & "d15d6c15" & "b0f00a08")),
    CorpusCase(name: "sha512-lowercase", shouldDetect: false,
      content: "digest=" & ("cf83e135" & "7eefb8bd" & "f1542850" & "d66d8007" &
                              "d620e405" & "0b5715dc" & "83f4a921" & "d36ce9ce" &
                              "47d0d13c" & "5d85f2b0" & "ff8318d2" & "877eec2f" &
                              "63b931bd" & "47417a81" & "a538327a" & "f927da3e")),
    CorpusCase(name: "git-hash-like", shouldDetect: false,
      content: "commit=" & ("01234567" & "89abcdef" & "01234567" & "89abcdef" & "01234567")),
    CorpusCase(name: "release-id", shouldDetect: false,
      content: "release-2026-08-23-build-1234567890abcdef"),
    CorpusCase(name: "version-id", shouldDetect: false,
      content: "v2026.08.23-release-candidate-123456789"),
    CorpusCase(name: "package-id", shouldDetect: false,
      content: "carnaverone-agent-market-hub-v2026.08.23"),
    CorpusCase(name: "filename-id", shouldDetect: false,
      content: "report-2026-08-23-final-version-123456789.pdf"),
    CorpusCase(name: "digits-only", shouldDetect: false,
      content: "123456789012345678901234567890123456"),
    CorpusCase(name: "lowercase-only", shouldDetect: false,
      content: "abcdefghijklmnopqrstuvwxyzabcdefghijkl"),
    CorpusCase(name: "repeated-low-entropy", shouldDetect: false,
      content: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
  ]

proc main() =
  let cases = positiveCases() & benignCases()
  var tp, fp, tn, fn: int

  for item in cases:
    let detected = scanText(item.content).len > 0
    if item.shouldDetect and detected:
      inc tp
    elif item.shouldDetect and not detected:
      inc fn
    elif not item.shouldDetect and detected:
      inc fp
    else:
      inc tn

  echo "detection-corpus: total=", cases.len,
       " tp=", tp, " fp=", fp, " tn=", tn, " fn=", fn

  # Baseline gate for v0.2. This corpus is synthetic and deliberately small;
  # it is a regression signal, not a claim about real-world detection rates.
  doAssert cases.len == 22
  doAssert tp == 8
  doAssert fn == 0
  doAssert tn >= 10
  doAssert fp <= 4

main()
