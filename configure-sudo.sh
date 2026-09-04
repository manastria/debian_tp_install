#!/usr/bin/env bash
# =============================================================================
# NAME
#     configure-sudo.sh — Configure sudo pour les groupes de labo
#
# SYNOPSIS
#     ./configure-sudo.sh [-h|--help]
#
# DESCRIPTION
#     Met en place deux groupes sudo pour les étudiants d'un labo :
#     "adminpwd" (sudo AVEC mot de passe) et "admins" (sudo SANS mot de
#     passe). Crée les groupes s'ils n'existent pas encore, dépose les
#     fichiers /etc/sudoers.d correspondants, et conserve HOME, DISPLAY,
#     XAUTHORITY et SSH_AUTH_SOCK dans l'environnement sudo pour éviter les
#     erreurs d'interface graphique en sudo. Idempotent : peut être relancé
#     sans effet de bord.
#
# OPTIONS
#     -h, --help   Affiche cette aide et quitte.
#
# EXAMPLES
#     sudo ./configure-sudo.sh
#         Crée les groupes et les fichiers sudoers.d.
#
#     sudo usermod -aG adminpwd etudiant1
#         Donne à etudiant1 le sudo AVEC mot de passe.
#
#     sudo usermod -aG admins etudiant2
#         Donne à etudiant2 le sudo SANS mot de passe.
#
# EXIT CODES
#     0   Succès.
#     1   Option inconnue, ou erreur de syntaxe détectée dans un fichier
#         sudoers.d généré (le fichier invalide est supprimé avant de sortir).
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly SUDOERS_ENV_FILE="/etc/sudoers.d/env_custom"
readonly SUDOERS_ADMINS_FILE="/etc/sudoers.d/admins"

# -----------------------------------------------------------------------------
# Couleurs et fonctions de log
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Trace persistante (/var/log/tp-install)
# -----------------------------------------------------------------------------
readonly LOG_DIR="/var/log/tp-install"
readonly LOG_FILE="${LOG_DIR}/$(basename "$0" .sh).log"

setup_logging() {
    install -d -m 0750 -o root -g adm "$LOG_DIR"
    [ -e "$LOG_FILE" ] || install -m 0640 -o root -g adm /dev/null "$LOG_FILE"

    # Sauvegarde des descripteurs d'origine, pour les restaurer en fin de script.
    exec 3>&1 4>&2

    # Tout ce que produit le script part à l'écran ET dans le fichier, débarrassé
    # des séquences ANSI qui le rendraient illisible dans un éditeur.
    exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1
    _TEE_PID=$!

    # Le trap n'est posé qu'une fois la redirection active, pour ne pas tenter
    # de restaurer des descripteurs jamais dupliqués (ex. chemin -h/--help).
    trap cleanup EXIT

    echo "===== $(date '+%F %T') | $(basename "$0") $* | $(id -un)@$(uname -n) ====="
}

cleanup() {
    exec 1>&3 2>&4
    wait "$_TEE_PID" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) sed -n '2,34p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Option inconnue : $1 (voir -h)" ;;
  esac
done

# -----------------------------------------------------------------------------
# Élévation de privilèges (Tier 1 — opérations exclusivement système)
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

# -----------------------------------------------------------------------------
# Environnement sudo
# -----------------------------------------------------------------------------
configure_env_keep() {
    info "Configuration des variables d'environnement conservées par sudo..."
    cat > "$SUDOERS_ENV_FILE" << EOF
Defaults        env_keep += "HOME"
Defaults        env_keep += "DISPLAY XAUTHORITY"
Defaults        env_keep += "SSH_AUTH_SOCK"
EOF
    chown root:root "$SUDOERS_ENV_FILE"
    chmod 0440 "$SUDOERS_ENV_FILE"

    if ! visudo -cf "$SUDOERS_ENV_FILE" > /dev/null 2>&1; then
        rm -f "$SUDOERS_ENV_FILE"
        die "Erreur de syntaxe dans $SUDOERS_ENV_FILE — fichier supprimé, sudo non modifié."
    fi
    success "Environnement sudo configuré ($SUDOERS_ENV_FILE)."
}

# -----------------------------------------------------------------------------
# Groupes de labo
# -----------------------------------------------------------------------------
create_lab_groups() {
    if ! getent group admins > /dev/null 2>&1; then
        groupadd admins
        success "Groupe 'admins' créé."
    else
        info "Groupe 'admins' déjà présent."
    fi

    if ! getent group adminpwd > /dev/null 2>&1; then
        groupadd adminpwd
        success "Groupe 'adminpwd' créé."
    else
        info "Groupe 'adminpwd' déjà présent."
    fi
}

configure_lab_privileges() {
    info "Configuration des privilèges sudo pour les groupes de labo..."
    cat > "$SUDOERS_ADMINS_FILE" << EOF
# Configuration pour les étudiants débutants (béquilles)
%adminpwd   ALL=(ALL:ALL)   PASSWD: ALL
%admins     ALL=(ALL:ALL)   NOPASSWD: ALL
EOF
    chown root:root "$SUDOERS_ADMINS_FILE"
    chmod 0440 "$SUDOERS_ADMINS_FILE"

    if ! visudo -cf "$SUDOERS_ADMINS_FILE" > /dev/null 2>&1; then
        rm -f "$SUDOERS_ADMINS_FILE"
        die "Erreur de syntaxe dans $SUDOERS_ADMINS_FILE — fichier supprimé, sudo non modifié."
    fi
    success "Privilèges sudo configurés ($SUDOERS_ADMINS_FILE)."
}

# -----------------------------------------------------------------------------
# Rappel affiché en fin d'exécution
# -----------------------------------------------------------------------------
print_usage_hint() {
    echo -e "${CYAN}${BOLD}Pour donner les droits sudo à un utilisateur :${RESET}"
    cat << 'USAGE'

  Deux groupes sont disponibles selon le niveau de l'étudiant :

    - adminpwd : sudo AVEC mot de passe
    - admins   : sudo SANS mot de passe

  Commande pour ajouter un utilisateur à un groupe :

    sudo usermod -aG <groupe> <utilisateur>

  Exemples :

    sudo usermod -aG adminpwd etudiant1
    sudo usermod -aG admins   etudiant2

  Options importantes :

    -a  : "append", ajoute le groupe sans retirer les groupes existants
          (ne JAMAIS omettre -a, sinon tous les autres groupes de
          l'utilisateur sont perdus)
    -G  : indique qu'il s'agit d'un groupe secondaire

  Vérifier l'appartenance aux groupes d'un utilisateur :

    groups <utilisateur>
    id <utilisateur>

  Note : la nouvelle appartenance au groupe n'est prise en compte qu'à
  la prochaine connexion (ou nouvelle session) de l'utilisateur.

USAGE
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    setup_logging "$@"

    echo -e "\n${BOLD}=== Configuration de sudo ===${RESET}\n"

    configure_env_keep
    create_lab_groups
    configure_lab_privileges

    echo -e "\n${GREEN}${BOLD}Configuration de sudo terminée avec succès !${RESET}\n"
    print_usage_hint
}

main "$@"
