# entlint: tiny entropy linter (MIT) — "safe by default"
# Nim stdlib only. Works with Nim 1.6+ and 2.x.
# No external deps; JSON/plain output; exit code 0 = clean, 2 = findings.
# Author: carnaverone

import std/[os, strutils, sequtils, math, json]

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
    h -= p * (ln(p) / ln(2.0))
  result = h

proc isLikelyText(s: string): bool =
  ## Heuristic: consider a string "texty" if most bytes are printable/newline/tab.
  if s.len == 0: return true
  var good = 0
  for ch in s:
    if ch == '\n' or ch == '\r' or ch == '\t' or (ch >= ' ' and ch <= '~'):
      inc good
  result = good.float / s.len.float >= 0.85

# ---------- preview helper (ethics-by-design) ----------

proc previewRedact(s: string; maxChars = 24): string =
  ## Keep visual structure but redact alphanumerics; show only first maxChars.
  if s.len == 0: return ""
  let t = if s.len <= maxChars: s else: s[0 ..< maxChars]
  var buf = newString(t.len)              # avoid reserved word `out` in Nim 2
  for i, c in t:
    buf[i] = (if c.isAlphaNumeric: '*' else: c)
  result = buf & (if s.len > t.len: "…" else: "")

# ---------- model ----------

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

proc scanFile(path: string; minH: float; perLine: bool): (int, seq[Finding]) =
  ## Returns (#findings, list)
  var findings: seq[Finding] = @[]
  var content: string
  try:
    content = slurp(path)
  except CatchableError:
    return (0, @[])

  # File-level entropy (always)
  let hfile = entropyStr(content)
  if hfile >= minH and content.len >= 64:
    findings.add Finding(path: path, kind: "file", line: 0, entropy: hfile, size: content.len)

  # Line-level entropy (text files only, if requested)
  if perLine and isLikelyText(content):
    let lines = content.splitLines
    for i, ln in lines:
      if ln.len == 0: continue
      let h = entropyStr(ln)
      if h >= minH and ln.len >= 16:
        findings.add Finding(path: path, kind: "line", line: i+1, entropy: h, size: ln.len)

  (findings.len, findings)

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
  --preview      redact-and-show short line preview (safe by default)
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

  # parse common flags after subcommand
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
      break
    inc i

  if cmd == "file":
    if i >= args.len: usage(); quit(1)
    let file = args[i]
    if not fileExists(file): stderr.writeLine "missing file: ", file; quit(1)
    let (n, findings) = scanFile(file, minH, perLine)

    if jsonOut:
      var arr = newSeq[JsonNode]()
      for f in findings:
        var node = f.toJsonNode()
        if showPreview and f.kind == "line":
          # load the specific line again for preview
          try:
            let content = slurp(file)
            let lines = content.splitLines
            if f.line > 0 and f.line <= lines.len:
              node["preview"] = %previewRedact(lines[f.line - 1])
          except CatchableError:
            discard
        arr.add node
      echo %*{"file": file, "findings": arr, "count": n}
    else:
      if findings.len == 0:
        echo "No findings"
      else:
        # compute lines if we need preview for lines
        var lines: seq[string] = @[]
        if showPreview and perLine:
          try: lines = slurp(file).splitLines
          except CatchableError: lines = @[]
        for x in findings:
          if x.kind == "file":
            echo "[FILE] ", x.path, " ent=", formatFloat(x.entropy, ffDecimal, 3), " size=", x.size
          else:
            var pv = ""
            if showPreview and lines.len > 0 and x.line > 0 and x.line <= lines.len:
              pv = previewRedact(lines[x.line - 1])
            if showPreview and pv.len > 0:
              echo "[LINE] ", x.path, ":", x.line, " ent=", formatFloat(x.entropy, ffDecimal, 3), " preview=\"", pv, "\""
            else:
              echo "[LINE] ", x.path, ":", x.line, " ent=", formatFloat(x.entropy, ffDecimal, 3)
    quit(if findings.len == 0: 0 else: 2)

  elif cmd == "scan":
    if i >= args.len: usage(); quit(1)
    let root = args[i]
    if not dirExists(root): stderr.writeLine "missing directory: ", root; quit(1)

    var all: seq[Finding] = @[]
    for p in walkDirRec(root, {pcFile}):   # Nim 2.x signature
      if shouldSkip(p, maxSize, excludes): continue
      let (n, f) = scanFile(p, minH, perLine)
      if n > 0: all.add f

    if jsonOut:
      var arr = newSeq[JsonNode]()
      for f in all:
        var node = f.toJsonNode()
        if showPreview and f.kind == "line":
          try:
            let content = slurp(f.path)
            let lines = content.splitLines
            if f.line > 0 and f.line <= lines.len:
              node["preview"] = %previewRedact(lines[f.line - 1])
          except CatchableError:
            discard
        arr.add node
      echo %*{"root": root, "findings": arr, "count": all.len}
    else:
      if all.len == 0:
        echo "No findings"
      else:
        for x in all:
          if x.kind == "file":
            echo "[FILE] ", x.path, " ent=", formatFloat(x.entropy, ffDecimal, 3), " size=", x.size
          else:
            var pv = ""
            if showPreview:
              try:
                let ls = slurp(x.path).splitLines
                if x.line > 0 and x.line <= ls.len:
                  pv = previewRedact(ls[x.line - 1])
              except CatchableError:
                discard
            if showPreview and pv.len > 0:
              echo "[LINE] ", x.path, ":", x.line, " ent=", formatFloat(x.entropy, ffDecimal, 3), " preview=\"", pv, "\""
            else:
              echo "[LINE] ", x.path, ":", x.line, " ent=", formatFloat(x.entropy, ffDecimal, 3)
        echo "Total findings: ", all.len
    quit(if all.len == 0: 0 else: 2)

  else:
    usage(); quit(1)
