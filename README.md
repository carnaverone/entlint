<p align="center">
  <img src="./docs/assets/entlint.png"
       alt="entlint — local entropy-based secret scanner for Nim"
       width="100%">
</p>

<h1 align="center">entlint</h1>

<p align="center">
  <strong>Local-first entropy-based secret scanning for source trees and CI.</strong>
</p>

<p align="center">
  <a href="https://github.com/carnaverone/entlint/actions/workflows/test.yml"><img alt="CI" src="https://github.com/carnaverone/entlint/actions/workflows/test.yml/badge.svg"></a>
  <img alt="Version 0.2.0" src="https://img.shields.io/badge/version-0.2.0-2563eb">
  <img alt="Nim 2.0+" src="https://img.shields.io/badge/Nim-%E2%89%A52.0.0-f3c72e">
  <img alt="Local first" src="https://img.shields.io/badge/runtime-local--first-16a34a">
  <img alt="SARIF 2.1.0" src="https://img.shields.io/badge/SARIF-2.1.0-7c3aed">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-64748b"></a>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> ·
  <a href="#command-line">CLI</a> ·
  <a href="#security-and-output-safety">Security</a> ·
  <a href="#detection-quality">Detection Quality</a> ·
  <a href="SECURITY.md">Security Policy</a> ·
  <a href="CONTRIBUTING.md">Contribute</a>
</p>

Current release: **0.2.0**

---

`entlint` is a compact native secret linter written in **Nim**. It scans text files for long, high-entropy token candidates that may represent accidentally committed API keys, access tokens, passwords, or generated credentials.

It is deliberately narrow: scanning stays local, raw candidate secrets are never printed, and findings are treated as review signals rather than proof that a credential is valid.

> [!IMPORTANT]
> `entlint` does not upload findings, contact credential providers, or verify whether a detected value is live. For Git-history analysis or provider-aware verification, use specialized tooling alongside it.

## At a glance

| Capability | Current behavior |
|---|---|
| Runtime | **Local-first; no runtime network dependency** |
| Detection | Shannon entropy + conservative candidate guards |
| Minimum Nim | **2.0.0** |
| Default threshold | **4.0 bits / character** |
| Default minimum token length | **20 characters** |
| Default maximum file size | **2 MiB** |
| Human output | Raw candidate values are **never printed** |
| Machine output | Native JSON + **SARIF 2.1.0** |
| Ignore configuration | `.entlintignore` + explicit ignore files |
| Exit codes | `0` clean · `1` error · `2` findings |
| CI platforms | Linux · macOS · Windows |
| License | **MIT** |

## Why entlint exists

Secret scanners often need to solve two different problems:

1. recognize known credential formats;
2. notice suspicious opaque values that do not match a provider-specific signature.

`entlint` focuses on the second problem. It provides a small provider-agnostic entropy layer that can run locally or as a CI gate without sending source material elsewhere.

The scanner is useful for:

- catching suspicious opaque tokens before merge;
- adding a lightweight local secret check to development workflows;
- producing JSON for automation;
- producing SARIF 2.1.0 for downstream security tooling;
- complementing provider-aware or Git-history scanners.

## Quick start

### Build from source

Requirements:

- Nim **2.0.0+**
- Nimble

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

### Scan the current repository

```bash
entlint scan .
```

### Scan one file

```bash
entlint file ./config.txt --lines
```

### Show masked previews and line numbers

```bash
entlint scan . --preview --lines
```

### Generate JSON

```bash
entlint scan . --json
```

### Generate SARIF

```bash
entlint scan . --sarif > entlint.sarif
```

### Tune a scan

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

## Example finding

Human-readable output masks the candidate:

```text
HIGH src/example.txt:12 entropy=4.625 len=32 preview="Ab************************yz"
entlint: findings=1 scanned=14 skipped=3
```

The original candidate is not printed. Without `--preview`, even the masked preview is omitted.

## Detection model

By default, a candidate must:

1. be at least **20 characters** long;
2. contain at least **two character classes**;
3. reach at least **4.0 bits/character** of Shannon entropy.

The scanner then applies targeted guards for obvious non-secret structures such as UUIDs and multi-segment URL/path forms.

```text
source text
    ↓
candidate extraction
    ↓
identifier / URL-path guards
    ↓
character-class check
    ↓
Shannon entropy threshold
    ↓
masked finding + deterministic exit code
```

Candidate characters include letters, digits and:

```text
_ - + / . ~
```

JWT-shaped opaque values remain eligible for detection.

Entropy is heuristic. False positives and false negatives are possible, so every finding requires review.

## Command line

```text
entlint scan [PATH] [options]
entlint file FILE [options]
```

