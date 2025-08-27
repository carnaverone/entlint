import std/[os, osproc, strutils]

when defined(windows):
  const exe = "entlint.exe"
else:
  const exe = "entlint"

proc buildBinary(): void =
  let rc = execShellCmd("nim c -d:release -o:" & exe & " src/entlint.nim")
  doAssert rc == 0, "build failed"

proc runCli(args: string): string =
  let cmd = (when defined(windows): exe else: "./" & exe) & " " & args
  result = execProcess(cmd)

proc main() =
  buildBinary()

  let tmpDir = getTempDir() / "entlint_ci"
  createDir(tmpDir)
  let f = tmpDir / "sample.txt"
  writeFile(f, "hello\n" &
               "AAAAAAAAAA\n" &
               "9aZ2Qm!X#C7yP0kV4uR3tY8wS1bL5nH6qJ2zD9eF0gM\n")

  let output = runCli("--path=" & tmpDir & " --preview --lines --threshold=3.5")

  doAssert output.contains("file="), "expected file= in output"
  doAssert output.contains("entropy="), "expected entropy= in output"
  doAssert output.contains("lines="), "expected lines= in output"
  doAssert output.contains("preview=\""), "expected preview=\" in output"

main()
