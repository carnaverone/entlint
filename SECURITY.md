# Security Policy

`entlint` is a local-first secret linter. Security and privacy are part of the product contract: scan data stays on the machine and raw candidate secrets must not be printed by the tool.

## Supported versions

| Version | Status |
| --- | --- |
| `0.2.x` | Supported |
| `0.1.x` | Legacy / best-effort fixes |

## Security properties

The project is designed to preserve these properties:

- no telemetry or runtime network upload;
- no external service dependency at runtime;
- no raw candidate values in human, JSON, or SARIF output;
- masked previews only when `--preview` is explicitly requested;
- terminal/control characters are sanitized in human-readable paths and errors;
- binary and oversized files are handled according to documented limits;
- recursive scans do not follow symlinks or special files;
- ignore files are bounded and must be regular files;
- malformed or overflowing limits are rejected;
- deterministic exit codes are used for automation.

A regression that violates one of these properties should be treated as a security issue.

## Scope and limitations

Entropy and pattern-based detection is heuristic. False positives and false negatives are possible. A clean result is not proof that a repository contains no credentials.

Ignore configuration intentionally suppresses matching paths and must be reviewed carefully in security-sensitive repositories.

## Reporting a vulnerability

Do not open a public issue containing a real credential, token, private key, `.env` file, private scan log, or unredacted finding.

Use GitHub private vulnerability reporting when available. Otherwise contact the repository owner through the public GitHub profile/contact path and provide only the minimum information required to reproduce the issue safely.

Please include the affected version or commit, operating system and Nim version when relevant, minimal synthetic reproduction steps, expected behavior, observed behavior, and security impact.

Never send a real production secret as a proof of concept.

## Disclosure handling

Security reports should be reproduced with synthetic data before a fix is published. Fixes should include regression coverage whenever practical.

If a real secret is discovered in repository content, revoke or rotate it, remove it from active content, and assess whether Git history also requires cleanup.

## Dependencies and network model

The scanner uses the Nim standard library and is intended to run without network access. Building from source requires a Nim toolchain; CI may access normal package and tooling infrastructure to provision the build environment.
