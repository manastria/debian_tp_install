#!/usr/bin/env bash
# profadmin-init.sh
# Cree (ou met a jour) le compte d'administration enseignant "profadmin"
# sur une VM Xubuntu. Script idempotent : relancer sans risque.
#
# Usage (en root) :
#   sudo ./profadmin-init.sh
#
# Variables d'environnement facultatives :
#   PROFADMIN_USER          nom du compte            (defaut : profadmin)
#   PROFADMIN_UID           UID systeme (< 1000)     (defaut : 990)
#   PROFADMIN_HOME          repertoire personnel     (defaut : /var/lib/profadmin)
#   PROFADMIN_PASS_HASH     hash du mot de passe (genere avec : openssl passwd -6)
#   PROFADMIN_SSH_KEY       cle publique SSH a autoriser (une ligne)
#   PROFADMIN_SUDO_NOPASSWD 1 pour sudo sans mot de passe (defaut : 0)
#   DOTFILES_URL            depot Git des dotfiles a cloner dans ~/dotfiles
#   DOTFILES_INSTALL        script d'installation relatif au depot (defaut : install.sh)

set -euo pipefail

USER_NAME="${PROFADMIN_USER:-profadmin}"
USER_UID="${PROFADMIN_UID:-990}"
USER_HOME="${PROFADMIN_HOME:-/var/lib/${USER_NAME}}"
PASS_HASH="${PROFADMIN_PASS_HASH:-}"
SSH_KEY="${PROFADMIN_SSH_KEY:-}"
SUDO_NOPASSWD="${PROFADMIN_SUDO_NOPASSWD:-0}"
DOTFILES_URL="${DOTFILES_URL:-}"
DOTFILES_INSTALL="${DOTFILES_INSTALL:-install.sh}"

log() { printf '[profadmin] %s\n' "$*"; }
die() { printf '[profadmin] ERREUR : %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "ce script doit etre execute en root (sudo)."

# --- 1. Compte ---------------------------------------------------------------
if id "$USER_NAME" >/dev/null 2>&1; then
    log "le compte ${USER_NAME} existe deja, aucune creation."
else
    if getent passwd "$USER_UID" >/dev/null; then
        die "l'UID ${USER_UID} est deja utilise. Choisir un autre PROFADMIN_UID."
    fi
    log "creation du compte ${USER_NAME} (UID ${USER_UID}, home ${USER_HOME})."
    useradd --system --uid "$USER_UID" --user-group \
        --create-home --home-dir "$USER_HOME" \
        --shell /bin/bash \
        --comment "Compte administration enseignant" \
        "$USER_NAME"
fi

# Le home doit etre prive : les etudiants n'ont rien a y lire.
install -d -m 0750 -o "$USER_NAME" -g "$USER_NAME" "$USER_HOME"

# --- 2. Mot de passe ---------------------------------------------------------
if [[ -n "$PASS_HASH" ]]; then
    log "definition du mot de passe a partir du hash fourni."
    usermod --password "$PASS_HASH" "$USER_NAME"
elif [[ "$(passwd -S "$USER_NAME" | awk '{print $2}')" == "L" ]]; then
    log "mot de passe verrouille : acces par cle SSH ou 'sudo -iu ${USER_NAME}' uniquement."
fi

# --- 3. Droits sudo ----------------------------------------------------------
SUDOERS_FILE="/etc/sudoers.d/${USER_NAME}"
TMP_SUDOERS="$(mktemp)"
trap 'rm -f "$TMP_SUDOERS"' EXIT
if [[ "$SUDO_NOPASSWD" == "1" ]]; then
    echo "${USER_NAME} ALL=(ALL:ALL) NOPASSWD: ALL" > "$TMP_SUDOERS"
else
    echo "${USER_NAME} ALL=(ALL:ALL) ALL" > "$TMP_SUDOERS"
fi
visudo -cf "$TMP_SUDOERS" >/dev/null || die "fichier sudoers invalide."
install -m 0440 -o root -g root "$TMP_SUDOERS" "$SUDOERS_FILE"
log "droits sudo installes dans ${SUDOERS_FILE}."

# --- 4. Masquage dans l'ecran de connexion ----------------------------------
# Deja masque par l'UID < 1000 ; ce fichier garantit le comportement
# meme si l'UID est modifie plus tard.
install -d -m 0755 /var/lib/AccountsService/users
cat > "/var/lib/AccountsService/users/${USER_NAME}" <<'EOF'
[User]
SystemAccount=true
EOF
chmod 0600 "/var/lib/AccountsService/users/${USER_NAME}"

# --- 5. Arborescence de travail ---------------------------------------------
for d in bin scripts .config; do
    install -d -m 0750 -o "$USER_NAME" -g "$USER_NAME" "${USER_HOME}/${d}"
done

# --- 6. Profil shell : PATH propre au compte uniquement ---------------------
PROFILE_MARK="# >>> profadmin >>>"
BASHRC="${USER_HOME}/.bashrc"
if [[ ! -f "$BASHRC" ]] || ! grep -qF "$PROFILE_MARK" "$BASHRC"; then
    {
        echo "$PROFILE_MARK"
        echo 'case ":$PATH:" in *":$HOME/bin:"*) ;; *) PATH="$HOME/bin:$PATH" ;; esac'
        echo 'export PATH'
        echo "# <<< profadmin <<<"
    } >> "$BASHRC"
    chown "$USER_NAME:$USER_NAME" "$BASHRC"
fi
# Un .profile est necessaire pour les shells de connexion (ssh, su -).
PROFILE="${USER_HOME}/.profile"
if [[ ! -f "$PROFILE" ]]; then
    printf '[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"\n' > "$PROFILE"
    chown "$USER_NAME:$USER_NAME" "$PROFILE"
fi

# --- 7. Cle SSH (facultatif) -------------------------------------------------
if [[ -n "$SSH_KEY" ]]; then
    SSH_DIR="${USER_HOME}/.ssh"
    AUTH="${SSH_DIR}/authorized_keys"
    install -d -m 0700 -o "$USER_NAME" -g "$USER_NAME" "$SSH_DIR"
    touch "$AUTH"
    grep -qxF "$SSH_KEY" "$AUTH" || echo "$SSH_KEY" >> "$AUTH"
    chown "$USER_NAME:$USER_NAME" "$AUTH"
    chmod 0600 "$AUTH"
    log "cle SSH autorisee."
fi

# --- 8. Dotfiles (facultatif) ------------------------------------------------
if [[ -n "$DOTFILES_URL" ]]; then
    command -v git >/dev/null || apt-get install -y git
    TARGET="${USER_HOME}/dotfiles"
    if [[ -d "${TARGET}/.git" ]]; then
        log "mise a jour des dotfiles."
        sudo -u "$USER_NAME" -H git -C "$TARGET" pull --ff-only
    else
        log "clonage des dotfiles depuis ${DOTFILES_URL}."
        sudo -u "$USER_NAME" -H git clone "$DOTFILES_URL" "$TARGET"
    fi
    if [[ -x "${TARGET}/${DOTFILES_INSTALL}" ]]; then
        log "execution de ${DOTFILES_INSTALL}."
        sudo -u "$USER_NAME" -H "${TARGET}/${DOTFILES_INSTALL}"
    fi
fi

# --- 9. Verifications --------------------------------------------------------
log "verification :"
id "$USER_NAME"
getent passwd "$USER_NAME"
if ls /home 2>/dev/null | grep -qx "$USER_NAME"; then
    log "ATTENTION : ${USER_NAME} apparait dans /home."
else
    log "OK : absent de /home."
fi
log "termine."
