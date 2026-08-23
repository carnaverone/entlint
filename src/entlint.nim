import std/[os, strutils, math, json]

const
  Version* = "0.2.0"
  DefaultThreshold* = 4.0
  DefaultMinLength* = 20
  DefaultMaxSize* = 2 * 1024 * 1024
  DefaultExcludeDirs = [".git", "node_modules", "nimcache", "zig-cache",
                        "zig-out", "target", "dist", "build", ".cache"]

type
  Finding* = object
    path*: string
    line*: int
    entropy*: float
    length*: int
    preview*: string

  ScanOptions = object
    threshold: float
    minLength: int
    maxSize: int64
    excludes: seq[string]
    wantPreview: bool
    wantLines: bool
    jsonOutput: bool
    useDefaultExcludes: bool

  ScanStats = object
    scannedFiles: int
    skippedEntries: int
    errors: int
    findings: seq[Finding]

proc usage() =
  echo "entlint v", Version, """
Local entropy-based secret linter. Raw candidate secrets are never printed.

Usage:
  entlint scan [PATH] [options]
  entlint file FILE [options]
  entlint [--path PATH] [options]        # v0.1 compatibility

Options:
  --min N, --threshold N    entropy threshold in bits/character (default: 4.0)
  --min-length N            minimum candidate length (default: 20)
  --max-size N              maximum file size; accepts bytes, K/KiB, M/MiB
                            (default: 2 MiB)
  --exclude PATTERN         exclude paths containing PATTERN (repeatable)
  --no-default-excludes     scan default excluded directories too
  --preview                 show masked previews only
  --lines                   include line numbers in human output
  --json                    machine-readable JSON on stdout
  --version                 print version and exit
  -h, --help                show this help and exit

Exit codes:
  0  no findings
  1  usage, I/O, or scan error
  2  one or more suspicious candidates found
"""

proc shannonEntropy*(s: string): float =
  if s.len == 0:
    return 0.0

  var counts: array[256, int]
  for ch in s:
    inc counts[ord(ch) and 0xff]

  let n = s.len.float
  for count in counts:
    if count > 0:
      let p = count.float / n
      result -= p * (ln(p) / ln(2.0))

proc maskSecret*(s: string): string =
  ## Return a stable masked representation without exposing the full candidate.
  if s.len == 0:
    return ""
  if s.len <= 6:
    return "*".repeat(s.len)

  result = s[0 .. 1]
  result.add("*".repeat(s.len - 4))
  result.add(s[^2 .. ^1])

proc findPreview*(s: string; win = 32; thr = DefaultThreshold): string =
  ## Compatibility helper from v0.1. The returned preview is always masked.
  if win <= 0:
    return ""

  var i = 0
  while i + win <= s.len:
    let candidate = s[i ..< i + win]
    if shannonEntropy(candidate) >= thr:
      return maskSecret(candidate)
    inc i

  if s.len > 0 and s.len < win and shannonEntropy(s) >= thr:
    return maskSecret(s)

proc isCandidateChar(ch: char): bool =
  (ch >= 'a' and ch <= 'z') or
  (ch >= 'A' and ch <= 'Z') or
  (ch >= '0' and ch <= '9') or
  ch in {'_', '-', '+', '/', '.', '~'}

proc candidateTokens*(line: string; minLength = DefaultMinLength): seq[string] =
  ## Split a line into secret-like token candidates without regex/PCRE.
  var current = ""

  for ch in line:
    if isCandidateChar(ch):
      current.add(ch)
    else:
      if current.len >= minLength:
        result.add(current)
      current.setLen(0)

  if current.len >= minLength:
    result.add(current)

proc tokenClassCount(token: string): int =
  var lower, upper, digit, special: bool

  for ch in token:
    if ch >= 'a' and ch <= 'z':
      lower = true
    elif ch >= 'A' and ch <= 'Z':
      upper = true
    elif ch >= '0' and ch <= '9':
      digit = true
    else:
      special = true

  result = ord(lower) + ord(upper) + ord(digit) + ord(special)

proc isUuidLike(token: string): bool =
  if token.len != 36:
    return false

  for i, ch in token:
    if i == 8 or i == 13 or i == 18 or i == 23:
      if ch != '-':
        return false
    elif not ((ch >= '0' and ch <= '9') or
              (ch >= 'a' and ch <= 'f') or
              (ch >= 'A' and ch <= 'F')):
      return false

  true

