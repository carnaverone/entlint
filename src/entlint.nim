# entlint: tiny entropy linter (MIT) — "safe by default"
# Nim stdlib only. Works with Nim 1.6+ and 2.x.

import std/[os, strutils, sequtils, math, json, times]

# ---------- entropy helpers ----------

proc entropyStr(s: string): float =
  ## Shannon entropy (bits per byte) computed on raw bytes of the string
  if s.len == 0: return 0.0
  var freq: array[256, int]
  for ch in s: inc freq[ord(ch)]
  let n = s.len.float
  var h = 0.0
  for c in freq:
    if c == 0: continue
    let p = c.float / n
    h -= p * log2(p)
  h

proc isProbablyTextBytes(data: string): bool =
  ## crude text check: reject if too many control bytes or NULs
  if data.len == 0: return true
  var ctrl = 0
  var nul = 0
  for ch in data:
    let b = uint8(ord(ch))
    if b == 0'u8: inc nul
    if b < 9'u8 or (b in {11'u8, 12'u8}) or (b > 126'u8 and b < 160'u8):
      inc ctrl
  let fCtrl = ctrl.float / data.len.float
  let fNul  = nul.float / data.len.float
  (fCtrl < 0.30) and (fNul < 0.01)

proc slurp(path: string): string =
  readFile(path)

# ---------- redaction / preview ----------

proc previewRedact(s: string; maxChars = 24): string =
  ## Keep visual structure but redact alphanumerics; show only first maxChars.
  if s.len == 0: return ""
  let t = if s.len <= maxChars: s else: s[0 ..< maxChars]
  var buf = newString(t.len)              # <- renommé: évite le mot-clé `out`
  for i, c in t:
    buf[i] = (if c.isAlphaNumeric: '*' else: c)
  result = buf & (if s.len > t.len: "…" else: "")

# ---------- reporting ----------

type Finding = object
  path: string
  kind: string       # "file" or "line"
  line: int          # 1-based for lines, 0 for file
  entropy: float
  size: int

proc toJsonNode(f: Finding): JsonNode =
  %*{"path": f.path, "kind": f.kind, "line": f.line, "entropy": f.entropy, "size": f.size}

# ---------- scanning ----------

proc shouldSkip(path: string; maxSize: int; excludes: seq[string]): bool =
  let base = splitFile(path).name
  if base == ".DS_Store": return true
  for pat in excludes:
    if path.contains(pat): return true
  try:
    let s = getFileSize(path)
    if s > maxSize: return true
  except CatchableError:
    return true
  false

proc scanFile(path: string; minH: float; perLine: bool; jsonOut: bool): (int, seq[Finding]) =
  var findings: seq[Finding] = @[]
  var content: string
  try:
    content = slurp(path)
  except CatchableError:
    if not jsonOut: stderr.writeLine "warn: cannot read: " & path
    return (0, findings)

  let h = entropyStr(content)
  let fsz = content.len
  if h >= minH:
    findings.add Finding(path: path, kind: "file", line: 0, entropy: h, size: fsz)

  if perLine and isProbablyTextBytes(content):
    let ls = content.splitLines
    for i, line in ls:
      if line.len < 16: continue
      let e = entropyStr(line)
      if e >= minH:
        findings.add Finding(path: path, kind: "line", line: i+1, entropy: e, size: line.len)

  (findings.len, findings)

proc scanTree(root: string; minH: float; perLine: bool; jsonOut: bool; maxSize: int; excludes: seq[string]): (int, seq[Finding]) =
  var total = 0
  var all: seq[Finding] = @[]

  for path in walkDirRec(root, {pcFile}, yieldFilter = proc (k: PathComponent): bool =
    let name = k.path.splitPath.tail
    if name in [".git", "node_modules", "zig-cache", "zig-out", "target", "dist", "build"]: return false
    true
  ):
    if shouldSkip(path, maxSize, excludes): continue
    let (n, f) = scanFile(path, minH, perLine, jsonOut)
    total += n
    if n > 0: all.add f

  (total, all)

# ---------- CLI ----------

