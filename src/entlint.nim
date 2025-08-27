import std/[os, strutils, math, times, sequtils]

const Version = "0.1.1"

proc usage() =
  echo "entlint v", Version, """
Usage:
  entlint [--path DIR] [--threshold N] [--preview] [--lines] [--help] [--version]

Options:
  --path DIR        root directory to scan (default: ".")
  --threshold N     Shannon entropy threshold (default: 7.5)
  --preview         print preview=\"...\" for first high-entropy hit per file
  --lines           also print lines=COUNT
  --version         print version and exit
  --help            show this help and exit
"""

# -------- entropy helpers --------

proc shannonEntropy*(s: string): float =
  if s.len == 0: return 0.0
  var counts: array[256, int]
  for ch in s:
    inc counts[ord(ch) and 0xff]
  let n = s.len.float
  var e = 0.0
  for c in counts:
    if c > 0:
      let p = c.float / n
      e -= p * (ln(p) / ln(2.0))
  return e

proc safeSnippet(s: string, start: int, win: int): string =
  let a = max(0, start)
  let b = min(s.len, a + win)
  result = s[a ..< b]
  result = result.replace("\"", "'").replace("\n", " ").replace("\r", " ")

proc findPreview*(s: string; win = 32; thr = 7.5): string =
  var i = 0
  while i + win <= s.len:
    let e = shannonEntropy(s[i ..< i+win])
    if e >= thr: return safeSnippet(s, i, win)
    inc i, 1
  if s.len > 0 and s.len < win and shannonEntropy(s) >= thr:
    return safeSnippet(s, 0, s.len)
  return ""

# -------- file analysis --------

proc shouldSkipPath(p: string): bool =
  # Vérifie juste si le chemin contient l'un des dossiers à ignorer
  for dir in [".git", "node_modules", "zig-cache", "zig-out", "target", "dist", "build", ".cache"]:
    if dir in p: return true
  return false

proc analyzeFile(path: string; thr: float; wantPreview, wantLines: bool) =
  try:
    if getFileSize(path) == 0: return
    let data = readFile(path)
    let e = shannonEntropy(data)
    let flag = if e >= thr: "HIGH" else: "OK"
    echo "file=", path
    echo "entropy=", formatFloat(e, ffDecimal, 3), " flag=", flag
    if wantLines:
      let lc = if data.len == 0: 0 else: data.count('\n') + 1
      echo "lines=", lc
    if wantPreview:
      var pv = findPreview(data, 32, thr)
      if pv.len == 0: pv = ""
      echo "preview=\"", pv, "\""
  except CatchableError as err:
    echo "file=", path
    echo "error=", err.msg

# -------- CLI parsing --------

proc parseEq(arg, name: string; val: var string; i: var int; args: seq[string]): bool =
  let prefix = "--" & name & "="
  if arg == "--" & name:
    if i + 1 < args.len:
      val = args[i+1]; inc i, 1
      return true
    else:
      quit "missing value for --" & name, 1
  elif arg.startsWith(prefix):
    val = arg[prefix.len .. ^1]
    return true
  return false

proc main() =
  var root = "."
  var threshold = 7.5
  var wantPreview = false
  var wantLines = false

  let args = commandLineParams()
  var i = 0
  while i < args.len:
    let a = args[i]
    if a == "--help" or a == "-h":
      usage(); quit(0)
    elif a == "--version":
      echo Version; quit(0)
    elif a == "--preview":
      wantPreview = true
    elif a == "--lines":
      wantLines = true
    else:
      var sval: string
      if parseEq(a, "path", sval, i, args): root = sval
      elif parseEq(a, "threshold", sval, i, args):
        try: threshold = parseFloat(sval)
        except ValueError: quit "invalid --threshold value: " & sval, 1
      else:
        quit "unknown option: " & a & "\nUse --help.", 1
    inc i

  for p in walkDirRec(root):
    if shouldSkipPath(p): continue
    try:
      if fileExists(p): analyzeFile(p, threshold, wantPreview, wantLines)
    except CatchableError:
      discard

when isMainModule:
  main()