| Option | Description |
|---|---|
| `--min N`, `--threshold N` | Shannon entropy threshold; default `4.0` |
| `--min-length N` | Minimum candidate length; default `20` |
| `--max-size N` | Maximum file size; bytes, `K/KiB`, or `M/MiB` |
| `--exclude PATTERN` | Exclude paths containing `PATTERN`; repeatable |
| `--ignore-file FILE` | Load an additional path-fragment ignore file; repeatable |
| `--no-ignore-file` | Disable automatic scan-root `.entlintignore` loading |
| `--no-default-excludes` | Disable built-in directory exclusions |
| `--preview` | Show a **masked** candidate preview |
| `--lines` | Include line numbers in human output |
| `--json` | Emit native entlint JSON |
| `--sarif` | Emit SARIF 2.1.0 |
| `--version` | Print version |
| `-h`, `--help` | Show help |

`--json` and `--sarif` are mutually exclusive.

`--exclude` performs a case-sensitive path-substring match. It is **not** gitignore/glob syntax.

## Scan boundaries

Default excluded directory components:

```text
.git node_modules nimcache zig-cache zig-out target dist build .cache
```

Regular files merely named `build` or `target` remain eligible; the built-in rules target directory components.

Recursive traversal:

- does not follow symlinks;
- skips special file objects;
- skips binary files containing NUL bytes;
- skips files above the configured maximum size.

If a symlink is supplied directly as the scan target, `entlint` refuses to follow it and exits with code `1` rather than silently crossing the requested path boundary.

## `.entlintignore`

For directory scans, `entlint` automatically loads a regular file named `.entlintignore` from the **scan root**. It does not search parent directories.

Example:

```text
# generated fixtures
fixtures/generated/
docs/snapshots/
third_party/cache.bin
```

Rules are intentionally deterministic:

- blank lines are ignored;
- lines whose first non-whitespace character is `#` are comments;
- active lines are **case-sensitive path substrings**;
- `\` is normalized to `/` for matching;
- `*` and `?` have no glob semantics;
- `!` negation is not implemented.

Additional ignore files can be supplied explicitly:

```bash
entlint scan . --ignore-file ./config/ci.entlintignore
```

`--ignore-file` is repeatable. `--no-ignore-file` disables only automatic scan-root loading; explicitly supplied files are still loaded.

For safety, ignore files:

- must be regular files;
- cannot be symlinks;
- reject NUL or control characters in active rules;
- are limited to **256 KiB**;
- are limited to **2,048 active rules**;
- are limited to **4,096 characters per rule**.

> [!WARNING]
> Ignore configuration changes scanner visibility. Review `.entlintignore` changes like other security-sensitive repository configuration.

## Security and output safety

`entlint` is designed not to become another secret-exfiltration surface.

It:

- performs no runtime network requests;
- uploads no files, findings, JSON, or SARIF;
- never validates credentials against providers;
- never prints raw candidate secrets;
- refuses explicit symlink scan targets;
- does not recursively follow symlinks;
- refuses symlinked ignore files;
- sanitizes human-readable paths and errors against control-character log injection;
- uses synthetic test credentials only.

### JSON

Native JSON contains finding metadata rather than the candidate value:

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

A preview is included only when `--preview` is explicitly requested, and remains masked.

### SARIF 2.1.0

```bash
entlint scan . --sarif > entlint.sarif
```

| Contract | Current behavior |
|---|---|
| SARIF version | `2.1.0` |
| Tool name | `entlint` |
| Rule ID | `ENTLINT001` |
| Rule name | `HighEntropySecretCandidate` |
| Physical file location | Yes |
| `startLine` | Yes |
| Raw secret | **Never** |
| Runtime upload | **Never** |

A clean scan emits valid SARIF with an empty `results` array. Findings still return exit code `2` after the SARIF document is written.

Uploading SARIF to GitHub Code Scanning or another consumer is a separate operator or CI action outside `entlint`.

For responsible disclosure and operational constraints, see [`SECURITY.md`](SECURITY.md) and [`SECURITY_OPERATION_POLICY.md`](SECURITY_OPERATION_POLICY.md).

## Exit codes

| Code | Meaning |
|---:|---|
| `0` | Scan completed with no findings |
| `1` | Usage, I/O, safety-boundary, ignore-configuration, or scan error |
| `2` | One or more suspicious candidates found |

Example CI gate:

```yaml
- name: Secret entropy check
  run: ./entlint scan .
