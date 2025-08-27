# entlint

**CLI Entropy Linter (Nim)** — Scan files and directories for secrets (API keys, tokens, credentials) using entropy analysis.  
**No BS**: no cloud, no data leaks, 100% CLI, MIT license.

---

## 📦 INSTALLATION

### **Quick method: prebuilt binary**
- [Download the latest release](https://github.com/carnaverone/entlint/releases)
- Make it executable and move it anywhere you want:
  ```sh
  chmod +x entlint
  sudo mv entlint /usr/local/bin/

Build from source

    Prerequisites: Nim >= 1.6.0

nimble install nim

Build

    git clone https://github.com/carnaverone/entlint.git
    cd entlint
    nimble build -d:release
    # Binary will be at ./entlint

🚦 USAGE
Scan a directory (with exclusions, preview, strict threshold)

entlint scan . --lines --preview --min 4.2 --exclude node_modules --exclude .git

Scan a file

entlint file ./secrets.env --min 4.0 --preview

JSON output (for CI or scripts)

entlint scan src --lines --json

MAIN OPTIONS
Flag	Description
--min <f>	Entropy threshold in bits/byte (default: 4.0)
--lines	Line-by-line analysis
--json	Machine-readable JSON output
--max-size <N>	Ignore files >N bytes (default: 2MiB)
--exclude <pat>	Exclude paths containing <pat> (repeatable)
--preview	Masked preview (never prints raw content)

Exit codes:

    0 = no findings

    2 = suspect secrets found

    1 = error/usage

🧰 TROUBLESHOOTING

    invalid indentation error during build:
    → Check your indentation (only spaces, no tabs!), fix with:

    find . -name "*.nim" -exec sed -i 's/\t/  /g' {} \;

    normalizePath not found:
    → Replace .normalizePath with canonicalPath(p) or just use p depending on your Nim version.

    No ./entlint binary after build:
    → Build failed, check logs (nimble build -d:release --verbose).

    CI/CD GitHub Actions:
    → .github/workflows/test.yml runs build + test on push/PR.

🚨 ETHICS

    NO actual secrets are shown (masked previews only).

    For authorized audit only (do not scan random code!).

    Zero upload, zero cloud, zero leak possible.

🦾 PRE-COMMIT HOOK (anti-leak)

Blocks commit if secrets detected:

# .git/hooks/pre-commit (chmod +x)
tmp=$(mktemp -d)
git diff --cached --name-only -z | xargs -0 -I{} sh -c 'd=$(dirname "{}"); mkdir -p "$tmp/$d"; cp "{}" "$tmp/{}"'
./entlint scan "$tmp" --lines --json >/dev/null || rc=$?
rm -rf "$tmp"
[ "${rc:-0}" -eq 2 ] && echo "entlint: secrets found!" && exit 1 || exit 0

🛣️ ROADMAP

    SARIF export, .entlintignore, per-extension thresholds, multithread, PR welcome.

🔖 LICENSE

MIT © Carnaverone Studio — All Rights Reserved 2025

    Contact / Pro / AI bundles: carnaverone.store


PromptBase / Gumroad / Consulting: on request
