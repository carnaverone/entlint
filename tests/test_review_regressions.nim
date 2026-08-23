import std/[os, osproc, strutils, json, times]

proc syntheticSecret(): string =
  # Keep fragments short so the repository never stores a realistic credential.
  "AbCdEfGh" & "12345678" & "_+-/WXYZ"

proc runCommand(executable: string;
                args: seq[string]): tuple[output: string, exitCode: int] =
  var command = quoteShell(executable)
  for arg in args:
    command.add(" " & quoteShell(arg))
  execCmdEx(command)

proc makeRules(prefix: string; count: int): string =
  for i in 0 ..< count:
    result.add(prefix & $i & "\n")

proc main() =
  let nimExe = findExe("nim")
  doAssert nimExe.len > 0, "nim executable must be available"

  let suffix = $int(epochTime() * 1_000_000.0)
  let tempRoot = getTempDir() / ("entlint-review-regressions-" & suffix)
  createDir(tempRoot)
  defer:
    if dirExists(tempRoot):
      removeDir(tempRoot)

  let binaryPath = tempRoot / ("entlint-review-test" & ExeExt)
  let compileResult = runCommand(nimExe, @[
    "c", "-d:release", "--hints:off", "--warnings:off",
    "-o:" & binaryPath, "src/entlint.nim"
  ])
  doAssert compileResult.exitCode == 0, compileResult.output

  let sample = syntheticSecret()

  # Regression: an excluded-name ancestor outside the selected scan root must
  # not suppress the entire requested tree.
  let ancestorBuild = tempRoot / "build"
  let requestedRoot = ancestorBuild / "repo"
  createDir(ancestorBuild)
  createDir(requestedRoot)
  writeFile(requestedRoot / "secret.txt", "token=" & sample & "\n")

  let ancestorResult = runCommand(binaryPath, @[
    "scan", requestedRoot, "--json"
  ])
  doAssert ancestorResult.exitCode == 2, ancestorResult.output
  let ancestorJson = parseJson(ancestorResult.output)
  doAssert ancestorJson["scanned_files"].getInt() >= 1
  doAssert ancestorJson["findings_count"].getInt() == 1

  # Regression: built-in exclusions are directory names only. A regular file
  # literally named "build" must still be scanned when selected explicitly.
  let fileNamedBuild = tempRoot / "build-file-root"
  createDir(fileNamedBuild)
  let buildFile = fileNamedBuild / "build"
  writeFile(buildFile, "token=" & sample & "\n")

  let buildFileResult = runCommand(binaryPath, @[
    "file", buildFile, "--json"
  ])
  doAssert buildFileResult.exitCode == 2, buildFileResult.output
  let buildFileJson = parseJson(buildFileResult.output)
  doAssert buildFileJson["scanned_files"].getInt() == 1
  doAssert buildFileJson["findings_count"].getInt() == 1

  # But a nested directory named "build" inside the selected root remains a
  # default-excluded directory.
  let directoryRoot = tempRoot / "directory-exclude-root"
  let nestedBuild = directoryRoot / "build"
  createDir(directoryRoot)
  createDir(nestedBuild)
  writeFile(directoryRoot / "clean.txt", "ordinary configuration text\n")
  writeFile(nestedBuild / "hidden.txt", "token=" & sample & "\n")

  let nestedBuildResult = runCommand(binaryPath, @[
    "scan", directoryRoot, "--json"
  ])
  doAssert nestedBuildResult.exitCode == 0, nestedBuildResult.output
  let nestedBuildJson = parseJson(nestedBuildResult.output)
  doAssert nestedBuildJson["findings_count"].getInt() == 0
  doAssert nestedBuildJson["scanned_files"].getInt() >= 1
  doAssert nestedBuildJson["skipped_entries"].getInt() >= 1

  # Regression: the 2,048 ignore-rule safety limit is cumulative across every
  # explicitly and automatically loaded ignore file, not a per-file allowance.
  let ignoreRoot = tempRoot / "ignore-cap-root"
  createDir(ignoreRoot)
  writeFile(ignoreRoot / "clean.txt", "ordinary configuration text\n")
  let ignoreA = tempRoot / "first.ignore"
  let ignoreB = tempRoot / "second.ignore"
  writeFile(ignoreA, makeRules("first-rule-", 1025))
  writeFile(ignoreB, makeRules("second-rule-", 1025))

  let cumulativeIgnoreResult = runCommand(binaryPath, @[
    "scan", ignoreRoot,
    "--no-ignore-file",
    "--ignore-file", ignoreA,
    "--ignore-file", ignoreB,
    "--json"
  ])
  doAssert cumulativeIgnoreResult.exitCode == 1, cumulativeIgnoreResult.output
  doAssert not cumulativeIgnoreResult.output.contains(sample)
  doAssert cumulativeIgnoreResult.output.contains("too many active ignore rules")

  # Regression: SARIF artifactLocation.uri is a URI path, so reserved filename
  # bytes such as space, '#', and '%' must be percent-encoded while '/' remains
  # a path separator.
  let sarifRoot = tempRoot / "sarif-uri-root"
  createDir(sarifRoot)
  let specialName = "special #100% file.txt"
  let specialPath = sarifRoot / specialName
  writeFile(specialPath, "token=" & sample & "\n")

  let sarifResult = runCommand(binaryPath, @[
    "file", specialPath, "--sarif"
  ])
  doAssert sarifResult.exitCode == 2, sarifResult.output
  doAssert not sarifResult.output.contains(sample)
  let sarifJson = parseJson(sarifResult.output)
  let artifactUri = sarifJson["runs"][0]["results"][0]["locations"][0]["physicalLocation"]["artifactLocation"]["uri"].getStr()
  doAssert artifactUri.endsWith("special%20%23100%25%20file.txt"), artifactUri
  doAssert not artifactUri.contains(" ")
  doAssert not artifactUri.contains("#")
  doAssert artifactUri.contains("/")

  echo "review-regressions: PASS"

main()
