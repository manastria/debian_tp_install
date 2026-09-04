## Documentation des scripts

Tout script shell/Python doit avoir :
1. Un bloc d'en-tête façon manpage (NAME/SYNOPSIS/DESCRIPTION/OPTIONS/EXAMPLES)
2. Des commentaires inline sur les parties non triviales (pas de commentaires évidents type `# incrémente i`)
3. Pour les scripts avec arguments : aide `-h`/`--help` qui affiche un résumé du SYNOPSIS
4. **Une page de documentation dans `docs/`** (voir ci-dessous)

### Page `docs/<nom-du-script>.md`

Obligatoire pour **tout nouveau script**, et **à mettre à jour à chaque changement de comportement** : options ajoutées ou renommées, valeurs par défaut, codes de retour, prérequis. Un script supprimé implique de supprimer sa page.

- Un fichier Markdown par script, nommé d'après le script **sans son extension** : `pack-bundle.sh` → `docs/pack-bundle.md`.
- `docs/` est un répertoire versionné à la racine du dépôt : la page y est créée directement, à côté de l'index `README.md`.
- Rédigée en **français**, comme les commentaires et les messages des scripts.
- **Référencer la page dans l'index `docs/README.md`** (et l'y retirer si le script disparaît) : `README.md` est l'index obligatoire du répertoire, toute page non listée est considérée comme oubliée. Les scripts vivant à la racine du dépôt, les liens s'écrivent en relatif depuis `docs/` : `../mon-script.sh`.

Structure imposée, en trois parties (références : `docs/yadm-check-submodules.md`, `docs/pack-bundle.md`) :

**En bref** — paragraphe de rappel destiné au mémo `562 shell.docx` (section 11.2), placé **en tête de page**, juste après la ligne `> Script : …` et avant le premier séparateur `---` :

```markdown
## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`mon-script.sh` fait ceci… (4 à 6 phrases)
```

- **Un seul paragraphe**, 4 à 6 phrases, sans liste ni tableau : c'est un rappel de quelques lignes dans un mémo, pas une fiche.
- Le Markdown est collé tel quel dans Word (via une extension) : le balisage `code` et `**gras**` est donc à utiliser normalement, mais **aucun lien** — sorti de `docs/`, un `[texte](../mon-script.sh)` ne pointe plus nulle part.
- **Autonome** : il nomme le script, dit à quoi il sert, ce qu'il ne fait **pas** (la confusion à éviter avec un script voisin), et les deux ou trois options réellement utilisées au quotidien.
- La ligne `>` au-dessus signale le contenu à recopier ; elle ne fait pas partie du texte à coller.
- C'est un rappel, pas un résumé de la page : ni prérequis, ni codes de retour, ni détail d'implémentation.

**Section utilisateur** — ce qu'il faut savoir pour s'en servir :
- `Description` : à quoi sert le script, et en quoi il diffère des scripts voisins
- `Prérequis` : tableau outil / rôle / commande de vérification
- `Syntaxe` : la ligne de commande, puis un tableau option / argument / défaut / description
- `Exemples d'utilisation` : commandes commentées **et** un exemple de sortie réelle
- `Codes de retour` : tableau code / signification, aligné sur la section EXIT CODES de l'en-tête

