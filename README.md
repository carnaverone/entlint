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

Usage

entlint --help
entlint scan <path> [--min 4.0] [--lines] [--json] [--max-size 2097152] [--exclude <pat>]... [--preview]
entlint file <file> [--min 4.0] [--lines] [--json] [--preview]

Common flags

    --min <f> entropy threshold in bits/byte (default 4.0)

    --lines also analyze per-line (for text files)

    --json machine-friendly output

    --max-size skip files larger than N bytes (default 2 MiB) in scan

    --exclude skip paths containing <pat> (repeatable)

    --preview show redacted snippet for line findings (no raw alphanumerics)

Examples

# quick repo scan (metadata only)
entlint scan . --lines

# scan with redacted preview and exclusions
entlint scan . --lines --preview --exclude node_modules --exclude dist

# per-file check, JSON output (good for CI)
entlint file .env --json

# strict threshold
entlint scan src --min 4.2

CI

This repo ships:

    .github/workflows/test.yml – runs nimble build + nimble test on push/PR

    .github/workflows/release.yml – builds binaries for Linux/macOS/Windows and
    attaches them to a GitHub Release when you push a tag v*

Create a release from the UI or:

git tag v0.1.1 && git push origin v0.1.1

Ethics & Limits

    Offline-only; prints metadata (path/line/entropy), no raw content by default.

    --preview shows a redacted snippet to avoid secret leakage.

    Use on code you own or are authorized to audit.

    Treat exit code 2 as a policy violation in CI.

See also: SECURITY.md
and DISCLAIMER.md

.
License

MIT © Carnaverone