proc isLikelySecretToken(token: string; threshold: float; minLength: int): bool =
  if token.len < minLength:
    return false
  if isUuidLike(token):
    return false
  if tokenClassCount(token) < 2:
    return false

  shannonEntropy(token) >= threshold

proc scanText*(text: string;
               path: string = "<memory>";
               threshold: float = DefaultThreshold;
               minLength: int = DefaultMinLength;
               wantPreview: bool = false): seq[Finding] =
  ## Scan in-memory text. This is useful for tests and integrations.
  if text.find('\0') >= 0:
    return @[]

  for lineIndex, line in text.splitLines():
    for token in candidateTokens(line, minLength):
      if isLikelySecretToken(token, threshold, minLength):
        let preview = if wantPreview: maskSecret(token) else: ""
        result.add(Finding(
          path: path,
          line: lineIndex + 1,
          entropy: shannonEntropy(token),
          length: token.len,
          preview: preview
        ))

proc pathHasComponent(path, component: string): bool =
  let normalized = path.replace("\\", "/")
  for part in normalized.split('/'):
    if part == component:
      return true

proc shouldSkipPath(path: string; opts: ScanOptions): bool =
  if opts.useDefaultExcludes:
    for component in DefaultExcludeDirs:
      if pathHasComponent(path, component):
        return true

  for pattern in opts.excludes:
    if pattern.len > 0 and path.contains(pattern):
      return true

proc parseSize(value: string): int64 =
  var text = value.strip().toLowerAscii()
  var multiplier: int64 = 1

  if text.endsWith("kib"):
    multiplier = 1024
    text = text[0 ..< text.len - 3]
  elif text.endsWith("kb"):
    multiplier = 1000
    text = text[0 ..< text.len - 2]
  elif text.endsWith("k"):
    multiplier = 1024
    text = text[0 ..< text.len - 1]
  elif text.endsWith("mib"):
    multiplier = 1024 * 1024
    text = text[0 ..< text.len - 3]
  elif text.endsWith("mb"):
    multiplier = 1000 * 1000
    text = text[0 ..< text.len - 2]
  elif text.endsWith("m"):
    multiplier = 1024 * 1024
    text = text[0 ..< text.len - 1]

  let amount = parseBiggestInt(text)
  if amount <= 0:
    raise newException(ValueError, "size must be greater than zero")

  result = int64(amount) * multiplier

proc scanOneFile(path: string; opts: ScanOptions; stats: var ScanStats) =
  if shouldSkipPath(path, opts):
    inc stats.skippedEntries
    return

  try:
    let size = getFileSize(path)
    if size > BiggestInt(opts.maxSize):
      inc stats.skippedEntries
      return

    let data = readFile(path)
    if data.find('\0') >= 0:
      inc stats.skippedEntries
      return

    inc stats.scannedFiles
    for finding in scanText(data, path, opts.threshold, opts.minLength,
                            opts.wantPreview):
      stats.findings.add(finding)
  except CatchableError as err:
    inc stats.errors
    stderr.writeLine("entlint: ", path, ": ", err.msg)

proc scanDirectory(path: string; opts: ScanOptions; stats: var ScanStats) =
  try:
    for kind, entry in walkDir(path):
      case kind
      of pcFile:
        scanOneFile(entry, opts, stats)
      of pcDir:
        if shouldSkipPath(entry, opts):
          inc stats.skippedEntries
        else:
          scanDirectory(entry, opts, stats)
      else:
        # Do not follow symlinks or special files.
        inc stats.skippedEntries
  except CatchableError as err:
    inc stats.errors
    stderr.writeLine("entlint: ", path, ": ", err.msg)

proc findingToJson(finding: Finding; includePreview: bool): JsonNode =
  result = newJObject()
  result["path"] = %finding.path
  result["line"] = %finding.line
  result["entropy"] = %finding.entropy
  result["length"] = %finding.length
  if includePreview:
    result["preview"] = %finding.preview

proc printJson(stats: ScanStats; target: string; opts: ScanOptions) =
  var root = newJObject()
  root["version"] = %Version
  root["target"] = %target
  root["threshold"] = %opts.threshold
  root["min_length"] = %opts.minLength
  root["scanned_files"] = %stats.scannedFiles
  root["skipped_entries"] = %stats.skippedEntries
  root["errors"] = %stats.errors
  root["findings_count"] = %stats.findings.len

  var findings = newJArray()
  for finding in stats.findings:
    findings.add(findingToJson(finding, opts.wantPreview))
  root["findings"] = findings

  echo $root

