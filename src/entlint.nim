import std/[os, strutils, math, json]

const
  Version* = "0.2.0"
  DefaultThreshold* = 4.0
  DefaultMinLength* = 20
  DefaultMaxSize* = 2 * 1024 * 1024
  DefaultIgnoreFile* = ".entlintignore"
  MaxIgnoreFileSize = 256 * 1024
  MaxIgnoreRules = 2048
  MaxIgnoreRuleLength = 4096
  SarifRuleId = "ENTLINT001"
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
    ignoreFiles: seq[string]
    ignoreRuleCount: int
    wantPreview: bool
    wantLines: bool
    jsonOutput: bool
    sarifOutput: bool
    useDefaultExcludes: bool
    useDefaultIgnoreFile: bool

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
  --ignore-file FILE        load path-fragment exclusions from FILE (repeatable)
  --no-ignore-file          do not auto-load PATH/.entlintignore for directory scans
  --no-default-excludes     scan default excluded directories too
  --preview                 show masked previews only
  --lines                   include line numbers in human output
  --json                    machine-readable JSON on stdout
  --sarif                   SARIF 2.1.0 on stdout for code-scanning integrations
  --version                 print version and exit
  -h, --help                show this help and exit

Ignore-file format:
  blank lines and lines beginning with # are ignored;
  other lines are case-sensitive path substrings, not gitignore/glob syntax.

Exit codes:
  0  no findings
  1  usage, I/O, safety-boundary, or scan error
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

proc safeDisplayText*(s: string): string =
  ## Keep human/stderr output single-line and neutralize terminal controls.
  for ch in s:
    case ch
    of '\n':
      result.add("\\n")
    of '\r':
      result.add("\\r")
    of '\t':
      result.add("\\t")
    else:
      let code = ord(ch)
      if code < 32 or code == 127:
        result.add('?')
      else:
        result.add(ch)

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

proc slashCount(token: string): int =
  for ch in token:
    if ch == '/':
      inc result

proc isObviousUrlOrPath(token: string): bool =
  ## Avoid common false positives while keeping opaque slash-containing tokens.
  let slashes = slashCount(token)

  if token.startsWith("//") or token.startsWith("www."):
    return true

  if slashes >= 2 and
     (token.startsWith("/") or token.startsWith("./") or
      token.startsWith("../")):
    return true

  # A multi-segment dotted path is much more likely to be a URL/path than a
  # credential. Base64-like tokens normally have no dots; JWTs normally have
  # dots but no path separators, so those remain eligible.
  if slashes >= 2 and token.contains(".") and tokenClassCount(token) <= 3:
    return true

  false

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
  if isObviousUrlOrPath(token):
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

  let lines = text.splitLines()
  for lineIndex in 0 ..< lines.len:
    let line = lines[lineIndex]
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

proc pathMatchesPattern*(path, pattern: string): bool =
  ## Exclusion patterns are deliberately simple, normalized path substrings.
  if pattern.len == 0:
    return false
  let normalizedPath = path.replace("\\", "/")
  let normalizedPattern = pattern.replace("\\", "/")
  normalizedPath.contains(normalizedPattern)

proc parseIgnoreRules*(text: string): seq[string] =
  ## Parse .entlintignore-style path fragments without gitignore/glob semantics.
  if text.find('\0') >= 0:
    raise newException(ValueError, "ignore file contains NUL bytes")

  for rawLine in text.splitLines():
    var rule = rawLine.strip()
    if rule.len == 0 or rule.startsWith("#"):
      continue

    if rule.len > MaxIgnoreRuleLength:
      raise newException(ValueError, "ignore rule is too long")

    for ch in rule:
      let code = ord(ch)
      if code < 32 or code == 127:
        raise newException(ValueError, "ignore rule contains a control character")

    rule = rule.replace("\\", "/")
    result.add(rule)

    if result.len > MaxIgnoreRules:
      raise newException(ValueError, "too many ignore rules")

proc matchesUserExclusion(path: string; opts: ScanOptions): bool =
  for pattern in opts.excludes:
    if pathMatchesPattern(path, pattern):
      return true

proc relativeForDefaultExcludes(path, scanRoot: string): string =
  ## Default directory names are interpreted inside the selected scan root.
  ## Ancestors of the requested root must not make the whole scan disappear.
  try:
    result = relativePath(path, scanRoot)
  except CatchableError:
    result = path

proc shouldSkipDirectory(path, scanRoot: string; opts: ScanOptions): bool =
  if opts.useDefaultExcludes:
    let relative = relativeForDefaultExcludes(path, scanRoot)
    for component in DefaultExcludeDirs:
      if pathHasComponent(relative, component):
        return true

  matchesUserExclusion(path, opts)

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

  let maxAmount = BiggestInt(high(int64) div multiplier)
  if amount > maxAmount:
    raise newException(ValueError, "size is too large")

  result = int64(amount) * multiplier

