#!/usr/bin/env bash
# install_issue_xubuntu.sh
# Objectif : afficher les adresses IP sur les consoles texte (Ctrl+Alt+F1 à F6)
#            sans ouvrir de session, via /etc/issue
# Auteur   : Manastria
# Usage    : sudo ./install_issue_xubuntu.sh [--uninstall]
#
# Fonctionnement :
#   Un script dispatcher NetworkManager (/etc/NetworkManager/dispatcher.d/90-login-info)
#   s'exécute à chaque changement réseau (up, down, dhcp4-change).
#   Il régénère /etc/issue à partir de /etc/issue.std (copie de l'original) en
#   y ajoutant un tableau coloré : interface, type, adresse IP/masque.
#   Ordre : Ethernet en premier (vert), puis Wi-Fi, autres, puis Docker/libvirt
#   (gris, moins mis en avant mais visibles).
#   Le hostname est déjà affiché par l'escape \n de /etc/issue.
#   Remplace install_issue.sh (ifupdown, Debian) sur Xubuntu.
#
# Prérequis :
#   - Xubuntu 24.04+ géré par NetworkManager
#   - Exécution en root (le script se relance via sudo)
#
# Remarques :
#   - Rafraîchissement automatique : après chaque régénération, le dispatcher
#     exécute "agetty --reload". Les consoles qui affichent l'invite "login:"
#     (sans saisie commencée) effacent l'écran et réaffichent /etc/issue à jour.
#   - "Raccourci" manuel sur la console : Ctrl+D à l'invite "login:" termine
#     agetty ; systemd le relance aussitôt (écran effacé, /etc/issue relu).
#     Ctrl+U efface la saisie en cours.
#     (Entrée seul ne fait que réafficher l'invite : agetty ne relit pas le fichier.)
#   - Les interfaces ignorées et les couleurs se modifient en tête du fichier
#     dispatcher généré (EXCLUDE_IFACES, C_*).
#   - Le tableau utilise des caractères de tracé Unicode (┌─┬┐) : la console
#     texte d'Ubuntu (UTF-8) les affiche correctement.
#   - Ne pas utiliser en même temps que install_issue.sh (même /etc/issue.std).
#   - Les versions précédentes de ce script configuraient aussi l'écran LightDM :
#     ce reliquat est nettoyé automatiquement (installation ou désinstallation).
#
# Restauration : sudo ./install_issue_xubuntu.sh --uninstall

# ---------------------------------------------------------------------------
# Gardes initiales (avant set -euo pipefail)
# ---------------------------------------------------------------------------
[[ -n "${BASH_VERSION:-}" ]] || { echo "Ce script doit être exécuté avec bash." >&2; exit 1; }

if [ "$EUID" -ne 0 ]; then
    exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

set -euo pipefail

# ---------------------------------------------------------------------------
# Couleurs & helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERREUR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Arguments
# ---------------------------------------------------------------------------
UNINSTALL=0
for arg in "$@"; do
    case "$arg" in
        --uninstall) UNINSTALL=1 ;;
        *) die "Option inconnue : $arg (usage : $0 [--uninstall])" ;;
    esac
done

# ---------------------------------------------------------------------------
# Variables globales
# ---------------------------------------------------------------------------
HOOK="/etc/NetworkManager/dispatcher.d/90-login-info"
ISSUE="/etc/issue"
ISSUE_STD="/etc/issue.std"

# Reliquats des anciennes versions (affichage LightDM)
BG_FILE="/usr/share/backgrounds/login-info.png"
GREETER_MAIN="/etc/lightdm/lightdm-gtk-greeter.conf"
GREETER_DROPIN="/etc/lightdm/lightdm-gtk-greeter.conf.d/50-login-info.conf"
GREETER_BAK="${GREETER_MAIN}.bak-login-info"

