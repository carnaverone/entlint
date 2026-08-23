# Detection Corpus — v0.2 Baseline

`entlint` includes a small synthetic detection corpus to make false-positive and false-negative behavior measurable instead of relying only on anecdotal examples.

This is a **regression corpus**, not a scientific benchmark of real-world secret detection. It contains no production credentials, copied API keys, private data, or provider-issued tokens. Secret-like candidates are assembled from short synthetic fragments at runtime.

## Current baseline

The v0.2 corpus contains **22 labeled cases**:

- 8 intentionally secret-like opaque candidates;
- 14 intentionally benign values.

Expected current result:

| Metric | Count |
| --- | ---: |
| True positives | 8 |
| False negatives | 0 |
| True negatives | 10 |
| False positives | 4 |

Derived values for this small corpus:

- recall: **100%** (`8 / 8`);
- precision: **66.7%** (`8 / 12`);
- benign specificity: **71.4%** (`10 / 14`).

These percentages describe only this controlled corpus. They must **not** be presented as general detection accuracy.

## Positive classes

The positive side intentionally exercises token shapes that an entropy-only guard should notice:

- mixed alphanumeric/symbol token;
- JWT-shaped opaque token;
- Base64-like mixed token;
- URL-safe opaque token;
- dotted opaque token;
- long alphanumeric token;
- opaque token containing one slash;
- token using underscore, dash and tilde separators.

All 8 are expected to be detected at the default threshold.

## Benign classes

The benign side currently covers:

- ordinary text;
- UUID;
- URL;
- absolute path;
- lowercase SHA-256-shaped digest;
- lowercase SHA-512-shaped digest;
- Git-commit-hash-shaped value;
- release identifier;
- version identifier;
- package/build identifier;
- filename/version identifier;
- long digits-only value;
- long lowercase-only value;
- repeated low-entropy value.

The current known false positives are the four structured identifiers:

1. release identifier;
2. version identifier;
3. package/build identifier;
4. filename/version identifier.

This is intentional documentation of the present heuristic boundary, not an attempt to hide it.

## Regression gate

`tests/test_detection_corpus.nim` currently enforces:

```text
total = 22
true positives = 8
false negatives = 0
true negatives >= 10
false positives <= 4
```

A change that introduces a false negative or increases the known false-positive count fails `nimble test`.

A future improvement may reduce false positives below four, but it should do so only with a defensible rule and without silently reducing positive coverage.

## Why hashes are not filtered explicitly yet

Lowercase SHA-256/SHA-512/Git-style hexadecimal values in this corpus currently fall below the default `4.0` entropy threshold and are therefore clean without a dedicated digest exception.

Adding a blanket "all hex digests are safe" rule would be risky because some real credentials are hex-shaped. The project should prefer measured evidence before introducing such a suppression rule.

## Next useful corpus work

Good additions for later iterations include:

- more benign generated identifiers from build systems and package managers;
- PEM-like/public-key metadata without embedding actual private keys;
- synthetic provider-shaped tokens, clearly not provider-issued;
- Unicode surrounding text and unusual filenames;
- larger generated corpora for threshold tuning;
- per-threshold comparison (`3.5`, `4.0`, `4.5`, etc.);
- performance measurements separated from detection-quality measurements.

The corpus should remain small enough to audit manually and safe enough to keep public.
