# entlint

**FR** · Linter d’entropie Nim pour repérer secrets/credentials/artefacts à forte entropie dans fichiers & repos.  
**Safe-by-default** : aucun contenu sensible affiché, zéro connexion réseau. **MIT**.

**EN** · Entropy linter (Nim) to detect secrets/credentials/high-entropy blobs in files & repos.  
Safe-by-default: no raw content, no network. **MIT**.

[![Latest release](https://img.shields.io/github/v/release/carnaverone/entlint?display_name=tag)](https://github.com/carnaverone/entlint/releases)
[![Downloads](https://img.shields.io/github/downloads/carnaverone/entlint/total)](https://github.com/carnaverone/entlint/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## ⚡️ Features

- **Scan d’entropie** : fichiers entiers ou par ligne (Shannon, bits/byte)
- **Seuil custom** (`--min 4.0` par défaut) pour détecter l’anomalie
- **Preview masqué** (`--preview`) : aucun secret affiché, que du flouté
- **Exclusions** (`--exclude <pat>`) multiples
- **Sortie JSON** pour intégration CI/automatisation
- **Exit codes** : `0` (rien trouvé), `2` (suspect trouvé), `1` (erreur/usage)

---

## 🚀 Installation

### 1. **Binaire tout prêt (recommandé)**

- [Télécharger ici (Linux/macOS/Windows)](https://github.com/carnaverone/entlint/releases)
- Linux/macOS :  
  ```bash
  chmod +x entlint
  sudo install -m755 entlint /usr/local/bin/entlint
