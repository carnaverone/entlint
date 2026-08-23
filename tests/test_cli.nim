import std/[strutils, os, osproc, json, times]
import entlint

proc highEntropySample(): string =
  # Fragments stay short so the repository never contains a realistic raw secret.
  "AbCdEfGh" & "12345678" & "_+-/WXYZ"

proc jwtLikeSample(): string =
  # Synthetic JWT-shaped candidate, assembled from short non-credential fragments.
  "AbCdEf12" & "GhIjKl34" & "." &
  "MnOpQr56" & "StUvWx78" & "." &
  "YzABcd90" & "EfGHij12"

proc runCommand(executable: string;
                args: seq[string]): tuple[output: string, exitCode: int] =
  var command = quoteShell(executable)
  for arg in args:
    command.add(" " & quoteShell(arg))
  execCmdEx(command)

proc testScannerCore() =
  doAssert shannonEntropy("aaaaaaaaaaaaaaaaaaaa") < 1.0

  let sample = highEntropySample()
  doAssert sample.len >= 20
  doAssert shannonEntropy(sample) > 4.0

  let masked = maskSecret(sample)
  doAssert masked != sample
  doAssert masked.contains("*")
  doAssert not masked.contains(sample)

  let dirtyDisplay = "safe\npath\t" & char(27) & "tail"
  let safeDisplay = safeDisplayText(dirtyDisplay)
  doAssert not safeDisplay.contains("\n")
  doAssert not safeDisplay.contains("\t")
  doAssert not safeDisplay.contains($char(27))
  doAssert safeDisplay.contains("\\n")
  doAssert safeDisplay.contains("\\t")
  doAssert safeDisplay.contains("?")

  let tokens = candidateTokens("prefix=" & sample & " suffix", minLength = 20)
  doAssert tokens.len == 1
  doAssert tokens[0] == sample

  let findings = scanText(
    "first line\ntoken=" & sample,
    path = "fixture.txt",
    threshold = 4.0,
    minLength = 20,
    wantPreview = true
  )
  doAssert findings.len == 1
  doAssert findings[0].path == "fixture.txt"
  doAssert findings[0].line == 2
  doAssert findings[0].preview != sample
  doAssert findings[0].preview.contains("*")

  doAssert scanText(
    "ordinary configuration text",
    threshold = 4.0,
    minLength = 20
  ).len == 0

  doAssert scanText(
    "text\0binary" & sample,
    threshold = 4.0,
    minLength = 20
  ).len == 0

  # UUIDs are identifiers, not secrets by themselves.
  let uuid = "123e4567" & "-e89b-12d3" & "-a456-4266" & "14174000"
  doAssert scanText("id=" & uuid).len == 0

  # Obvious URLs and multi-segment paths should not become entropy findings.
  let url = "https:" & "//cdn.example.com/assets/" & "v1.2.3/abcdef1234567890"
  doAssert shannonEntropy(url.split(":", maxsplit = 1)[1]) > 4.0
  doAssert scanText("url=" & url).len == 0

  let path = "/opt/carnaverone/feature/" & "agentic-coding-project-2026/file.txt"
  doAssert shannonEntropy(path) > 4.0
  doAssert scanText("path=" & path).len == 0

  # JWT-shaped opaque tokens remain eligible for detection.
  let jwt = jwtLikeSample()
  doAssert shannonEntropy(jwt) > 4.0
  doAssert scanText("jwt=" & jwt).len == 1

  let preview = findPreview(sample, win = 16, thr = 3.5)
  doAssert preview.len > 0
  doAssert preview != sample

  # Ignore rules are deliberately simpler than gitignore syntax.
  let ignoreRules = parseIgnoreRules(
    "# comment\n\nfixtures/\n generated.txt \nwindows\\cache\\\n"
  )
  doAssert ignoreRules == @["fixtures/", "generated.txt", "windows/cache/"]
  doAssert pathMatchesPattern("project/fixtures/token.txt", ignoreRules[0])
  doAssert pathMatchesPattern("project\\windows\\cache\\token.txt", ignoreRules[2])
  doAssert not pathMatchesPattern("project/src/token.txt", ignoreRules[0])

  var rejectedNul = false
  try:
    discard parseIgnoreRules("safe\ninvalid\0rule\n")
  except ValueError:
    rejectedNul = true
  doAssert rejectedNul

  var rejectedControl = false
  try:
    discard parseIgnoreRules("safe\ninvalid" & char(1) & "rule\n")
  except ValueError:
    rejectedControl = true
  doAssert rejectedControl

