# entlint

**FR** · Linter d’entropie (Nim) pour détecter des blobs / lignes à forte entropie (probables secrets).  
**Safe-by-default** : pas de réseau, pas de contenu brut imprimé. **MIT**.

**EN** · Entropy linter (Nim) to detect high-entropy blobs/lines (likely secrets) in files and repos.  
Safe-by-default: no network, no raw content printed. **MIT**.

[![Build (test)](https://github.com/carnaverone/entlint/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/carnaverone/entlint/actions/workflows/test.yml)
[![Latest release](https://img.shields.io/github/v/release/carnaverone/entlint?display_name=tag)](https://github.com/carnaverone/entlint/releases)
[![Downloads](https://img.shields.io/github/downloads/carnaverone/entlint/total)](https://github.com/carnaverone/entlint/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## Features
- **Entropy scan** (file / per-line) via Shannon bits/byte.
- **Threshold** `--min 4.0` (par défaut) pour signaler le “suspect”.
- **Redacted preview** `--preview` : aperçu **masqué** (aucun alphanum brut).
- **Exclusions** `--exclude <pat>` répétables.
- **JSON output** pour CI/outillage.
- **Exit codes** : `0` (OK), `2` (findings), `1` (usage/erreur).

---

## Install

### A) Binaires (recommandé)
Télécharge pour Linux/macOS/Windows : **[Releases](https://github.com/carnaverone/entlint/releases)**.

Linux/macOS :
```bash
chmod +x entlint
sudo install -m755 entlint /usr/local/bin/entlint

Windows : place entlint.exe dans un dossier du PATH.
B) Build from source

nimble build -d:release
# binaire: ./entlint (ou entlint.exe sur Windows)

Usage

entlint --help
entlint scan <path> [--min 4.0] [--lines] [--json] [--max-size 2097152] [--exclude <pat>]... [--preview]
entlint file <file> [--min 4.0] [--lines] [--json] [--preview]

Flags clés

    --min <f> seuil entropie en bits/byte (défaut 4.0)

    --lines analyse par-ligne (pour fichiers texte)

    --json sortie machine (CI)

    --max-size ignore fichiers > N octets (défaut 2 MiB en scan)

    --exclude exclut les chemins contenant <pat> (répéter)

    --preview montre un aperçu masqué pour les lignes signalées (aucun contenu brut)

Exemples

# scan repo, uniquement métadonnées
entlint scan . --lines

# avec aperçu masqué et exclusions
entlint scan . --lines --preview --exclude node_modules --exclude dist

# fichier unique, JSON (pour CI)
entlint file .env --json

# seuil plus strict
entlint scan src --min 4.2

Codes de sortie

    0 = aucun finding

    2 = findings présents

    1 = erreur / mauvais usage

Ethics & Limits

    Offline-only ; imprime métadonnées (chemin/ligne/entropie), pas de contenu brut.

    --preview affiche un aperçu masqué (letters/digits → *) pour éviter les fuites.

    À utiliser uniquement sur du code autorisé (propriété ou mandat d’audit).

    En CI, traitez le code retour 2 comme une violation de politique.

Voir aussi : SECURITY.md
et DISCLAIMER.md

.
CI
Tests (automatique sur push/PR)

    .github/workflows/test.yml : build + nimble test.

Release (binaries attachés)

    .github/workflows/release.yml : build Linux/macOS/Windows et attache sur Release.

Créer une release :

    via UI (Releases → Draft a new release) avec tag v0.1.1, ou

    via CLI :

git tag v0.1.1 && git push origin v0.1.1

Pre-commit hook (optionnel)

Empêche de committer si findings :

# .git/hooks/pre-commit (chmod +x)
#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d)
git diff --cached --name-only -z | xargs -0 -I{} sh -c 'd=$(dirname "{}"); mkdir -p "'"$tmp"'/$d"; cp "{}" "'"$tmp"'/{}
'
./entlint scan "$tmp" --lines --json >/dev/null || rc=$?
rm -rf "$tmp"
[ "${rc:-0}" -eq 2 ] && echo "entlint: potential secrets found" && exit 1 || exit 0

Roadmap

    --sarif pour GitHub Code Scanning.

    Seuils par extension (réduire le bruit sur binaires/archives).

    .entlintignore (globs).

License

MIT © Carnaverone