proc loadIgnoreFile(path: string; opts: var ScanOptions; stats: var ScanStats) =
  try:
    let info = getFileInfo(path, followSymlink = false)
    if info.kind == pcLinkToFile or info.kind == pcLinkToDir:
      raise newException(ValueError, "refusing to follow ignore-file symlink")
    if info.isSpecial or info.kind != pcFile:
      raise newException(ValueError, "ignore file must be a regular file")

    let size = getFileSize(path)
    if size > BiggestInt(MaxIgnoreFileSize):
      raise newException(ValueError, "ignore file exceeds 256 KiB")

    let data = readFile(path)
    let rules = parseIgnoreRules(data)
    if opts.ignoreRuleCount + rules.len > MaxIgnoreRules:
      raise newException(ValueError, "too many active ignore rules across loaded files")

    for rule in rules:
      opts.excludes.add(rule)
    opts.ignoreRuleCount += rules.len
  except CatchableError as err:
    inc stats.errors
    stderr.writeLine("entlint: ignore file ", safeDisplayText(path), ": ",
                     safeDisplayText(err.msg))

proc loadConfiguredIgnoreFiles(target: string;
                               targetIsDirectory: bool;
                               opts: var ScanOptions;
                               stats: var ScanStats) =
  for ignorePath in opts.ignoreFiles:
    loadIgnoreFile(ignorePath, opts, stats)
    if stats.errors > 0:
      return

  if not targetIsDirectory or not opts.useDefaultIgnoreFile:
    return

  let defaultIgnorePath = target / DefaultIgnoreFile
  if fileExists(defaultIgnorePath) or dirExists(defaultIgnorePath):
    loadIgnoreFile(defaultIgnorePath, opts, stats)

proc scanOneFile(path: string; opts: ScanOptions; stats: var ScanStats) =
  # Built-in default exclusions describe directories only. A regular file may
  # legitimately be named "build", "target", "dist", etc. User/ignore rules
  # still apply to files.
  if matchesUserExclusion(path, opts):
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
    stderr.writeLine("entlint: ", safeDisplayText(path), ": ",
                     safeDisplayText(err.msg))

proc scanDirectory(path, scanRoot: string;
                   opts: ScanOptions; stats: var ScanStats) =
  try:
    for kind, entry in walkDir(path):
      case kind
      of pcFile:
        scanOneFile(entry, opts, stats)
      of pcDir:
        if shouldSkipDirectory(entry, scanRoot, opts):
          inc stats.skippedEntries
        else:
          scanDirectory(entry, scanRoot, opts, stats)
      else:
        # Do not follow symlinks or special files during directory traversal.
        inc stats.skippedEntries
  except CatchableError as err:
    inc stats.errors
    stderr.writeLine("entlint: ", safeDisplayText(path), ": ",
                     safeDisplayText(err.msg))

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

proc percentEncodeUriPath(path: string): string =
  ## Encode filesystem bytes as an RFC 3986 URI path while preserving '/'.
  const Hex = "0123456789ABCDEF"
  for ch in path:
    let code = ord(ch)
    let unreserved =
      (ch >= 'a' and ch <= 'z') or
      (ch >= 'A' and ch <= 'Z') or
      (ch >= '0' and ch <= '9') or
      ch in {'-', '.', '_', '~'}
    if unreserved or ch == '/':
      result.add(ch)
    else:
      result.add('%')
      result.add(Hex[(code shr 4) and 0x0f])
      result.add(Hex[code and 0x0f])

proc sarifArtifactUri(path: string): string =
  ## Prefer a repository-relative URI when invoked from the repository root.
  var candidate = path
  try:
    let relative = relativePath(path, getCurrentDir())
    if relative.len > 0 and not relative.startsWith(".."):
      candidate = relative
  except CatchableError:
    discard

  var normalized = candidate.replace("\\", "/")
  while normalized.startsWith("./") and normalized.len > 2:
    normalized = normalized[2 .. ^1]
  result = percentEncodeUriPath(normalized)

proc sarifRule(): JsonNode =
  result = newJObject()
  result["id"] = %SarifRuleId
  result["name"] = %"HighEntropySecretCandidate"

  var shortDescription = newJObject()
  shortDescription["text"] = %"Potential high-entropy secret candidate"
  result["shortDescription"] = shortDescription

  var fullDescription = newJObject()
  fullDescription["text"] = %(
    "A long, high-entropy token-like value was found. Review it as a possible " &
    "credential or generated secret. entlint never verifies credentials over the network."
  )
  result["fullDescription"] = fullDescription

  var defaultConfiguration = newJObject()
  defaultConfiguration["level"] = %"warning"
  result["defaultConfiguration"] = defaultConfiguration

  var properties = newJObject()
  var tags = newJArray()
  tags.add(%"security")
  tags.add(%"secrets")
  properties["tags"] = tags
  result["properties"] = properties