proc testCliIntegration() =
  let nimExe = findExe("nim")
  doAssert nimExe.len > 0, "nim executable must be available for CLI integration tests"

  let suffix = $int(epochTime() * 1_000_000.0)
  let tempRoot = getTempDir() / ("entlint-cli-test-" & suffix)
  createDir(tempRoot)
  defer:
    if dirExists(tempRoot):
      removeDir(tempRoot)

  let binaryPath = tempRoot / ("entlint-test" & ExeExt)
  let compileResult = runCommand(nimExe, @[
    "c",
    "-d:release",
    "--hints:off",
    "--warnings:off",
    "-o:" & binaryPath,
    "src/entlint.nim"
  ])
  doAssert compileResult.exitCode == 0, compileResult.output

  let sample = highEntropySample()
  let secretPath = tempRoot / "secret-fixture.txt"
  let cleanPath = tempRoot / "clean.txt"
  let binaryFixture = tempRoot / "binary-fixture.bin"

  writeFile(secretPath, "token=" & sample & "\n")
  writeFile(cleanPath, "ordinary configuration text\n")
  writeFile(binaryFixture, "prefix\0token=" & sample)

  let found = runCommand(binaryPath, @[
    "file", secretPath, "--json", "--preview", "--lines"
  ])
  doAssert found.exitCode == 2, found.output
  doAssert not found.output.contains(sample)

  let foundJson = parseJson(found.output)
  doAssert foundJson["version"].getStr() == Version
  doAssert foundJson["findings_count"].getInt() == 1
  doAssert foundJson["errors"].getInt() == 0
  doAssert foundJson["findings"][0]["line"].getInt() == 1
  doAssert foundJson["findings"][0]["preview"].getStr().contains("*")
  doAssert foundJson["findings"][0]["preview"].getStr() != sample

  let foundSarifResult = runCommand(binaryPath, @["file", secretPath, "--sarif"])
  doAssert foundSarifResult.exitCode == 2, foundSarifResult.output
  doAssert not foundSarifResult.output.contains(sample)
  let foundSarif = parseJson(foundSarifResult.output)
  doAssert foundSarif["version"].getStr() == "2.1.0"
  doAssert foundSarif["runs"].len == 1
  doAssert foundSarif["runs"][0]["tool"]["driver"]["name"].getStr() == "entlint"
  doAssert foundSarif["runs"][0]["tool"]["driver"]["rules"].len == 1
  doAssert foundSarif["runs"][0]["tool"]["driver"]["rules"][0]["id"].getStr() == "ENTLINT001"
  doAssert foundSarif["runs"][0]["results"].len == 1
  doAssert foundSarif["runs"][0]["results"][0]["ruleId"].getStr() == "ENTLINT001"
  doAssert foundSarif["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["region"]["startLine"].getInt() == 1
  doAssert foundSarif["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["artifactLocation"]["uri"].getStr().len > 0

  let clean = runCommand(binaryPath, @["file", cleanPath, "--json"])
  doAssert clean.exitCode == 0, clean.output
  let cleanJson = parseJson(clean.output)
  doAssert cleanJson["findings_count"].getInt() == 0
  doAssert cleanJson["errors"].getInt() == 0

  let cleanSarifResult = runCommand(binaryPath, @["file", cleanPath, "--sarif"])
  doAssert cleanSarifResult.exitCode == 0, cleanSarifResult.output
  let cleanSarif = parseJson(cleanSarifResult.output)
  doAssert cleanSarif["runs"][0]["results"].len == 0

  let mixedOutput = runCommand(binaryPath, @[
    "file", cleanPath, "--json", "--sarif"
  ])
  doAssert mixedOutput.exitCode == 1

  let skippedBinary = runCommand(binaryPath, @["file", binaryFixture, "--json"])
  doAssert skippedBinary.exitCode == 0, skippedBinary.output
  let binaryJson = parseJson(skippedBinary.output)
  doAssert binaryJson["scanned_files"].getInt() == 0
  doAssert binaryJson["skipped_entries"].getInt() == 1

  let excluded = runCommand(binaryPath, @[
    "scan", tempRoot, "--exclude", "secret-fixture.txt", "--json"
  ])
  doAssert excluded.exitCode == 0, excluded.output
  doAssert parseJson(excluded.output)["findings_count"].getInt() == 0

  let maxSizeSkipped = runCommand(binaryPath, @[
    "file", secretPath, "--max-size", "1", "--json"
  ])
  doAssert maxSizeSkipped.exitCode == 0, maxSizeSkipped.output
  doAssert parseJson(maxSizeSkipped.output)["skipped_entries"].getInt() == 1

  let gitDir = tempRoot / ".git"
  createDir(gitDir)
  writeFile(gitDir / "hidden.txt", "token=" & sample & "\n")

  let defaultExcluded = runCommand(binaryPath, @[
    "scan", tempRoot, "--exclude", "secret-fixture.txt", "--json"
  ])
  doAssert defaultExcluded.exitCode == 0, defaultExcluded.output
  doAssert parseJson(defaultExcluded.output)["findings_count"].getInt() == 0

  let defaultsDisabled = runCommand(binaryPath, @[
    "scan", tempRoot,
    "--exclude", "secret-fixture.txt",
    "--no-default-excludes",
    "--json"
  ])
  doAssert defaultsDisabled.exitCode == 2, defaultsDisabled.output
  doAssert parseJson(defaultsDisabled.output)["findings_count"].getInt() >= 1

  when defined(posix):
    let lnExe = findExe("ln")
    doAssert lnExe.len > 0, "ln executable must be available for symlink test"
    let linkPath = tempRoot / "secret-link.txt"
    let linkCreated = runCommand(lnExe, @["-s", secretPath, linkPath])
    doAssert linkCreated.exitCode == 0, linkCreated.output

    let symlinkTarget = runCommand(binaryPath, @["file", linkPath, "--json"])
    doAssert symlinkTarget.exitCode == 1
    doAssert not symlinkTarget.output.contains(sample)

  let missing = runCommand(binaryPath, @["file", tempRoot / "missing.txt", "--json"])
  doAssert missing.exitCode == 1

  let invalidThreshold = runCommand(binaryPath, @[
    "scan", tempRoot, "--min", "nan", "--json"
  ])
  doAssert invalidThreshold.exitCode == 1

  let overflowingSize = runCommand(binaryPath, @[
    "scan", tempRoot,
    "--max-size", "9223372036854775807M",
    "--json"
  ])
  doAssert overflowingSize.exitCode == 1

  # Root .entlintignore is loaded automatically for directory scans.
  let ignoreRoot = tempRoot / "ignore-case"
  createDir(ignoreRoot)
  let ignoredSecret = ignoreRoot / "ignored-secret.txt"
  writeFile(ignoredSecret, "token=" & sample & "\n")
  writeFile(ignoreRoot / DefaultIgnoreFile,
            "# local generated fixture\nignored-secret.txt\n")

  let autoIgnored = runCommand(binaryPath, @["scan", ignoreRoot, "--json"])
  doAssert autoIgnored.exitCode == 0, autoIgnored.output
  doAssert parseJson(autoIgnored.output)["findings_count"].getInt() == 0

  let ignoreDisabled = runCommand(binaryPath, @[
    "scan", ignoreRoot, "--no-ignore-file", "--json"
  ])
  doAssert ignoreDisabled.exitCode == 2, ignoreDisabled.output
  doAssert parseJson(ignoreDisabled.output)["findings_count"].getInt() == 1

  # Explicit ignore files can be supplied independently of the scan root.
  let customRoot = tempRoot / "custom-ignore-case"
  createDir(customRoot)
  let customSecret = customRoot / "custom-secret.txt"
  let customIgnore = tempRoot / "custom.ignore"
  writeFile(customSecret, "token=" & sample & "\n")
  writeFile(customIgnore, "custom-secret.txt\n")

  let customIgnored = runCommand(binaryPath, @[
    "scan", customRoot,
    "--no-ignore-file",
    "--ignore-file", customIgnore,
    "--json"
  ])
  doAssert customIgnored.exitCode == 0, customIgnored.output
  doAssert parseJson(customIgnored.output)["findings_count"].getInt() == 0

  let missingIgnore = runCommand(binaryPath, @[
    "scan", customRoot,
    "--ignore-file", tempRoot / "missing.ignore",
    "--json"
  ])
  doAssert missingIgnore.exitCode == 1
  doAssert not missingIgnore.output.contains(sample)

  let nulIgnore = tempRoot / "nul.ignore"
  writeFile(nulIgnore, "custom-secret.txt\0ignored\n")
  let invalidIgnore = runCommand(binaryPath, @[
    "scan", customRoot,
    "--ignore-file", nulIgnore,
    "--json"
  ])
  doAssert invalidIgnore.exitCode == 1
  doAssert not invalidIgnore.output.contains(sample)

  let oversizedIgnore = tempRoot / "oversized.ignore"
  writeFile(oversizedIgnore, "a".repeat(256 * 1024 + 1))
  let oversizedIgnoreResult = runCommand(binaryPath, @[
    "scan", customRoot,
    "--ignore-file", oversizedIgnore,
    "--json"
  ])
  doAssert oversizedIgnoreResult.exitCode == 1
  doAssert not oversizedIgnoreResult.output.contains(sample)

  when defined(posix):
    let linkedIgnoreRoot = tempRoot / "linked-ignore-case"
    createDir(linkedIgnoreRoot)
    writeFile(linkedIgnoreRoot / "linked-secret.txt", "token=" & sample & "\n")
    let ignoreTarget = tempRoot / "ignore-target.txt"
    writeFile(ignoreTarget, "linked-secret.txt\n")
    let linkedIgnorePath = linkedIgnoreRoot / DefaultIgnoreFile
    let linkedIgnoreCreated = runCommand(findExe("ln"), @[
      "-s", ignoreTarget, linkedIgnorePath
    ])
    doAssert linkedIgnoreCreated.exitCode == 0, linkedIgnoreCreated.output

    let linkedIgnoreScan = runCommand(binaryPath, @[
      "scan", linkedIgnoreRoot, "--json"
    ])
    doAssert linkedIgnoreScan.exitCode == 1
    doAssert not linkedIgnoreScan.output.contains(sample)

proc main() =
  testScannerCore()
  testCliIntegration()

main()
