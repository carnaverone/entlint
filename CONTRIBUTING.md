# Contributing to entlint

Thanks for helping improve `entlint`.

## Principles

Changes should preserve the project's core properties:

- local-only scanning;
- no telemetry or network upload;
- no raw secret output;
- no external runtime dependency;
- deterministic CLI behavior suitable for CI.

## Development

Requirements:

- Nim 2.0.0 or newer;
- Nimble.

Build:

```bash
nimble build -d:release
```

Test:

```bash
nimble test -y
```

## Test data

Never commit real credentials, copied production tokens, private `.env` content, or raw scanner reports.

When a test needs high-entropy input, assemble a clearly synthetic value from short fragments at runtime so the repository itself does not contain a realistic credential fixture.

## Pull requests

Keep pull requests small and focused. A useful PR should include:

1. the behavior being changed;
2. tests for that behavior;
3. README/help updates when the CLI changes;
4. confirmation that output remains masked;
5. no release/deployment changes unless they are reviewed separately.

Breaking CLI changes should be called out explicitly.

## Security issues

Do not open a public issue containing a real secret. Follow [`SECURITY.md`](SECURITY.md) for security reporting.