proc findingToSarif(finding: Finding): JsonNode =
  result = newJObject()
  result["ruleId"] = %SarifRuleId
  result["level"] = %"warning"

  var message = newJObject()
  message["text"] = %(
    "Potential high-entropy secret candidate; entropy=" &
    formatFloat(finding.entropy, ffDecimal, 3) &
    ", length=" & $finding.length & ". Review before committing or publishing."
  )
  result["message"] = message

  var artifactLocation = newJObject()
  artifactLocation["uri"] = %sarifArtifactUri(finding.path)

  var region = newJObject()
  region["startLine"] = %finding.line

  var physicalLocation = newJObject()
  physicalLocation["artifactLocation"] = artifactLocation
  physicalLocation["region"] = region

  var location = newJObject()
  location["physicalLocation"] = physicalLocation

  var locations = newJArray()
  locations.add(location)
  result["locations"] = locations

proc printSarif(stats: ScanStats) =
  var root = newJObject()
  root["$schema"] = %"https://json.schemastore.org/sarif-2.1.0.json"
  root["version"] = %"2.1.0"

  var driver = newJObject()
  driver["name"] = %"entlint"
  driver["semanticVersion"] = %Version
  driver["informationUri"] = %"https://github.com/carnaverone/entlint"
  var rules = newJArray()
  rules.add(sarifRule())
  driver["rules"] = rules

  var tool = newJObject()
  tool["driver"] = driver

  var run = newJObject()
  run["tool"] = tool
  var results = newJArray()
  for finding in stats.findings:
    results.add(findingToSarif(finding))
  run["results"] = results

  var runs = newJArray()
  runs.add(run)
  root["runs"] = runs

  echo $root

proc printHuman(stats: ScanStats; opts: ScanOptions) =
  for finding in stats.findings:
    var message = "HIGH " & safeDisplayText(finding.path)
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
    ignoreFiles: @[],
    ignoreRuleCount: 0,
    wantPreview: false,
    wantLines: false,
    jsonOutput: false,
    sarifOutput: false,
    useDefaultExcludes: true,
    useDefaultIgnoreFile: true
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
    elif arg == "--sarif":
      opts.sarifOutput = true
    elif arg == "--no-default-excludes":
      opts.useDefaultExcludes = false
    elif arg == "--no-ignore-file":
      opts.useDefaultIgnoreFile = false
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
          quit("invalid entropy threshold: " & safeDisplayText(value), 1)
      elif optionValue(arg, "min-length", value, index, args):
        try:
          opts.minLength = parseInt(value)
        except ValueError:
          quit("invalid --min-length value: " & safeDisplayText(value), 1)
      elif optionValue(arg, "max-size", value, index, args):
        try:
          opts.maxSize = parseSize(value)
        except ValueError:
          quit("invalid --max-size value: " & safeDisplayText(value), 1)
      elif optionValue(arg, "exclude", value, index, args):
        opts.excludes.add(value)
      elif optionValue(arg, "ignore-file", value, index, args):
        opts.ignoreFiles.add(value)
      elif arg.startsWith("-"):
        quit("unknown option: " & safeDisplayText(arg) & "\nUse --help.", 1)
      else:
        if targetSet:
          quit("only one scan target may be supplied", 1)
        target = arg
        targetSet = true

    inc index

  if opts.jsonOutput and opts.sarifOutput:
    quit("--json and --sarif are mutually exclusive", 1)
  if opts.threshold != opts.threshold or
     opts.threshold <= 0.0 or opts.threshold > 8.0:
    quit("entropy threshold must be a finite value > 0 and <= 8", 1)
  if opts.minLength < 8:
    quit("--min-length must be at least 8", 1)
  if command == "file" and not targetSet:
    quit("file command requires a file path", 1)

  var stats: ScanStats
  try:
    let targetInfo = getFileInfo(target, followSymlink = false)

    if targetInfo.kind == pcLinkToFile or targetInfo.kind == pcLinkToDir:
      stderr.writeLine("entlint: refusing to follow symlink target: ",
                       safeDisplayText(target))
      inc stats.errors
    elif targetInfo.isSpecial:
      stderr.writeLine("entlint: special file not scanned: ",
                       safeDisplayText(target))
      inc stats.errors
    elif targetInfo.kind == pcFile:
      loadConfiguredIgnoreFiles(target, false, opts, stats)
      if stats.errors == 0:
        scanOneFile(target, opts, stats)
    elif targetInfo.kind == pcDir:
      if command == "file":
        stderr.writeLine("entlint: expected a regular file: ",
                         safeDisplayText(target))
        inc stats.errors
      else:
        loadConfiguredIgnoreFiles(target, true, opts, stats)
        if stats.errors == 0:
          scanDirectory(target, target, opts, stats)
  except OSError:
    if command == "file":
      stderr.writeLine("entlint: file not found or inaccessible: ",
                       safeDisplayText(target))
    else:
      stderr.writeLine("entlint: path not found or inaccessible: ",
                       safeDisplayText(target))
    inc stats.errors

  if opts.sarifOutput:
    printSarif(stats)
  elif opts.jsonOutput:
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
