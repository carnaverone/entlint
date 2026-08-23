# Security Policy

`entlint` is a local-first secret linter. Security and privacy are part of the product contract: scan data stays on the machine, and raw candidate secrets must never be printed by the tool.

## Supported versions

| Version | Status |
| --- | --- |
| `0.2.x` | Active development |
| `0.1.x` | Legacy / best-effort fixes |

Until `0.2.0` is formally released, the `0.2.x` behavior described in this repository should be treated as pre-release code under review.

## Security properties

The project is designed to preserve these properties:

- no telemetry;
- no network upload;
- no external service dependency at runtime;
- no raw secret values in normal human output;
- no raw secret values in JSON output;
- masked previews only when `--preview` is explicitly requested;
- human-readable paths and errors sanitize terminal/control characters;
- binary files containing NUL bytes are skipped;
- oversized files are skipped according to `--max-size`;
- invalid or overflowing size limits are rejected;
- recursive directory traversal does not follow symlinks or special files;
- an explicit symlink scan target is refused instead of followed;
- ignore files must be regular files and are never followed through symlinks;
- ignore-file rules reject NUL/control characters and enforce bounded file/rule sizes;
- findings use deterministic exit codes suitable for CI.

A regression that violates one of these properties should be treated as a security issue.

## Ignore configuration

`.entlintignore`, `--ignore-file`, and `--exclude` intentionally suppress scanning of matching paths. They are repository/operator configuration, not a security proof.

Review ignore-rule changes carefully in security-sensitive repositories. An attacker who can modify ignore configuration may be able to hide matching files from an entropy scan even though the scanner itself remains local and non-networked.

The current ignore-file parser deliberately does **not** implement gitignore glob or negation semantics. It accepts bounded, case-sensitive path fragments only. This keeps matching predictable and reduces parser complexity.

## What to report

Useful security reports include, for example:

- a code path that prints an unmasked candidate secret;
- unexpected network access or telemetry;
- path handling that escapes the requested scan scope;
- symlink traversal, whether recursive, through an explicit target, or through an ignore file;
- ignore-file parsing that bypasses documented size/control-character boundaries;
- control-character or terminal escape injection in human-readable output;
- malformed input that causes unsafe disclosure;
- CLI parsing that bypasses configured safety limits;
- denial-of-service conditions triggered by ordinary repository content;
- release artifacts that do not correspond to the published source.

Detection false positives and false negatives are usually normal bug reports rather than security vulnerabilities unless they create a concrete disclosure or boundary-bypass risk.

## Reporting a vulnerability

Do **not** open a public issue containing a real credential, token, private key, `.env` file, private scan log, or unredacted finding.

Use GitHub private vulnerability reporting when it is available for this repository. If that option is not available, contact the repository owner through the GitHub profile/contact path and provide only the minimum information needed to reproduce the issue safely.

A good report contains:

1. affected version or commit;
2. operating system and Nim version when relevant;
3. minimal reproduction steps using synthetic data;
4. expected behavior;
5. observed behavior;
6. security impact;
7. whether any real credential was exposed.

Never send a real production secret as a proof of concept. Replace it with a synthetic value that demonstrates the same behavior.

## Disclosure handling

Security reports should be reproduced with synthetic data before a fix is published. Fixes should include regression coverage whenever practical.

If a real secret is discovered in repository content, do not copy or repost it. Revoke/rotate the credential through the relevant provider, remove it from active repository content, and assess whether history cleanup is required.

## Dependencies and network model

The scanner implementation uses the Nim standard library and is intended to run without network access. Building from source requires a Nim toolchain; project CI may access normal package/tooling infrastructure to provision that build environment.

The runtime scanner itself must not require a cloud account, API key, or network connection.

## Operational repository rules

Contributor and automation boundaries specific to this repository are documented separately in [`SECURITY_OPERATION_POLICY.md`](SECURITY_OPERATION_POLICY.md), [`AGENTS.md`](AGENTS.md), and [`CODEX.md`](CODEX.md). Those files govern repository operations; this document describes the public security policy of the software.