**Section développeur** — ce qu'il faut savoir pour le modifier :
- `Architecture interne` : enchaînement des fonctions de `main()`
- `Détail des choix techniques` : le **pourquoi** des décisions non évidentes (pièges d'API, contournements, comportements par défaut choisis)
- `Dépendances externes` : binaires requis et versions minimales, avec la fonctionnalité qui l'impose
- `Points d'extension` : modifications prévisibles, avec un extrait de code
- `Notes de maintenance` : limites connues et pièges pour la prochaine personne qui y touche

La page doit rester cohérente avec l'en-tête manpage du script : l'en-tête est la référence courte (`--help`), la page docs explique le contexte, les cas d'usage et les raisons.

Trois niveaux de détail, donc, du plus court au plus long : le paragraphe `En bref` (mémo), l'en-tête manpage (`--help`), la page `docs/` (contexte et raisons).

## Shell Script Color and Logging Conventions

Every script in `.local/bin/` that produces user-facing output must use the following color variables and log functions. Do not use raw `echo "INFO: ..."` strings or invent alternative naming.

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }
```

- Use `info` for progress steps, `success` after a step completes, `warn` for non-fatal alerts, `error`/`die` for fatal errors.
- `error` always writes to stderr (`>&2`). `die` calls `error` then exits with code 1.
- Reference implementation: `install-ghostty.sh`, `install-eza.sh`, `install-docker.sh`.

## Trace persistante dans `/var/log`

Les fonctions de log ci-dessus n'écrivent qu'à l'écran. Tout script qui modifie le système (paquets, `/etc/`, services, jonction au domaine) doit **en plus** conserver une trace sur disque, pour pouvoir diagnostiquer un poste après coup.

- La trace va dans un **fichier**, jamais dans le journal systemd : pas de `logger`, pas de `systemd-cat`. Un poste de TP est réinstallé, ré-imagé ou exporté en OVA ; un fichier se lit et se copie sans dépendre de journald ni d'un `Storage=persistent`.
- Répertoire dédié `/var/log/tp-install/`, **un fichier par script** nommé d'après le script sans son extension : `join-ad.sh` → `/var/log/tp-install/join-ad.log`.
- Le fichier est **ouvert en ajout**, jamais tronqué : chaque exécution ajoute une bannière puis ses lignes à la suite. On garde l'historique des tentatives sur un poste, ce qui est exactement ce qu'on cherche quand un TP a été relancé trois fois.
- **Aucun secret dans le fichier** : mot de passe de jonction AD, clé, token. Ne jamais activer `set -x` dans un script qui manipule un secret, et ne jamais faire passer un secret en argument de commande.

### Mise en place

À placer juste après les fonctions de log, avant toute autre sortie :

```bash
readonly LOG_DIR="/var/log/tp-install"
readonly LOG_FILE="${LOG_DIR}/$(basename "$0" .sh).log"

