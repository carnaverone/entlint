## Summary

<!-- Explain the user-visible change and why it is needed. -->

## Safety / scope

- [ ] Change is focused and local-first.
- [ ] No real credentials, private data, `.env` payloads, or production scan findings were added.
- [ ] Raw candidate secrets are never printed by new output paths.
- [ ] No telemetry, network upload, or external runtime service was added.
- [ ] Symlink/path boundaries remain explicit and tested when relevant.

## Validation

- [ ] `nimble test -y` passes.
- [ ] CLI behavior was tested when commands/output changed.
- [ ] Detection-corpus impact was checked when scanner heuristics changed.
- [ ] Documentation/changelog were updated for user-visible behavior.

## Detection changes

<!-- If scanner behavior changed, report TP/FP/TN/FN corpus impact and explain any new suppression rule. Otherwise write N/A. -->

## Notes for reviewers

<!-- Call out compatibility, security, performance, or follow-up considerations. -->
