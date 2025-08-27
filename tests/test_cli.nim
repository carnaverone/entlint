import std/[os, osproc, strformat, strutils, re]

proc runExit(cmd: string; args: seq[string]): int =
  var p = startProcess(cmd, args = args, options = {poStdErrToStdOut, poUsePath})
  let code = waitForExit(p)   # Nim 2: récupère le code ici
  close(p)                    # ferme le process proprement
  code

proc runOut(cmd: string; args: seq[string]): string =
  execProcess(cmd, args = args, options = {poStdErrToStdOut, poUsePath})

when isMainModule:
  # build du binaire à tester
  discard runExit("nimble", @["build", "-d:release"])

  # 1) pas de fuite de contenu sans --preview
  writeFile("sample.txt", "MYSECRET-ABC123-XYZ789\nand some text\n")
  let out1 = runOut("./entlint", @["file", "sample.txt", "--lines"])
  doAssert out1.contains("sample.txt")
  doAssert not out1.contains("MYSECRET")   # ne doit pas apparaître

  # 2) avec --preview : aperçu masqué (aucun alphanum)
  let out2 = runOut("./entlint", @["file", "sample.txt", "--lines", "--preview"])
  doAssert out2.contains("preview=\"")
  doAssert not contains(out2, re"[A-Za-z0-9]")

  # 3) exclusions fonctionnent
  createDir("dist")
  writeFile("dist/high.txt", "AAAAAAAAAAAAAAAAAAAAAA")
  let out3 = runOut("./entlint", @["scan", ".", "--exclude", "dist"])
  doAssert not out3.contains("dist/high.txt")

  # 4) codes de sortie
  writeFile("low.txt", "bonjour bonjour bonjour\n")
  doAssert runExit("./entlint", @["file", "low.txt"]) == 0

  # pseudo-aléatoire pour déclencher une entropie élevée
  var raw = newString(128)
  for i in 0 ..< raw.len:
    raw[i] = char((i * 73) mod 256)
  writeFile("high.bin", raw)
  let rc = runExit("./entlint", @["file", "high.bin"])
  doAssert rc == 2

  echo "tests OK"
