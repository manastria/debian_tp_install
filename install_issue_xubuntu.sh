#!/usr/bin/env bash
# install_issue_xubuntu.sh
# Objectif : afficher le hostname et les adresses IP sans ouvrir de session
#              - consoles texte (Ctrl+Alt+F1 à F6) : via /etc/issue
#              - écran de connexion LightDM : hostname dans la barre du haut
#                (indicateur ~host) et hostname + IP sur l'image de fond
# Auteur   : Manastria
# Usage    : sudo ./install_issue_xubuntu.sh [--uninstall]
#
# Fonctionnement :
#   Un script dispatcher NetworkManager (/etc/NetworkManager/dispatcher.d/90-login-info)
#   s'exécute à chaque changement réseau (up, down, dhcp4-change, hostname).
#   Il régénère /etc/issue à partir de /etc/issue.std, puis l'image de fond
#   du greeter. Remplace install_issue.sh (ifupdown, Debian) sur Xubuntu.
#
# Prérequis :
#   - Xubuntu 24.04+ (LightDM + lightdm-gtk-greeter) géré par NetworkManager
#   - Exécution en root (le script se relance via sudo)
#   - Accès aux dépôts apt (paquets imagemagick et fonts-dejavu-core)
#
# Remarques :
#   - L'image de fond est relue à chaque affichage du greeter (déconnexion,
#     verrouillage, redémarrage). LightDM n'est PAS redémarré par le script :
#     cela fermerait les sessions ouvertes.
#   - Pour rafraîchir une console texte : systemctl restart getty@tty1
#     (ferme la session ouverte sur tty1).
#   - Les réglages de l'image (taille, couleurs, interfaces ignorées) se
#     modifient en tête du fichier dispatcher généré.
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
# Variables globales (à garder cohérentes avec l'en-tête du dispatcher généré)
# ---------------------------------------------------------------------------
HOOK="/etc/NetworkManager/dispatcher.d/90-login-info"
ISSUE="/etc/issue"
ISSUE_STD="/etc/issue.std"
BG_FILE="/usr/share/backgrounds/login-info.png"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
GREETER_MAIN="/etc/lightdm/lightdm-gtk-greeter.conf"
GREETER_DROPIN="/etc/lightdm/lightdm-gtk-greeter.conf.d/50-login-info.conf"
GREETER_BAK="${GREETER_MAIN}.bak-login-info"

echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Hostname et IP à l'écran de connexion — $(lsb_release -ds 2>/dev/null || echo "Ubuntu")${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
echo ""

# ---------------------------------------------------------------------------
# Désinstallation
# ---------------------------------------------------------------------------
if [[ "$UNINSTALL" -eq 1 ]]; then
    info "Désinstallation..."
    rm -f "$HOOK" "$GREETER_DROPIN" "$BG_FILE"
    if [[ -f "$ISSUE_STD" ]]; then
        mv -f "$ISSUE_STD" "$ISSUE"
        success "/etc/issue restauré."
    fi
    if [[ -f "$GREETER_BAK" ]]; then
        mv -f "$GREETER_BAK" "$GREETER_MAIN"
        success "$GREETER_MAIN restauré."
    fi
    success "Désinstallation terminée."
    exit 0
fi

# ---------------------------------------------------------------------------
# ÉTAPE 1 — Pré-vérifications
# ---------------------------------------------------------------------------
info "[1/5] Pré-vérifications..."

command -v nmcli &>/dev/null || die "NetworkManager introuvable. Ce script cible Xubuntu géré par NetworkManager."
systemctl is-active --quiet NetworkManager || warning "NetworkManager n'est pas actif : le dispatcher ne sera appelé qu'après son démarrage."

HAS_LIGHTDM=0
if [[ -d /etc/lightdm ]]; then
    HAS_LIGHTDM=1
    success "LightDM détecté : console texte et écran de connexion graphique."
else
    warning "LightDM absent : seule la console texte (/etc/issue) sera configurée."
fi

# ---------------------------------------------------------------------------
# ÉTAPE 2 — Paquets
# ---------------------------------------------------------------------------
info "[2/5] Paquets nécessaires..."

