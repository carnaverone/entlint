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

  # 1) créer une ligne à HAUTE ENTROPIE (ASCII 33..122, pseudo-aléatoire)
  var hi = newString(96)
  for i in 0 ..< hi.len:
    hi[i] = char(33 + ((i * 73) mod 90))   # large alphabet imprimable -> entropie élevée

  # 2) pas de fuite sans --preview
  writeFile("sample.txt", hi & "\nmore text\n")
  let out1 = runOut("./entlint", @["file", "sample.txt", "--lines"])
  doAssert out1.contains("sample.txt")
  doAssert not out1.contains(hi[0 ..< 12])   # le contenu brut ne doit pas apparaître

  # 3) avec --preview: doit afficher un aperçu MASQUÉ
  let out2 = runOut("./entlint", @["file", "sample.txt", "--lines", "--preview"])
  doAssert out2.contains("preview=\"")
  let snippet = firstPreviewSnippet(out2)
  doAssert snippet.len > 0
  doAssert not hasAnyAlnum(snippet)          # tous les alphanum doivent être masqués

  # 4) exclusions fonctionnent
  createDir("dist")
  writeFile("dist/high.txt", "AAAAAAAAAAAAAAAAAAAAAA")
  let out3 = runOut("./entlint", @["scan", ".", "--exclude", "dist"])
  doAssert not out3.contains("dist/high.txt")

  # 5) codes de sortie
  writeFile("low.txt", "bonjour bonjour bonjour\n")
  doAssert runExit("./entlint", @["file", "low.txt"]) == 0

  # pseudo-aléatoire binaire pour déclencher l’entropie fichier
  var raw = newString(128)
  for i in 0 ..< raw.len:
    raw[i] = char((i * 73) mod 256)
  writeFile("high.bin", raw)
  doAssert runExit("./entlint", @["file", "high.bin"]) == 2

  echo "tests OK"
