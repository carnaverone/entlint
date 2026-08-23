# entlint

[![CI](https://github.com/carnaverone/entlint/actions/workflows/test.yml/badge.svg)](https://github.com/carnaverone/entlint/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`entlint` is a small, local-first secret linter written in **Nim**. It scans text files for long, high-entropy token candidates that may represent accidentally committed API keys, tokens, passwords, or generated credentials.

It is intentionally simple:

- **local only** — no uploads, telemetry, or external service dependency;
- **safe output** — raw candidate secrets are never printed;
- **single CLI** — build to one native executable;
- **CI-friendly** — deterministic exit codes and JSON output;
- **heuristic by design** — useful as a lightweight guardrail, not a substitute for provider-aware scanners.

Development version: **0.2.0**

> `0.2.0` is under review until it is formally released. The repository may contain newer behavior than the latest published release.

## What it detects

`entlint` tokenizes text without PCRE and evaluates candidate strings using Shannon entropy. By default, a candidate must:

1. be at least 20 characters long;
2. contain at least two character classes;
3. have entropy of at least 4.0 bits/character.

The scanner also applies conservative false-positive guards for UUIDs and obvious multi-segment URLs/paths. Common generated/build directories are skipped by default, binary files containing NUL bytes are ignored, and files larger than 2 MiB are skipped unless configured otherwise.

Because entropy is heuristic, false positives and false negatives are possible. For deep repository-history scans or provider-side credential verification, use a specialized tool such as Gitleaks or TruffleHog alongside `entlint`.

## Build

Requirements:

- Nim **1.6+** (package minimum)
- Nimble

The current GitHub CI validates the repository with the stable Nim toolchain. The package minimum is retained for compatibility, but minimum-version CI should be added before making stronger cross-version guarantees.

```bash
git clone https://github.com/carnaverone/entlint.git
cd entlint
nimble build -d:release
./entlint --version
```

Optional user-local installation:

```bash
mkdir -p ~/.local/bin
cp ./entlint ~/.local/bin/entlint
```

## Quick start

Scan the current repository:

```bash
entlint scan .
```

Include line numbers and masked previews:

```bash
entlint scan . --lines --preview
```

Scan one file:

```bash
entlint file ./config.txt --lines
```

Produce machine-readable JSON:

```bash
entlint scan src --json
```

Tune detection:

```bash
entlint scan . \
  --min 4.2 \
  --min-length 24 \
  --max-size 4MiB \
  --exclude fixtures \
  --exclude vendor
```

The v0.1-style form remains accepted:

```bash
entlint --path . --threshold 4.0
```

## CLI

```text
entlint scan [PATH] [options]
entlint file FILE [options]
```

| Option | Description |
| --- | --- |
| `--min N`, `--threshold N` | Shannon entropy threshold; default `4.0` |
| `--min-length N` | Minimum candidate length; default `20` |
| `--max-size N` | Maximum file size; bytes, `K/KiB`, or `M/MiB` |
| `--exclude PATTERN` | Exclude paths containing `PATTERN`; repeatable |
| `--no-default-excludes` | Disable built-in directory exclusions |
| `--preview` | Show a **masked** candidate preview |
| `--lines` | Include line numbers in human output |
| `--json` | Emit JSON on stdout |
| `--version` | Print version |
| `-h`, `--help` | Show help |

Default excluded directory components:

```text
.git node_modules nimcache zig-cache zig-out target dist build .cache
```

`--exclude` currently performs a case-sensitive path-substring match. It is **not** gitignore/glob syntax.

Recursive directory traversal skips symlinks and special files. If a symlink is supplied directly as the CLI scan target, `entlint` refuses to follow it and exits with code `1` rather than silently scanning outside the requested path boundary.

## Output safety

Human output never contains the full candidate token.

Example:

```text
HIGH src/example.txt:12 entropy=4.625 len=32 preview="Ab************************yz"
entlint: findings=1 scanned=14 skipped=3
```

`--json` follows the same rule. A preview is included only when `--preview` is explicitly supplied, and that preview remains masked.

Human-readable paths and error messages are sanitized so control characters cannot inject extra terminal/log lines. JSON strings are emitted through the standard JSON serializer.

Example shape:

```json
{
  "version": "0.2.0",
  "target": ".",
  "threshold": 4.0,
  "min_length": 20,
  "scanned_files": 14,
  "skipped_entries": 3,
  "errors": 0,
  "findings_count": 1,
  "findings": [
    {
      "path": "src/example.txt",
      "line": 12,
      "entropy": 4.625,
      "length": 32
    }
  ]
}
```

## Exit codes

| Code | Meaning |
| ---: | --- |
| `0` | Scan completed with no findings |
| `1` | Usage, I/O, safety-boundary, or scan error |
| `2` | One or more suspicious candidates found |

That makes CI usage straightforward:

```yaml
- name: Secret entropy check
  run: ./entlint scan . --json
```

A finding exits with code `2`, so a CI job can fail before a suspicious token is merged.

## Detection model

`entlint` is deliberately provider-agnostic. It does not maintain a catalog of cloud-provider token prefixes and does not attempt to authenticate or verify a credential over the network.

This gives it a narrow role:

```text
source text
    ↓
long token candidates
    ↓
identifier / obvious URL-path guards
    ↓
character-class check
    ↓
Shannon entropy threshold
    ↓
masked finding + deterministic exit code
```

Use `--min`, `--min-length`, `--exclude`, and `--max-size` to tune the scanner for a repository. A finding is a **review signal**, not proof that a credential is valid.

## Development and tests

Run the test suite:

```bash
nimble test -y
```

The test suite covers both scanner logic and the compiled CLI. It checks:

- entropy and tokenization;
- masked output guarantees;
- line-number reporting;
- UUID and URL/path false-positive guards;
- JWT-shaped opaque-token detection;
- JSON output;
- exit codes `0`, `1`, and `2`;
- binary-file skipping;
- maximum-size skipping and overflow rejection;
- explicit exclusions;
- default `.git` exclusion behavior;
- explicit symlink-target refusal on POSIX;
- control-character sanitization for human/log output;
- invalid/non-finite entropy thresholds.

The tests use synthetic values assembled at runtime. **Do not add real credentials or copied production tokens to fixtures.**

Project layout:

```text
src/entlint.nim        CLI and scanner implementation
tests/test_cli.nim     unit + CLI integration coverage
entlint.nimble         package metadata and test task
```

## Security model and limitations

`entlint`:

- does not connect to the network at runtime;
- does not verify whether a credential is active;
- does not scan Git history separately from files present in the target tree;
- does not print raw candidate secrets;
- refuses explicit symlink scan targets and does not follow symlinks recursively;
- intentionally skips binary data containing NUL bytes and oversized files by default;
- reads eligible files into memory rather than streaming them;
- uses heuristic entropy detection, so findings require review;
- does not yet implement gitignore-compatible ignore rules or SARIF output.

For responsible disclosure, see [`SECURITY.md`](SECURITY.md). Operational repository boundaries are documented separately in [`SECURITY_OPERATION_POLICY.md`](SECURITY_OPERATION_POLICY.md).

## Roadmap

Useful follow-up work for later releases includes:

- a documented ignore-file format;
- SARIF output for code-scanning platforms;
- minimum-supported-Nim CI coverage;
- optional provider-aware rules without network verification;
- streaming analysis for larger files;
- measured false-positive/false-negative benchmark corpora.

## Contributing

Contributions are welcome. Keep changes focused and local-first. See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT. See [`LICENSE`](LICENSE).

Copyright © 2025–2026 Carnaverone.