# Supprime les fichiers LightDM créés par les anciennes versions du script
cleanup_legacy_greeter() {
    rm -f "$GREETER_DROPIN" "$BG_FILE" /usr/share/backgrounds/login-info.*.png
    if [[ -f "$GREETER_BAK" ]]; then
        mv -f "$GREETER_BAK" "$GREETER_MAIN"
        success "$GREETER_MAIN restauré (reliquat d'une ancienne version)."
    fi
}

echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Adresses IP sur la console (/etc/issue) — $(lsb_release -ds 2>/dev/null || echo "Ubuntu")${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
echo ""

# ---------------------------------------------------------------------------
# Désinstallation
# ---------------------------------------------------------------------------
if [[ "$UNINSTALL" -eq 1 ]]; then
    info "Désinstallation..."
    rm -f "$HOOK"
    cleanup_legacy_greeter
    if [[ -f "$ISSUE_STD" ]]; then
        mv -f "$ISSUE_STD" "$ISSUE"
        success "/etc/issue restauré."
    fi
    success "Désinstallation terminée."
    exit 0
fi

# ---------------------------------------------------------------------------
# ÉTAPE 1 — Pré-vérifications
# ---------------------------------------------------------------------------
info "[1/3] Pré-vérifications..."

command -v nmcli &>/dev/null || die "NetworkManager introuvable. Ce script cible Xubuntu géré par NetworkManager."
systemctl is-active --quiet NetworkManager || warning "NetworkManager n'est pas actif : le dispatcher ne sera appelé qu'après son démarrage."

if [[ -f "$GREETER_DROPIN" || -f "$BG_FILE" || -f "$GREETER_BAK" ]]; then
    info "Nettoyage de la configuration LightDM d'une ancienne version..."
    cleanup_legacy_greeter
fi
success "Pré-vérifications OK."

# ---------------------------------------------------------------------------
# ÉTAPE 2 — Dispatcher NetworkManager
# ---------------------------------------------------------------------------
info "[2/3] Installation du dispatcher NetworkManager..."

if [[ ! -e "$ISSUE_STD" ]]; then
    cp -a "$ISSUE" "$ISSUE_STD"
    success "$ISSUE_STD créé (copie de $ISSUE)."
else
    info "$ISSUE_STD existe déjà : conservé."
fi

cat > "$HOOK" <<'HOOK_EOF'
#!/usr/bin/env bash
# /etc/NetworkManager/dispatcher.d/90-login-info
# Généré par install_issue_xubuntu.sh
#
# Met à jour les adresses IP affichées sur les consoles texte (/etc/issue,
# reconstruit depuis /etc/issue.std) sans ouvrir de session.

ISSUE="/etc/issue"
ISSUE_STD="/etc/issue.std"
# Interfaces ignorées (expression régulière, début de nom)
EXCLUDE_IFACES='^(lo|veth|tun|tap)'

# Couleurs (séquences ANSI interprétées par la console texte)
ESC=$'\033'
C_RST="${ESC}[0m"
C_BORDER="${ESC}[90m"   # gris
C_HEAD="${ESC}[1;36m"   # cyan gras
C_ETH="${ESC}[1;32m"    # vert gras  : Ethernet
C_WIFI="${ESC}[1;36m"   # cyan gras  : Wi-Fi
C_OTHER="${ESC}[0;37m"  # blanc      : autres
C_VIRT="${ESC}[90m"     # gris       : Docker, libvirt
C_ERR="${ESC}[1;31m"    # rouge gras : aucune adresse

iface="${1:-}"
action="${2:-}"

case "$action" in
    up|down|dhcp4-change) ;;
    *) exit 0 ;;
esac

[[ -f "$ISSUE_STD" ]] || exit 0

# Évite deux régénérations simultanées
exec 9>/run/login-info.lock
flock 9

# Sur "down", l'interface qui vient de tomber peut encore apparaître : on l'ignore
skip=""
[[ "$action" == "down" ]] && skip="$iface"