proc usage() =
  echo """
entlint — entropy linter (Nim, MIT)

Usage:
  entlint scan <path> [--min 4.0] [--lines] [--json] [--max-size 2097152] [--exclude <pat>]... [--preview]
  entlint file <file> [--min 4.0] [--lines] [--json] [--preview]
  entlint --help

Options:
  --min <f>      threshold in bits/byte (default 4.0)
  --lines        also analyze per-line (text files)
  --json         JSON output (machine friendly)
  --max-size <n> skip files larger than N bytes (default 2 MiB for scan)
  --exclude <p>  skip paths containing <p> (repeatable)
  --preview      show redacted snippet for line-findings (no raw content)

Exit codes: 0 = no findings, 2 = findings, 1 = usage/error
"""

when isMainModule:
  var minH = 4.0
  var perLine = false
  var jsonOut = false
  var maxSize = 2 * 1024 * 1024
  var excludes: seq[string] = @[]
  var showPreview = false

  let args = commandLineParams()
  if args.len == 0 or args[0] in ["-h", "--help"]:
    usage(); quit(0)

  var i = 0
  template next(): string =
    inc i; if i >= args.len: quit(1); args[i]

  let cmd = args[i]
  inc i

  while i < args.len and args[i].startsWith("--"):
    case args[i]
    of "--lines": perLine = true
    of "--json":  jsonOut = true
    of "--preview": showPreview = true
    of "--min":
      let v = next()
      try: minH = parseFloat(v)
      except ValueError: quit(1)
    of "--max-size":
      let v = next()
      try: maxSize = parseInt(v)
      except ValueError: quit(1)
    of "--exclude":
      excludes.add next()
    else:
      stderr.writeLine "unknown flag: " & args[i]; quit(1)
    inc i

  if cmd == "file":
    if i >= args.len: usage(); quit(1)
    let f = args[i]
    if not fileExists(f): stderr.writeLine "missing file: " & f; quit(1)
    let (_, findings) = scanFile(f, minH, perLine, jsonOut)
    if jsonOut:
      let arr = newJArray()
      for x in findings: arr.add x.toJsonNode
      echo $arr
    else:
      if findings.len == 0:
        echo "OK: no findings in ", f
      else:
        # no content printed; optional redacted preview for lines
        let content = try: readFile(f) except: ""
        let ls = content.splitLines
        for x in findings:
          if x.kind == "file":
            echo "[FILE] ", x.path, " ent=", formatFloat(x.entropy, ffDecimal, 3), " size=", x.size
          else:
            var pv = ""
            if showPreview and x.line > 0 and x.line <= ls.len:
              pv = previewRedact(ls[x.line - 1])
            if showPreview and pv.len > 0:
              echo "[LINE] ", x.path, ":", x.line, " ent=", formatFloat(x.entropy, ffDecimal, 3), " preview=\"", pv, "\""
            else:
              echo "[LINE] ", x.path, ":", x.line, " ent=", formatFloat(x.entropy, ffDecimal, 3)
    quit(if findings.len == 0: 0 else: 2)

  elif cmd == "scan":
    if i >= args.len: usage(); quit(1)
    let root = args[i]
    if not dirExists(root): stderr.writeLine "missing dir: " & root; quit(1)
    let (n, findings) = scanTree(root, minH, perLine, jsonOut, maxSize, excludes)
    if jsonOut:
      let arr = newJArray()
      for x in findings: arr.add x.toJsonNode
      echo $arr
    else:
      if n == 0:
        echo "OK: no findings under ", root
      else:
        # To avoid content leaks: only metadata; optional redacted preview for lines
        for x in findings:
          case x.kind
          of "file":
            echo "[FILE] ", x.path, " ent=", formatFloat(x.entropy, ffDecimal, 3), " size=", x.size
          else:
            var pv = ""
            if showPreview:
              try:
                let content = readFile(x.path)
                let ls = content.splitLines
                if x.line > 0 and x.line <= ls.len:
                  pv = previewRedact(ls[x.line - 1])
              except CatchableError:
                discard
            if showPreview and pv.len > 0:
              echo "[LINE] ", x.path, ":", x.line, " ent=", formatFloat(x.entropy, ffDecimal, 3), " preview=\"", pv, "\""
            else:
              echo "[LINE] ", x.path, ":", x.line, " ent=", formatFloat(x.entropy, ffDecimal, 3)
        echo "Total findings: ", n
    quit(if n == 0: 0 else: 2)

  else:
    usage(); quit(1)
