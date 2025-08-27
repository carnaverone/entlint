import std/[os, osproc, strutils]

proc runExit(cmd: string; args: seq[string]): int =
  var p = startProcess(cmd, args = args, options = {poStdErrToStdOut, poUsePath})
  let code = waitForExit(p)
  close(p)
  code

proc runOut(cmd: string; args: seq[string]): string =
  execProcess(cmd, args = args, options = {poStdErrToStdOut, poUsePath})

proc hasAnyAlnum(s: string): bool =
  for c in s:
    if c.isAlphaNumeric: return true
  false

proc firstPreviewSnippet(s: string): string =
  ## extrait la première valeur entre preview="…"
  let k = "preview=\""
  let i = s.find(k)
  if i < 0: return ""
  let start = i + k.len
  let j = s.find('"', start)
  if j < 0: return s[start..^1]
  s[start ..< j]

when isMainModule:
  # build du binaire à tester
  discard runExit("nimble", @["build", "-d:release"])

  # 1) pas de fuite de contenu sans --preview
  writeFile("sample.txt", "MYSECRET-ABC123-XYZ789\nand some text\n")
  let out1 = runOut("./entlint", @["file", "sample.txt", "--lines"])
  doAssert out1.contains("sample.txt")
  doAssert not out1.contains("MYSECRET")   # ne doit pas apparaître

  # 2) avec --preview : aperçu MASQUÉ uniquement (pas d’alphanum dans le snippet)
  let out2 = runOut("./entlint", @["file", "sample.txt", "--lines", "--preview"])
  doAssert out2.contains("preview=\"")
  let snippet = firstPreviewSnippet(out2)
  doAssert snippet.len > 0
  doAssert not hasAnyAlnum(snippet)        # le snippet lui-même est masqué

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