```

## Detection quality

`entlint` includes a public **synthetic regression corpus** so heuristic trade-offs are measured rather than hidden.

Current v0.2 controlled baseline:

| Metric | Value |
|---|---:|
| Corpus cases | **22** |
| True positives | **8** |
| False negatives | **0** |
| True negatives | **10** |
| False positives | **4** |
| Recall on labeled positive cases | **100%** |
| Precision | **66.7%** |
| Specificity | **71.4%** |

The four known false positives are structured release/version/package/filename identifiers. They remain documented rather than being silently suppressed by an unvalidated heuristic.

The corpus fails CI if a labeled positive becomes a false negative or if the false-positive count regresses beyond the documented bound.

> [!NOTE]
> These figures describe a **small controlled synthetic regression corpus**. They are not claims of real-world scanner accuracy.

See [`docs/DETECTION_CORPUS.md`](docs/DETECTION_CORPUS.md).

## What entlint is — and is not

| entlint is | entlint is not |
|---|---|
| Lightweight local secret-linting guardrail | Credential-validity checker |
| Entropy-based candidate detector | Provider credential catalog |
| Current source-tree scanner | Dedicated Git-history scanner |
| CI failure gate | Remote security service |
| JSON/SARIF producer | Automatic SARIF uploader |
| Review-signal generator | Proof that a finding is an active secret |

## CI and release validation

Normal CI validates the full test suite across:

| Platform | Nim 2.0.0 | Stable Nim |
|---|:---:|:---:|
| Ubuntu | ✅ | ✅ |
| Windows | ✅ | ✅ |
| macOS | ✅ | ✅ |

Release automation additionally verifies:

- stable `vMAJOR.MINOR.PATCH` tag format;
- tag ancestry on the repository default branch;
- version agreement across `entlint.nimble`, source, README and CHANGELOG;
- the full test suite;
- Linux, macOS and Windows native builds;
- clean and finding smoke tests;
- raw-candidate masking behavior;
- per-binary SHA-256 checksum generation;
- publication only after every build succeeds.

<details>
<summary><strong>Test coverage</strong></summary>

The suite covers scanner logic, the compiled CLI and detection-quality regression cases, including:

- entropy and tokenization;
- masked-output guarantees;
- line-number reporting;
- UUID and URL/path false-positive guards;
- JWT-shaped opaque-token detection;
- native JSON output;
- SARIF 2.1.0 structure, metadata and locations;
- clean SARIF with an empty result set;
- `--json` / `--sarif` mutual exclusion;
- exit codes `0`, `1`, and `2`;
- binary-file skipping;
- maximum-size skipping and overflow rejection;
- explicit exclusions;
- automatic and explicit ignore-file loading;
- malformed, oversized, missing and symlinked ignore-file rejection;
- explicit symlink-target refusal on POSIX;
- control-character sanitization;
- invalid or non-finite entropy thresholds;
- TP/FP/TN/FN regression bounds.

Tests use synthetic values assembled at runtime. **Do not add real credentials or copied production tokens to fixtures.**

</details>

<details>
<summary><strong>Known limitations</strong></summary>

- Entropy detection is heuristic and can produce false positives and false negatives.
- Some long structured release/version/package/filename identifiers are documented false positives.
- Provider-side credential validity is not checked.
- Git history is not scanned separately from files present in the selected tree.
- Eligible files are currently read into memory rather than streamed.
- `.entlintignore` uses substring rules rather than gitignore-compatible glob/negation semantics.
- Binary content containing NUL bytes and oversized files are skipped by design.

</details>

<details>
<summary><strong>Repository structure</strong></summary>

```text
entlint/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── SECURITY.md
├── SECURITY_OPERATION_POLICY.md
├── CONTRIBUTING.md
├── AGENTS.md
├── REPO_BOUNDARY.md
├── entlint.nimble
├── src/
│   └── entlint.nim
├── tests/
│   ├── test_cli.nim
│   └── test_detection_corpus.nim
├── docs/
│   ├── assets/
│   │   └── entlint.png
│   ├── DETECTION_CORPUS.md
│   └── RELEASE_CHECKLIST.md
└── .github/
    └── workflows/
```

</details>

## Roadmap

Current follow-up work is tracked publicly:

| Area | Direction |
|---|---|
| Detection precision | Reduce structured-identifier false positives without corpus regressions |
| Corpus | Expand audited benign and positive synthetic cases |
| Large files | Add bounded streaming analysis |
| SARIF | Add stable privacy-preserving fingerprints |
| Repository governance | Protect `main` with required review/CI policy |

See the [GitHub issue tracker](https://github.com/carnaverone/entlint/issues).

## Documentation

| Need | Document |
|---|---|
| Security reporting and guarantees | [`SECURITY.md`](SECURITY.md) |
| Operational security boundaries | [`SECURITY_OPERATION_POLICY.md`](SECURITY_OPERATION_POLICY.md) |
| Detection corpus and metrics | [`docs/DETECTION_CORPUS.md`](docs/DETECTION_CORPUS.md) |
| Release gates | [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md) |
| Contribution workflow | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| Repository boundaries | [`REPO_BOUNDARY.md`](REPO_BOUNDARY.md) |
| Release history | [`CHANGELOG.md`](CHANGELOG.md) |

## Contributing

Contributions are welcome, especially changes that preserve the project's narrow security model: detection-quality improvements, synthetic corpus expansion, false-positive reduction, output interoperability, cross-platform behavior, documentation, and bounded performance improvements.

Start with [`CONTRIBUTING.md`](CONTRIBUTING.md).

Do **not** submit real credentials or copied production secrets as fixtures.

## License

`entlint` is released under the **MIT License**. See [`LICENSE`](LICENSE).

---

<p align="center">
  Maintained by <strong>Carnaverone Studio</strong><br>
  Copyright © 2025–2026 Carnaverone
</p>
