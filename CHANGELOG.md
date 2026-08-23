# Changelog

All notable user-facing changes to `entlint` are documented here.

## 0.2.0 - Unreleased

### Added

- `scan` and `file` commands.
- CI-friendly JSON output with `--json`.
- Repeatable path exclusions with `--exclude`.
- Configurable minimum candidate length with `--min-length`.
- Configurable maximum file size with `--max-size`.
- Built-in exclusions for common generated/cache directories.
- Stable exit code `2` when suspicious candidates are found.
- Masked preview output that never prints the full candidate.
- CLI integration coverage for JSON, exit codes, exclusions, binary skipping, size limits and symlink boundaries.
- Public-facing security reporting policy.

### Changed

- Detection now operates on long token candidates instead of whole-file entropy.
- Default entropy threshold is `4.0` bits/character.
- Binary files containing NUL bytes are skipped.
- Recursive directory traversal skips symlinks and special files.
- Explicit symlink scan targets are refused with an error rather than followed.
- UUIDs and obvious multi-segment URLs/paths are filtered as common false positives.
- Non-finite entropy thresholds such as `NaN` are rejected.
- Oversized `--max-size` values that would overflow are rejected.
- Human-readable paths/errors sanitize control characters to avoid terminal/log injection.
- v0.1 `--path` and `--threshold` forms remain accepted for compatibility.

### Security

- Raw candidate values are never emitted in human or JSON output.
- Test fixtures use synthetic values assembled at runtime.
- Runtime scanner behavior remains local-only with no network service dependency.
- Explicit and recursive symlink boundaries are covered by regression tests.
