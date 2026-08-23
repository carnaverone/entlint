import std/strutils
import entlint

proc highEntropySample(): string =
  # Fragments stay short so the repository never contains a realistic raw secret.
  "AbCdEfGh" & "12345678" & "_+-/WXYZ"

proc main() =
  doAssert shannonEntropy("aaaaaaaaaaaaaaaaaaaa") < 1.0

  let sample = highEntropySample()
  doAssert sample.len >= 20
  doAssert shannonEntropy(sample) > 4.0

  let masked = maskSecret(sample)
  doAssert masked != sample
  doAssert masked.contains("*")
  doAssert not masked.contains(sample)

  let tokens = candidateTokens("prefix=" & sample & " suffix", minLength = 20)
  doAssert tokens.len == 1
  doAssert tokens[0] == sample

  let findings = scanText(
    "token=" & sample,
    path = "fixture.txt",
    threshold = 4.0,
    minLength = 20,
    wantPreview = true
  )
  doAssert findings.len == 1
  doAssert findings[0].path == "fixture.txt"
  doAssert findings[0].line == 1
  doAssert findings[0].preview != sample
  doAssert findings[0].preview.contains("*")

  doAssert scanText(
    "ordinary configuration text",
    threshold = 4.0,
    minLength = 20
  ).len == 0

  doAssert scanText(
    "text\0binary",
    threshold = 4.0,
    minLength = 20
  ).len == 0

  let preview = findPreview(sample, win = 16, thr = 3.5)
  doAssert preview.len > 0
  doAssert preview != sample

main()
