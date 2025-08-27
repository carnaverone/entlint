# entlint
## Ethics & Limits
- Offline-only; prints **metadata** only (no raw content).
- Use on code you **own** or are **authorized** to audit.
- `--preview` shows a **redacted** snippet to avoid leaking secrets.
- In CI, prefer `--json` and fail on exit code `2` (policy violations).

Entropy linter (Nim). Detects high-entropy blobs/lines (likely secrets). MIT.
