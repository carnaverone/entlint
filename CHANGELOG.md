# Changelog

All notable user-facing changes to `entlint` are documented here.

## 0.2.0 - 2026-08-23

### Added

- `scan` and `file` commands.
- CI-friendly native JSON output with `--json`.
- SARIF 2.1.0 output with `--sarif` for code-scanning integrations.
- Repeatable path exclusions with `--exclude`.
- Automatic root-level `.entlintignore` loading for directory scans.
- Repeatable explicit ignore files with `--ignore-file` and opt-out with `--no-ignore-file`.
- Configurable minimum candidate length with `--min-length`.
- Configurable maximum file size with `--max-size`.
- Built-in exclusions for common generated/cache directories.
- Stable exit code `2` when suspicious candidates are found.
- Masked preview output that never prints the full candidate.
- CLI integration coverage for JSON, SARIF, exit codes, exclusions, binary skipping, size limits, ignore files and symlink boundaries.
- A 22-case synthetic detection regression corpus with explicit TP/FP/TN/FN gates.
- Public-facing security reporting policy.

### Changed

- Detection now operates on long token candidates instead of whole-file entropy.
- Default entropy threshold is `4.0` bits/character.
- Minimum supported Nim version is **2.0.0**, validated in CI alongside the current stable toolchain.
- Binary files containing NUL bytes are skipped.
- Recursive directory traversal skips symlinks and special files.
- Explicit symlink scan targets are refused with an error rather than followed.
- UUIDs and obvious multi-segment URLs/paths are filtered as common false positives.
- Exclusion matching normalizes path separators while keeping simple case-sensitive substring semantics.
- Non-finite entropy thresholds such as `NaN` are rejected.
- Oversized `--max-size` values that would overflow are rejected.
- Human-readable paths/errors sanitize control characters to avoid terminal/log injection.
- `--json` and `--sarif` are mutually exclusive machine-output modes.
- `nimble test` now runs both CLI/integration coverage and the detection-quality corpus gate.
- v0.1 `--path` and `--threshold` forms remain accepted for compatibility.

### Security

- Raw candidate values are never emitted in human, JSON, or SARIF output.
- Test fixtures use synthetic values assembled at runtime.
- Runtime scanner behavior remains local-only with no network service dependency.
- SARIF generation is local-only and does not upload results.
- Explicit and recursive symlink boundaries are covered by regression tests.
- Ignore files must be regular files; symlinked ignore files are refused.
- Ignore files reject NUL/control characters and are bounded to 256 KiB, 2,048 rules and 4,096 characters per rule.

### Detection-quality baseline

The initial public synthetic corpus records 8 true positives, 0 false negatives, 10 true negatives and 4 known false positives. The four known false positives are structured release/version/package/filename identifiers. See `docs/DETECTION_CORPUS.md`; these values are a regression baseline, not a claim of real-world accuracy.