# Lignes "rang|interface|type|adresse/masque", triées : Ethernet d'abord
rows="$(ip -o -4 addr show scope global \
    | awk -v re="$EXCLUDE_IFACES" -v skip="$skip" '
        $2 !~ re && $2 != skip {
            n = $2
            if      (n ~ /^(docker|br-)/) { t = "Docker";   r = 4 }
            else if (n ~ /^virbr/)        { t = "libvirt";  r = 5 }
            else if (n ~ /^(en|eth)/)     { t = "Ethernet"; r = 1 }
            else if (n ~ /^wl/)           { t = "Wi-Fi";    r = 2 }
            else                          { t = "Autre";    r = 3 }
            printf "%d|%s|%s|%s\n", r, n, t, $4
        }' \
    | sort -t'|' -k1,1n -k2,2)"

# Largeurs de colonnes (minimum = largeur de l'en-tête)
w1=9; w2=4; w3=10
while IFS='|' read -r _ n t a; do
    [[ -n "$n" ]] || continue
    (( ${#n} > w1 )) && w1=${#n}
    (( ${#t} > w2 )) && w2=${#t}
    (( ${#a} > w3 )) && w3=${#a}
done <<< "$rows"

bar() { local s="" i; for ((i = 0; i < $1 + 2; i++)); do s+="─"; done; printf '%s' "$s"; }
hr()  { printf '%s%s%s%s%s%s%s%s%s\n' "$C_BORDER" "$1" "$(bar "$w1")" "$2" "$(bar "$w2")" "$2" "$(bar "$w3")" "$3" "$C_RST"; }
trow() {   # couleur interface type adresse
    local c="$1" b="${C_BORDER}│${C_RST}"
    printf '%s %s%-*s%s %s %s%-*s%s %s %s%-*s%s %s\n' \
        "$b" "$c" "$w1" "$2" "$C_RST" "$b" "$c" "$w2" "$3" "$C_RST" "$b" "$c" "$w3" "$4" "$C_RST" "$b"
}

{
    cat "$ISSUE_STD"
    if [[ -n "$rows" ]]; then
        hr "┌" "┬" "┐"
        trow "$C_HEAD" "Interface" "Type" "Adresse IP"
        hr "├" "┼" "┤"
        while IFS='|' read -r r n t a; do
            [[ -n "$n" ]] || continue
            case "$r" in
                1) c="$C_ETH" ;;
                2) c="$C_WIFI" ;;
                3) c="$C_OTHER" ;;
                *) c="$C_VIRT" ;;
            esac
            trow "$c" "$n" "$t" "$a"
        done <<< "$rows"
        hr "└" "┴" "┘"
    else
        printf '%s(aucune adresse)%s\n' "$C_ERR" "$C_RST"
    fi
    printf '%sCtrl+D à l'"'"'invite login : efface l'"'"'écran et réaffiche%s\n\n' "$C_BORDER" "$C_RST"
} > "$ISSUE.tmp" && mv -f "$ISSUE.tmp" "$ISSUE"

# Demande aux consoles en attente de login de relire /etc/issue (écran effacé
# et réaffiché seulement si le contenu a changé et si aucune saisie n'est commencée)
agetty_bin="$(command -v agetty || true)"
[[ -n "$agetty_bin" ]] || agetty_bin="/sbin/agetty"
"$agetty_bin" --reload >/dev/null 2>&1 || true
exit 0
HOOK_EOF

chown root:root "$HOOK"
chmod 755 "$HOOK"
success "$HOOK installé."

# ---------------------------------------------------------------------------
# ÉTAPE 3 — Première génération
# ---------------------------------------------------------------------------
info "[3/3] Génération initiale..."

"$HOOK" "" up || warning "Le dispatcher a retourné une erreur."
success "Terminé. Aperçu de $ISSUE :"
# \n et \l sont interprétés par agetty : on les remplace pour l'aperçu
sed -e "s/\\\\n/$(hostname)/" -e 's/\\l/tty1/' -e 's/^/    /' "$ISSUE"

echo ""
info "Consoles (Ctrl+Alt+F1..F6) : mises à jour automatiques (agetty --reload)."
info "Raccourci manuel : Ctrl+D à l'invite login (agetty relancé, écran effacé)."
info "Test manuel : sudo $HOOK eth0 up"
