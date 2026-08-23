# Release Checklist

Use this checklist before publishing an `entlint` release. A passing branch CI is necessary but not sufficient for release publication.

## Source and scope

- [ ] Release commit is on the intended default branch and matches the reviewed PR.
- [ ] `entlint.nimble`, `src/entlint.nim`, README, and CHANGELOG agree on the version.
- [ ] `CHANGELOG.md` moves the target version from `Unreleased` to the release date.
- [ ] No unrelated workflow, deployment, credential, or repository-policy changes are bundled into the release.

## Verification

- [ ] `nimble test -y` passes on the release candidate.
- [ ] CLI integration tests pass for exit codes `0`, `1`, and `2`.
- [ ] JSON output remains valid and does not expose raw candidate values.
- [ ] SARIF 2.1.0 output remains valid and does not include raw candidate values or masked previews.
- [ ] `.entlintignore` safety-boundary tests pass.
- [ ] Symlink and control-character regression tests pass.
- [ ] Detection corpus passes with zero corpus false negatives and no regression above the documented false-positive baseline.

## Security and privacy

- [ ] No real API keys, passwords, tokens, private keys, `.env` payloads, private logs, or production scan findings were added to source, tests, documentation, issues, or release notes.
- [ ] Test fixtures remain synthetic and auditable.
- [ ] Runtime remains local-only with no telemetry or network upload.
- [ ] `SECURITY.md` still accurately describes supported behavior and disclosure handling.

## Documentation

- [ ] README commands were checked against the release candidate.
- [ ] Known limitations are documented without overstating detection accuracy.
- [ ] `docs/DETECTION_CORPUS.md` matches the current measured corpus output.
- [ ] Release notes call out user-visible CLI, output-format, ignore-rule, or exit-code changes.

## Artifact/release publication

- [ ] Release tag matches the source version exactly.
- [ ] Any published binary is built from the reviewed release commit.
- [ ] Checksums are generated for published binaries when binary artifacts are provided.
- [ ] Published artifacts are smoke-tested with `--version`, a clean fixture, and a synthetic finding fixture.
- [ ] Release notes link to the exact source/tag and state the MIT license.

## Post-release

- [ ] Repository default branch reflects the released source.
- [ ] README no longer labels the released version as pre-release/development.
- [ ] Next changelog development section is opened when new work begins.
- [ ] Any release-specific follow-up is tracked as an issue rather than silently deferred.

Never use a real production credential to validate a release.
