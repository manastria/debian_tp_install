#!/bin/bash
# =============================================================================
# install_guest_additions.sh
# Installation des VirtualBox Guest Additions pour XUbuntu
# Gère : driver graphique, presse-papier partagé, drag-and-drop, dossiers partagés
# =============================================================================

set -euo pipefail

# --- Couleurs pour les messages ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERREUR]${NC} $*" >&2; }

# --- Escalade sudo ---
if [ "$EUID" -ne 0 ]; then
    exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

# --- Variables ---
ISO_PATH="/tmp/VBoxGuestAdditions_$$.iso"
MOUNT_DIR="/tmp/VBoxGA_mount_$$"
VBOX_VERSION=""

# --- Nettoyage à la sortie (succès ou échec) ---
cleanup() {
    local exit_code=$?
    if mountpoint -q "$MOUNT_DIR" 2>/dev/null; then
        umount "$MOUNT_DIR" 2>/dev/null || true
    fi
    rm -f "$ISO_PATH" 2>/dev/null || true
    rmdir "$MOUNT_DIR" 2>/dev/null || true
    if [ $exit_code -ne 0 ]; then
        error "Le script s'est terminé avec une erreur (code $exit_code)."
    fi
}
trap cleanup EXIT

# =============================================================================
# 1. Déterminer la version cible
# =============================================================================
info "Détection de la version VirtualBox cible..."

# Priorité 1 : version passée en argument (--version X.Y.Z)
if [[ "${1:-}" == "--version" && -n "${2:-}" ]]; then
    VBOX_VERSION="$2"
    info "Version forcée via argument : $VBOX_VERSION"

