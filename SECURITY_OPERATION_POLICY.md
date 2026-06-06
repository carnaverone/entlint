# Security Operation Policy — entlint

Status: active policy.
Repository: `carnaverone/entlint`.
Visibility: public.
Tool role: entropy-based secret scanning utility.

## Purpose

`entlint` is a public CLI entropy linter for detecting possible secrets in files and directories.

Because this repository is public and security-adjacent, it must never contain real secrets, private scan outputs, raw credentials, private logs, private repository snapshots or unredacted findings.

## Current script inventory

```yaml
script_inventory:
  install_script_present: false
  scripts_directory_present: false
  shell_scripts_present: false
  executable_runtime_tool: true
  tool_language: nim
  public_repo: true
```

## Tool boundary

```yaml
tool_boundary:
  scanner_type: entropy_linter
  cloud_upload: false
  local_cli: true
  masked_preview: true
  raw_secret_printing_allowed: false
  authorized_audit_only: true
```

## Allowed

```yaml
allowed:
  - source_code_for_entropy_linter
  - non_secret_test_fixtures
  - masked_preview_examples
  - public_build_instructions
  - local_pre_commit_hook_examples
  - redacted_scan_examples
  - safe_ci_examples
```

## Forbidden

```yaml
forbidden:
  - real_tokens
  - passwords
  - private_keys
  - browser_cookies
  - raw_env_files
  - private_scan_reports
  - raw_secret_findings
  - private_repository_snapshots
  - internal_project_exports
  - machine_specific_credentials
```

## Pre-commit hook rule

The README may show a local pre-commit hook example.

That example does not mean this repository owns an active hook deployment or controls user machines.

```yaml
pre_commit_policy:
  example_allowed: true
  active_hook_committed_by_default: false
  hook_must_scan_local_staged_copy_only: true
  hook_must_not_upload_data: true
  hook_must_not_commit_findings: true
```

## Secret scan output rule

```yaml
scan_output_policy:
  masked_preview_only: true
  raw_secret_output_allowed: false
  private_findings_must_not_be_committed: true
  unredacted_findings_allowed_in_public_repo: false
  json_output_must_not_include_raw_secrets: true
```

## Public repository boundary

Because this repo is public:

```yaml
public_boundary:
  commit_only_safe_examples: true
  redact_all_findings: true
  no_private_logs: true
  no_internal_exports: true
  no_real_environment_files: true
  no_private_paths_when_avoidable: true
```

## Stop condition

Stop before merge if a change includes:

```yaml
stop_if:
  - real_secret_value
  - token_like_test_fixture_without_masking
  - raw_scan_output
  - private_path_dump
  - .env_file
  - credentials_directory
  - browser_session_file
  - private_key_material
  - machine_specific_config
  - network_upload_path
  - cloud_scan_output
```

## Operating sentence

`entlint` may detect possible secrets locally. It must never store real secrets, upload scan data or commit unredacted findings.