proc printHuman(stats: ScanStats; opts: ScanOptions) =
  for finding in stats.findings:
    var message = "HIGH " & finding.path
    if opts.wantLines:
      message.add(":" & $finding.line)
    message.add(" entropy=" & formatFloat(finding.entropy, ffDecimal, 3))
    message.add(" len=" & $finding.length)
    if opts.wantPreview:
      message.add(" preview=\"" & finding.preview & "\"")
    echo message

  if stats.findings.len == 0:
    echo "entlint: clean scanned=", stats.scannedFiles,
         " skipped=", stats.skippedEntries
  else:
    echo "entlint: findings=", stats.findings.len,
         " scanned=", stats.scannedFiles,
         " skipped=", stats.skippedEntries

proc optionValue(arg, name: string;
                 value: var string;
                 index: var int;
                 args: seq[string]): bool =
  let full = "--" & name
  let prefix = full & "="

  if arg == full:
    if index + 1 >= args.len:
      quit("missing value for " & full, 1)
    value = args[index + 1]
    inc index
    return true

  if arg.startsWith(prefix):
    value = arg[prefix.len .. ^1]
    return true

proc main() =
  var opts = ScanOptions(
    threshold: DefaultThreshold,
    minLength: DefaultMinLength,
    maxSize: int64(DefaultMaxSize),
    excludes: @[],
    wantPreview: false,
    wantLines: false,
    jsonOutput: false,
    useDefaultExcludes: true
  )

  let args = commandLineParams()
  var command = "scan"
  var target = "."
  var targetSet = false
  var index = 0

  if args.len > 0 and (args[0] == "scan" or args[0] == "file"):
    command = args[0]
    index = 1

  while index < args.len:
    let arg = args[index]

    if arg == "-h" or arg == "--help":
      usage()
      quit(0)
    elif arg == "--version":
      echo Version
      quit(0)
    elif arg == "--preview":
      opts.wantPreview = true
    elif arg == "--lines":
      opts.wantLines = true
    elif arg == "--json":
      opts.jsonOutput = true
    elif arg == "--no-default-excludes":
      opts.useDefaultExcludes = false
    else:
      var value = ""
      if optionValue(arg, "path", value, index, args):
        target = value
        targetSet = true
      elif optionValue(arg, "min", value, index, args) or
           optionValue(arg, "threshold", value, index, args):
        try:
          opts.threshold = parseFloat(value)
        except ValueError:
          quit("invalid entropy threshold: " & value, 1)
      elif optionValue(arg, "min-length", value, index, args):
        try:
          opts.minLength = parseInt(value)
        except ValueError:
          quit("invalid --min-length value: " & value, 1)
      elif optionValue(arg, "max-size", value, index, args):
        try:
          opts.maxSize = parseSize(value)
        except ValueError:
          quit("invalid --max-size value: " & value, 1)
      elif optionValue(arg, "exclude", value, index, args):
        opts.excludes.add(value)
      elif arg.startsWith("-"):
        quit("unknown option: " & arg & "\nUse --help.", 1)
      else:
        if targetSet:
          quit("only one scan target may be supplied", 1)
        target = arg
        targetSet = true

    inc index

  if opts.threshold <= 0.0 or opts.threshold > 8.0:
    quit("entropy threshold must be > 0 and <= 8", 1)
  if opts.minLength < 8:
    quit("--min-length must be at least 8", 1)
  if command == "file" and not targetSet:
    quit("file command requires a file path", 1)

  var stats: ScanStats
  if command == "file":
    if not fileExists(target):
      stderr.writeLine("entlint: file not found: ", target)
      inc stats.errors
    else:
      scanOneFile(target, opts, stats)
  else:
    if fileExists(target):
      scanOneFile(target, opts, stats)
    elif dirExists(target):
      scanDirectory(target, opts, stats)
    else:
      stderr.writeLine("entlint: path not found: ", target)
      inc stats.errors

  if opts.jsonOutput:
    printJson(stats, target, opts)
  else:
    printHuman(stats, opts)

  if stats.errors > 0:
    quit(1)
  if stats.findings.len > 0:
    quit(2)
  quit(0)

when isMainModule:
  main()
