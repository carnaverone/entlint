import std/[os, osproc, strutils]

when defined(windows):
  const exe = "entlint.exe"
else:
  const exe = "entlint"

proc buildBinary(): void =
  let rc = execShellCmd("nim c -d:release -o:" & exe & " src/entlint.nim")
  doAssert rc == 0, "build failed"

proc runCli(args: string): string =
  let cmd =
    when defined(windows): exe & " " & args
    else: "./" & exe & " " & args
  result = execProcess(cmd)

proc main() =
  # 1) construire binaire
  buildBinary()

  # 2) fichier temporaire avec un contenu à entropie haute
  let tmpDir = getTempDir() / "entlint_ci"
  createDir(tmpDir)
  let f = tmpDir / "sample.txt"
  # chaîne assez diverse pour dépasser un petit seuil
  writeFile(f, "hello\n" &
               "AAAAAAAAAA\n" &
               "9aZ2Qm!X#C7yP0kV4uR3tY8wS1bL5nH6qJ2zD9eF0gM\n")

  # 3) exécuter avec preview + lines
  let out = runCli("--path=" & tmpDir & " --preview --lines --threshold=3.5")

  # 4) assertions minimales
  doAssert out.contains("file="), "expected file= in output"
  doAssert out.contains("entropy="), "expected entropy= in output"
  doAssert out.contains("lines="), "expected lines= in output"
  doAssert out.contains("preview=\""), "expected preview=\" in output"

main()