if [[ "$HAS_LIGHTDM" -eq 1 ]]; then
    need=()
    command -v magick &>/dev/null || command -v convert &>/dev/null || need+=(imagemagick)
    [[ -f "$FONT" ]] || need+=(fonts-dejavu-core)
    if (( ${#need[@]} )); then
        info "Installation de : ${need[*]}"
        apt-get update -q
        apt-get install -y --no-install-recommends "${need[@]}"
    fi
    success "ImageMagick et police DejaVu disponibles."
else
    info "Rien à installer (pas de LightDM)."
fi

# ---------------------------------------------------------------------------
# ÉTAPE 3 — Dispatcher NetworkManager
# ---------------------------------------------------------------------------
info "[3/5] Installation du dispatcher NetworkManager..."

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
# Met à jour le hostname et les adresses IP affichés sans ouvrir de session :
#   - consoles texte : /etc/issue (reconstruit depuis /etc/issue.std)
#   - écran de connexion LightDM : image de fond

ISSUE="/etc/issue"
ISSUE_STD="/etc/issue.std"
BG_FILE="/usr/share/backgrounds/login-info.png"
BG_SIZE="1920x1080"
BG_COLOR="#1e1e2e"
HOST_COLOR="#cdd6f4"
IP_COLOR="#a6adc8"
FONT="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
EXCLUDE_IFACES='^(lo|docker|veth|virbr|br-|tun|tap)'

iface="${1:-}"
action="${2:-}"

case "$action" in
    up|down|dhcp4-change|hostname) ;;
    *) exit 0 ;;
esac

# Évite deux régénérations simultanées
exec 9>/run/login-info.lock
flock 9

# Sur "down", l'interface qui vient de tomber peut encore apparaître : on l'ignore
skip=""
[[ "$action" == "down" ]] && skip="$iface"

host="$(hostname)"
addrs="$(ip -o -4 addr show scope global \
    | awk -v re="$EXCLUDE_IFACES" -v skip="$skip" \
        '$2 !~ re && $2 != skip { split($4, a, "/"); printf "%s - %s\n", $2, a[1] }')"
[[ -n "$addrs" ]] || addrs="(aucune adresse)"

# --- Console texte ---------------------------------------------------------
if [[ -f "$ISSUE_STD" ]]; then
    { cat "$ISSUE_STD"; echo "$addrs"; echo; } > "$ISSUE.tmp" && mv -f "$ISSUE.tmp" "$ISSUE"
fi

# --- Écran de connexion LightDM --------------------------------------------
[[ -d /etc/lightdm ]] || exit 0
im="$(command -v magick || command -v convert || true)"
[[ -n "$im" && -f "$FONT" ]] || exit 0

tmp="$(mktemp --suffix=.png "${BG_FILE%.png}.XXXXXX")"
if "$im" -size "$BG_SIZE" "xc:$BG_COLOR" -gravity center -font "$FONT" \
        -fill "$HOST_COLOR" -pointsize 96 -annotate +0-200 "$host" \
        -fill "$IP_COLOR" -pointsize 54 -interline-spacing 12 -annotate +0+60 "$addrs" \
        "$tmp"; then
    chmod 644 "$tmp"
    mv -f "$tmp" "$BG_FILE"
else
    rm -f "$tmp"
fi
exit 0
HOOK_EOF

chown root:root "$HOOK"
chmod 755 "$HOOK"
success "$HOOK installé."

# ---------------------------------------------------------------------------
# ÉTAPE 4 — Greeter LightDM
# ---------------------------------------------------------------------------
info "[4/5] Configuration du greeter LightDM..."

if [[ "$HAS_LIGHTDM" -eq 1 ]]; then
    mkdir -p "$(dirname "$GREETER_DROPIN")"
    cat > "$GREETER_DROPIN" <<EOF
[greeter]
background=$BG_FILE
user-background=false
indicators=~host;~spacer;~clock;~spacer;~language;~session;~a11y;~power
EOF
    chmod 644 "$GREETER_DROPIN"
    success "$GREETER_DROPIN écrit (indicateur ~host + image de fond)."

    # Le fichier principal est lu en dernier : il écraserait le fichier ci-dessus
    if [[ -f "$GREETER_MAIN" ]] && grep -qE '^[[:space:]]*(background|user-background|indicators)[[:space:]]*=' "$GREETER_MAIN"; then
        [[ -e "$GREETER_BAK" ]] || cp -a "$GREETER_MAIN" "$GREETER_BAK"
        sed -i -E 's/^([[:space:]]*)(background|user-background|indicators)([[:space:]]*=)/\1#\2\3/' "$GREETER_MAIN"
        warning "Réglages background/user-background/indicators commentés dans $GREETER_MAIN (sauvegarde : $GREETER_BAK)."
    fi

    # Contrôle : d'autres fichiers de config du greeter définissent-ils les mêmes clés ?
    # (information seulement : ces fichiers ne sont pas modifiés)
    conflicts=()
    for f in /etc/lightdm/lightdm-gtk-greeter.conf.d/*.conf \
             /usr/share/lightdm/lightdm-gtk-greeter.conf.d/*.conf \
             /etc/xdg/lightdm/lightdm-gtk-greeter.conf; do
        [[ -f "$f" && "$f" != "$GREETER_DROPIN" ]] || continue
        if grep -qE '^[[:space:]]*(background|user-background|indicators)[[:space:]]*=' "$f"; then
            conflicts+=("$f")
        fi
    done
    if (( ${#conflicts[@]} )); then
        warning "D'autres fichiers définissent background/user-background/indicators :"
        printf '          - %s\n' "${conflicts[@]}"
        warning "Selon l'ordre de lecture du greeter, ils peuvent prendre le pas sur $GREETER_DROPIN."
        warning "Si l'image n'apparaît pas, commentez ces clés ou renommez le drop-in pour qu'il soit lu en dernier."
    else
        success "Aucun autre fichier de config du greeter ne redéfinit ces clés."
    fi
else
    info "Ignoré (pas de LightDM)."
fi

# ---------------------------------------------------------------------------
# ÉTAPE 5 — Première génération
# ---------------------------------------------------------------------------
info "[5/5] Génération initiale..."

"$HOOK" "" up || warning "Le dispatcher a retourné une erreur."
success "Terminé. Contenu actuel de $ISSUE :"
sed 's/^/    /' "$ISSUE"
[[ -f "$BG_FILE" ]] && success "Image de fond : $BG_FILE"

echo ""
info "Console texte : systemctl restart getty@tty1 (ferme la session de tty1)"
info "Écran graphique : visible à la prochaine déconnexion ou au prochain démarrage"
info "Test manuel : sudo $HOOK eth0 up"
