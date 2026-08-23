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

### Changed

- Detection now operates on long token candidates instead of whole-file entropy.
- Default entropy threshold is `4.0` bits/character.
- Binary files containing NUL bytes are skipped.
- Symlinks and special files are not followed.
- v0.1 `--path` and `--threshold` forms remain accepted for compatibility.

### Security

- Raw candidate values are never emitted in human or JSON output.
- Test fixtures use synthetic values assembled at runtime.