setup_logging() {
    install -d -m 0750 -o root -g adm "$LOG_DIR"
    [ -e "$LOG_FILE" ] || install -m 0640 -o root -g adm /dev/null "$LOG_FILE"

    # Sauvegarde des descripteurs d'origine, pour les restaurer en fin de script.
    exec 3>&1 4>&2

    # Tout ce que produit le script — y compris apt, curl, systemctl — part à
    # l'écran ET dans le fichier, débarrassé des séquences ANSI qui le rendraient
    # illisible dans un éditeur.
    exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1
    _TEE_PID=$!

    echo "===== $(date '+%F %T') | $(basename "$0") $* | $(id -un)@$(uname -n) ====="
}
```

Appeler `setup_logging "$@"` (avec les arguments, pour que la bannière trace la ligne de commande réelle) en tête de `main()`.

La restauration des descripteurs en fin de script n'est pas cosmétique : sans elle, le `tee` peut perdre les toutes dernières lignes, celles qui expliquent justement pourquoi le script s'est arrêté.

```bash
cleanup() {
    exec 1>&3 2>&4
    wait "$_TEE_PID" 2>/dev/null
}
trap cleanup EXIT
```

Un seul `trap ... EXIT` par script : si le script utilise déjà le keep-alive sudo du Tier 2, fusionner les deux dans la même fonction `cleanup` plutôt que de poser un second `trap EXIT`, qui écraserait silencieusement le premier.

### Selon le tier sudo

- **Tier 1** (le script tourne en root) : le bloc ci-dessus s'applique tel quel, `setup_logging` étant appelé après l'auto-relaunch.
- **Tier 2** (mix user + root) : le script n'est pas root et ne peut pas écrire dans `/var/log`. Appeler `setup_logging` après le `sudo -v`, et préfixer les trois commandes privilégiées : `sudo install -d …`, `sudo install -m 0640 …`, et `sudo tee -a` à la place de `tee` dans la redirection.
- **Tier 3** (ne doit jamais être root) : pas de `/var/log`. La trace va dans `${XDG_STATE_HOME:-$HOME/.local/state}/tp-install/`, créé en `0700`, avec le même schéma de nommage.

### Rotation

Les fichiers étant en ajout, un script relancé souvent finit par produire un log volumineux. Pour ceux-là, déposer un fichier logrotate dans `/etc/logrotate.d/tp-install` :

```
/var/log/tp-install/*.log {
    monthly
    rotate 6
    compress
    missingok
    notifempty
    create 0640 root adm
}
```

## Sudo Privilege Management in Scripts

Every script in `.local/bin/` must follow one of three patterns depending on its needs. Do not mix patterns or invent variants.

### Tier 1 — Script requires root for all (or most) operations

Use auto-relaunch **without** `-E`. The user can call the script without `sudo`; the script re-executes itself with the resolved absolute path.

```bash
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi
```

- `readlink -f "$0"` resolves the absolute path regardless of how the script was called, which is required because `~/.local/bin` is not in sudo's `secure_path`.
- No `-E` flag: sudo starts with its own secure environment. Never use `sudo -E` as it passes `LD_PRELOAD`, `PATH`, `PYTHONPATH`, etc. from the user environment to root.
- Applies to: scripts that run `apt`, write to `/etc/`, manage systemd services, or otherwise operate exclusively at system level (`install-paquets.sh`, `update-ubuntu.sh`, `change-hostname.sh`, etc.).

### Tier 2 — Script mixes user-level and root operations

The script runs as the current user. Call `sudo -v` once at the start to cache credentials and avoid mid-script password prompts. Use `sudo` inline only on the commands that require it.

```bash
# Préchauffage : demande le mot de passe une seule fois en début de script
echo "INFO: Des droits administrateur sont nécessaires pour certaines étapes."
sudo -v
```

For scripts that run longer than ~5 minutes, add a keep-alive to prevent the sudo token from expiring:

```bash
sudo -v
( while true; do sudo -n true; sleep 50; done ) &
_SUDO_PID=$!
trap 'kill "$_SUDO_PID" 2>/dev/null' EXIT INT TERM
```

- Applies to: scripts that perform both user-space operations (downloads, config in `~/.config`, etc.) and occasional system operations (`install-docker.sh`, `install-ghostty.sh`, etc.).

### Tier 3 — Script must never run as root

Scripts that write to `~/.local`, configure the user shell, or manage user-owned files must reject root execution, as running them as root silently creates files owned by root in the user's home directory.

```bash
if [ "$(id -u)" -eq 0 ]; then
    echo "ERREUR : Ce script ne doit pas être lancé en root." >&2
    echo "Relancez sans sudo, en tant qu'utilisateur normal." >&2
    exit 1
fi
```

- Applies to: scripts that install to `~/.local/bin`, configure zsh/bash, or manage user dotfiles (`install-atuin.sh`, `install-fzf.sh`, `install-starship.sh`, `install-zoxide.sh`, etc.).

### Decision guide

```text
Le script a-t-il besoin de sudo ?
│
├── Non ──────────────────────── Rien à ajouter
│
├── Oui, opérations exclusivement
│   système (apt, /etc/, services) ── Tier 1 : auto-relaunch sans -E
│
├── Oui, mix user + système ──────── Tier 2 : sudo -v warmup + sudo inline
│
└── Non, et doit rester user ─────── Tier 3 : reverse-check (refuser root)
```

### Forbidden patterns

- `exec sudo -E "$0" "$@"` — propagates user environment to root (security risk).
- `if [ "$EUID" -ne 0 ]; then echo "Lancez avec sudo"; exit 1; fi` — forces the user to type the full path since `~/.local/bin` is not in sudo's `secure_path`.
- Asking for the password multiple times within the same script (use `sudo -v` warmup instead).

## Shell Script Structure

Organize installer scripts with section dividers and a `main()` entry point. This is the canonical layout:

```bash
#!/usr/bin/env bash
# install-foo.sh — Description courte
# Usage : bash install-foo.sh [--option]
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PACKAGE="foo"

# -----------------------------------------------------------------------------
# Couleurs et fonctions de log
# -----------------------------------------------------------------------------
# [canonical color variables and log functions here]

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_root() { ... }

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
install_foo() { ... }

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    echo -e "\n${BOLD}=== Installation de Foo ===${RESET}\n"
    check_root
    install_foo
}

main "$@"
```

Use `readonly` for all top-level constants. Group functions by responsibility. Put `main "$@"` as the last line.

### Argument parsing

For scripts that accept options, use a `while`-based parser that supports flags with values:

```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --option) VALUE="${2:-}"; shift 2 ;;
    --flag)   FLAG="yes"; shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) die "Option inconnue : $1" ;;
  esac
done
```

`sed -n '2,5p' "$0"` prints the script's header comment block as help text — only works if the header is written as comments on lines 2–N.

## Common Installer Script Patterns

### Idempotency

Scripts must be safely re-runnable. Check state before each step:

```bash
# Package already installed?
if dpkg -s "$PACKAGE" &>/dev/null; then
    local version
    version=$(dpkg -s "$PACKAGE" | awk '/^Version:/ { print $2 }')
    warn "Déjà installé (version $version)."
    read -r -p "$(echo -e "${YELLOW}Réinstaller ?${RESET} [o/N] ")" answer
    [[ ! "$answer" =~ ^[oOyY]$ ]] && { info "Annulé."; exit 0; }
fi

# Binary already on PATH?
if command -v foo &>/dev/null; then
    info "foo déjà présent : $(command -v foo)"
fi

# File/key already exists?
if [ ! -f "$KEY_FILE" ]; then
    # download and install key
fi
```

### Temporary directory with automatic cleanup

Always pair `mktemp` with a `trap` so the directory is removed on exit, error, or signal:

```bash
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
```

### Architecture detection

```bash
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ARCH_TAG="linux_amd64" ;;
    aarch64) ARCH_TAG="linux_arm64" ;;
    armv7l)  ARCH_TAG="linux_armv7" ;;
    *) die "Architecture non supportée : ${ARCH}" ;;
esac
```

### GitHub releases — fetch latest version

```bash
LATEST=$(curl -fsSL https://api.github.com/repos/OWNER/REPO/releases/latest \
    | grep '"tag_name"' \
    | sed 's/.*"v\?\([^"]*\)".*/\1/')
```

Then build the download URL:

```bash
TARBALL="tool-${LATEST}-${ARCH_TAG}.tar.gz"
URL="https://github.com/OWNER/REPO/releases/download/v${LATEST}/${TARBALL}"
curl -fsSL -o "${TMP_DIR}/${TARBALL}" "$URL"
tar -xzf "${TMP_DIR}/${TARBALL}" -C "$TMP_DIR"
install -m 0755 "${TMP_DIR}/tool" "${INSTALL_DIR}/tool"
```

### APT non-interactive mode (Tier 1 scripts only)

Set before any `apt` calls to suppress interactive prompts:

```bash
export DEBIAN_FRONTEND=noninteractive
```

Only set in Tier 1 scripts (running as root). In Tier 2, `sudo apt-get install -y` is sufficient.

### Post-install verification

Always verify the binary is reachable after installation:

```bash
verify_install() {
    if command -v foo &>/dev/null; then
        local version
        version=$(foo --version 2>/dev/null | head -1 || echo "inconnue")
        success "Installé avec succès : ${BOLD}$version${RESET}"
    else
        die "Introuvable dans le PATH après installation."
    fi
}
```
