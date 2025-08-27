# entlint

**Nim CLI – entropy linter.** Detect high-entropy blobs/lines (likely secrets) in files and repos.  
Safe-by-default (no network, no raw content printed), **MIT** licensed.

## Features
- **Entropy scan (file / per-line)** with Shannon bits/byte
- **Threshold** (default `--min 4.0`) to flag likely secrets
- **Redacted preview** `--preview` (shows masked snippet, no raw leakage)
- **Exclusions** `--exclude <pat>` (repeatable)
- **JSON output** for CI and tooling
- **Exit codes**: `0` no findings, `2` findings, `1` usage/error

## Install / Build
```bash
nimble build -d:release
# resulting binary: ./entlint (or entlint.exe on Windows)