# Priorité 2 : version détectée depuis les Guest Additions déjà installées
elif command -v VBoxControl &>/dev/null; then
    VBOX_VERSION=$(VBoxControl --nologo guestproperty get "/VirtualBox/GuestAdd/VersionExt" 2>/dev/null \
        | awk '{print $2}' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
    if [[ -n "$VBOX_VERSION" ]]; then
        info "Version détectée depuis les GA existantes : $VBOX_VERSION"
    fi
fi

# Priorité 3 : version de l'hôte via DMI (fonctionne si la VM expose cette info)
if [[ -z "$VBOX_VERSION" ]]; then
    VBOX_VERSION=$(dmidecode -s bios-version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
    if [[ -n "$VBOX_VERSION" ]]; then
        info "Version détectée via DMI (hôte) : $VBOX_VERSION"
    fi
fi

# Fallback : dernière version disponible (risque de décalage avec l'hôte)
if [[ -z "$VBOX_VERSION" ]]; then
    warning "Impossible de détecter la version de l'hôte VirtualBox."
    warning "Utilisation de la dernière version disponible — peut ne pas correspondre à l'hôte !"
    VBOX_VERSION=$(curl -sf https://download.virtualbox.org/virtualbox/LATEST.TXT)
    info "Dernière version disponible : $VBOX_VERSION"
fi

info "Version cible des Guest Additions : ${GREEN}$VBOX_VERSION${NC}"

# =============================================================================
# 2. Dépendances système
# =============================================================================
info "Mise à jour des paquets et installation des dépendances..."
apt-get update -q

# Dépendances de compilation des modules kernel
apt-get install -y --no-install-recommends \
    dkms \
    build-essential \
    linux-headers-"$(uname -r)" \
    curl \
    wget

# Dépendances pour le support graphique, presse-papier et drag-and-drop
# virtualbox-guest-x11 : driver vboxvideo + intégration X11 (clipboard, D&D)
# xserver-xorg-video-vmware est parfois en conflit, on s'assure de l'exclusion
apt-get install -y --no-install-recommends \
    virtualbox-guest-x11 \
    || warning "Paquet virtualbox-guest-x11 indisponible depuis les dépôts — les GA compilées prendront le relais."

success "Dépendances installées."

# =============================================================================
# 3. Téléchargement et vérification de l'ISO
# =============================================================================
ISO_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso"
SHA256_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/SHA256SUMS"

info "Téléchargement de l'ISO depuis : $ISO_URL"
if ! curl -f --progress-bar -o "$ISO_PATH" "$ISO_URL"; then
    error "Échec du téléchargement. La version $VBOX_VERSION existe-t-elle ?"
    error "URL tentée : $ISO_URL"
    exit 1
fi

info "Vérification de l'intégrité (SHA256)..."
EXPECTED_SHA256=$(curl -sf "$SHA256_URL" | grep "VBoxGuestAdditions_${VBOX_VERSION}.iso" | awk '{print $1}')
if [[ -n "$EXPECTED_SHA256" ]]; then
    ACTUAL_SHA256=$(sha256sum "$ISO_PATH" | awk '{print $1}')
    if [[ "$EXPECTED_SHA256" == "$ACTUAL_SHA256" ]]; then
        success "SHA256 vérifié : $ACTUAL_SHA256"
    else
        error "Vérification SHA256 ÉCHOUÉE !"
        error "  Attendu : $EXPECTED_SHA256"
        error "  Obtenu  : $ACTUAL_SHA256"
        exit 1
    fi
else
    warning "Impossible de récupérer le SHA256 attendu — vérification ignorée."
fi

# =============================================================================
# 4. Montage et installation
# =============================================================================
mkdir -p "$MOUNT_DIR"
info "Montage de l'ISO sur $MOUNT_DIR..."
mount -o loop,ro "$ISO_PATH" "$MOUNT_DIR"

info "Lancement de VBoxLinuxAdditions.run..."
# Le script retourne parfois un code != 0 même en succès partiel (ex: driver 3D).
# On capture le code et on inspecte le résultat plutôt que de s'y fier aveuglément.
set +e
sh "$MOUNT_DIR/VBoxLinuxAdditions.run" --nox11 2>&1 | tee /tmp/vboxga_install.log
INSTALL_EXIT=$?
set -e

if [ $INSTALL_EXIT -ne 0 ]; then
    # Certains échecs sont bénins (ex: OpenGL non dispo dans la VM)
    if grep -qiE "Installing.*\.\.\. done|VirtualBox Guest Additions.*installed" /tmp/vboxga_install.log; then
        warning "Code de retour non nul ($INSTALL_EXIT) mais l'installation semble réussie."
        warning "Voir /tmp/vboxga_install.log pour les détails."
    else
        error "Installation échouée (code $INSTALL_EXIT). Consulter /tmp/vboxga_install.log."
        exit $INSTALL_EXIT
    fi
fi

# =============================================================================
# 5. Vérification post-installation
# =============================================================================
info "Vérification du chargement des modules kernel..."

# Forcer le chargement immédiat sans redémarrer
modprobe vboxguest  2>/dev/null && success "Module vboxguest chargé."      || warning "Module vboxguest non chargé (sera actif après redémarrage)."
modprobe vboxsf     2>/dev/null && success "Module vboxsf chargé (dossiers partagés)." || warning "Module vboxsf non chargé."
modprobe vboxvideo  2>/dev/null && success "Module vboxvideo chargé (driver graphique)." || warning "Module vboxvideo non chargé."

# =============================================================================
# 6. Configuration post-installation
# =============================================================================

# Ajouter l'utilisateur courant au groupe vboxsf pour les dossiers partagés
# On récupère l'utilisateur réel (avant sudo)
REAL_USER="${SUDO_USER:-}"
if [[ -n "$REAL_USER" ]] && id "$REAL_USER" &>/dev/null; then
    if ! groups "$REAL_USER" | grep -qw vboxsf; then
        usermod -aG vboxsf "$REAL_USER"
        success "Utilisateur '$REAL_USER' ajouté au groupe vboxsf (dossiers partagés)."
    else
        info "Utilisateur '$REAL_USER' déjà membre du groupe vboxsf."
    fi
else
    warning "Impossible de déterminer l'utilisateur courant — ajoutez-vous manuellement au groupe vboxsf :"
    warning "  sudo usermod -aG vboxsf \$USER"
fi

# Activer le service VBoxService (clipboard, time sync, drag-and-drop)
if systemctl list-unit-files | grep -q vboxadd-service; then
    systemctl enable --now vboxadd-service 2>/dev/null \
        && success "Service vboxadd-service activé." \
        || warning "Impossible d'activer vboxadd-service maintenant (sera fait au démarrage)."
fi

# =============================================================================
# Résumé
# =============================================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Installation des Guest Additions $VBOX_VERSION terminée${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo "  Fonctionnalités activées après redémarrage :"
echo "    ✓ Redimensionnement automatique de l'écran"
echo "    ✓ Driver graphique vboxvideo"
echo "    ✓ Presse-papier partagé (à activer dans Périphériques > Presse-papier)"
echo "    ✓ Drag & Drop (à activer dans Périphériques > Drag and Drop)"
echo "    ✓ Dossiers partagés (groupe vboxsf)"
echo "    ✓ Synchronisation de l'heure"
echo ""
echo -e "${YELLOW}  → Redémarrez la VM pour finaliser l'installation.${NC}"
echo ""
