#!/usr/bin/env bash
# switch-to-networkmanager.sh
# Objectif : forcer NetworkManager comme gestionnaire réseau (XUbuntu 25.10+)
# Auteur   : J.-Ph. Demory
# Usage    : ./switch-to-networkmanager.sh [--force-apply] [--force]
#
# Options :
#   --force-apply   Utilise "netplan apply" au lieu de "netplan try"
#                   (utile si le terminal n'est pas interactif ou si try n'est pas dispo)
#   --force         Ré-applique la configuration même si NetworkManager est déjà
#                   actif et configuré comme renderer (script normalement idempotent)
#
# Prérequis :
#   - Ubuntu/XUbuntu basé sur netplan (≥ 22.04)
#   - NetworkManager installé (le script le vérifie et propose de l'installer)
#   - Exécution en root (le script se relance via sudo)
#
# Risques :
#   - Coupure réseau temporaire pendant l'application netplan
#   - "netplan try" lance un timeout de 120s : confirmer avec Entrée ou laisser expirer
#
# Restauration rapide (si quelque chose tourne mal) :
#   tar -xzf /root/netplan-backup-YYYYmmdd-HHMMSS.tar.gz -C /
#   netplan apply
#   systemctl restart NetworkManager

# ---------------------------------------------------------------------------
# Gardes initiales (avant set -euo pipefail)
# ---------------------------------------------------------------------------
[[ -n "${BASH_VERSION:-}" ]] || { echo "Ce script doit être exécuté avec bash." >&2; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
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
FORCE_APPLY=0
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force-apply) FORCE_APPLY=1 ;;
        --force)       FORCE=1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Variables globales
# ---------------------------------------------------------------------------
ts="$(date +%Y%m%d-%H%M%S)"
backup_tar="/root/netplan-backup-$ts.tar.gz"
NM_YAML="/etc/netplan/01-network-manager-all.yaml"
NETPLAN_TIMEOUT=120   # secondes pour netplan try

# ---------------------------------------------------------------------------
# ÉTAPE 0 — Pré-vérifications
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Switch vers NetworkManager — $(lsb_release -ds 2>/dev/null || echo "Ubuntu")${NC}"
echo -e "${BLUE}══════════════════════════════════════════════════════${NC}"
echo ""

info "[0/6] Pré-vérifications..."

# netplan doit être présent
command -v netplan &>/dev/null || die "netplan introuvable. Ce script cible Ubuntu/XUbuntu basé sur netplan."

# NetworkManager : vérifier, proposer d'installer si absent
if ! command -v NetworkManager &>/dev/null && ! dpkg -l network-manager &>/dev/null 2>&1; then
    warning "NetworkManager n'est pas installé."
    read -r -p "  Voulez-vous l'installer maintenant ? [O/n] " answer
    case "${answer,,}" in
        n|non) die "NetworkManager requis. Annulation." ;;
        *)
            info "Installation de NetworkManager..."
            apt-get update -q
            apt-get install -y --no-install-recommends network-manager
            success "NetworkManager installé."
            ;;
    esac
fi

# Idempotence : depuis que les installeurs desktop Ubuntu/Xubuntu génèrent nativement
# 01-network-manager-all.yaml, NM est souvent déjà le renderer actif — rien à faire.
if [[ $FORCE -eq 0 ]] \
    && systemctl is-active --quiet NetworkManager.service \
    && ! systemctl is-active --quiet systemd-networkd.service \
    && [[ -f "$NM_YAML" ]] \
    && grep -q "renderer: NetworkManager" "$NM_YAML" 2>/dev/null; then
    success "NetworkManager est déjà actif et configuré comme renderer netplan ($NM_YAML)."
    info "Rien à faire. Utilisez --force pour ré-appliquer la configuration quand même."
    exit 0
fi

# Avertir si on détecte une session SSH (la coupure réseau interromprait la connexion)
if [[ -n "${SSH_CONNECTION:-}" || -n "${SSH_CLIENT:-}" ]]; then
    warning "Session SSH détectée !"
    warning "  L'application netplan peut interrompre cette connexion."
    warning "  Conseil : lancez ce script dans un 'screen' ou 'tmux'."
    read -r -p "  Continuer quand même ? [o/N] " answer
    case "${answer,,}" in
        o|oui) ;;
        *) die "Annulé par l'utilisateur." ;;
    esac
fi

success "Pré-vérifications OK."

# ---------------------------------------------------------------------------
# ÉTAPE 1 — Sauvegarde complète
# ---------------------------------------------------------------------------
info "[1/6] Sauvegarde de /etc/netplan → $backup_tar"
tar -czf "$backup_tar" -C /etc netplan
success "Backup créé : $backup_tar"

# ---------------------------------------------------------------------------
# ÉTAPE 2 — Écriture du fichier netplan NetworkManager
# ---------------------------------------------------------------------------
info "[2/6] Écriture de $NM_YAML"
cat > "$NM_YAML" <<'YAML'
network:
  version: 2
  renderer: NetworkManager
YAML

# Permissions strictes requises par netplan ≥ 0.106 (Ubuntu 23.10+)
# Sans chmod 600, netplan refuse de s'exécuter et affiche une erreur cryptique
chmod 600 "$NM_YAML"
chown root:root "$NM_YAML"
success "Fichier écrit avec permissions 600."

# ---------------------------------------------------------------------------
# ÉTAPE 3 — Mise de côté des anciens fichiers YAML
# ---------------------------------------------------------------------------
info "[3/6] Mise de côté des anciens fichiers YAML netplan"
shopt -s nullglob
disabled_count=0
for f in /etc/netplan/*.yaml; do
    [[ "$f" == "$NM_YAML" ]] && continue
    mv -v "$f" "${f}.disabled-$ts"
    (( disabled_count++ )) || true
done
shopt -u nullglob

if [[ $disabled_count -gt 0 ]]; then
    success "$disabled_count fichier(s) renommé(s) en .disabled-$ts"
else
    info "Aucun autre fichier YAML à mettre de côté."
fi

# ---------------------------------------------------------------------------
# ÉTAPE 4 — Gestion de systemd-networkd et systemd-resolved
# ---------------------------------------------------------------------------
info "[4/6] Gestion de systemd-networkd et systemd-resolved"

# Désactiver networkd APRÈS que NM est prêt à prendre le relais
# (on ne coupe pas le réseau avant d'avoir un remplaçant)
if systemctl is-active --quiet systemd-networkd.service 2>/dev/null; then
    systemctl disable --now systemd-networkd.service systemd-networkd.socket 2>/dev/null || true
    success "systemd-networkd désactivé."
else
    info "systemd-networkd n'était pas actif."
fi

# Sur Ubuntu 25.10, NetworkManager délègue la résolution DNS à systemd-resolved.
# Il faut s'assurer que resolved est actif et que NM est configuré pour l'utiliser.
if systemctl list-unit-files systemd-resolved.service &>/dev/null; then
    systemctl enable --now systemd-resolved.service 2>/dev/null \
        && success "systemd-resolved actif (DNS)." \
        || warning "Impossible d'activer systemd-resolved."

    # Configurer NM pour utiliser systemd-resolved comme DNS backend
    NM_CONF_DIR="/etc/NetworkManager/conf.d"
    mkdir -p "$NM_CONF_DIR"
    if [[ ! -f "$NM_CONF_DIR/dns-resolved.conf" ]]; then
        cat > "$NM_CONF_DIR/dns-resolved.conf" <<'EOF'
[main]
dns=systemd-resolved
EOF
        chmod 644 "$NM_CONF_DIR/dns-resolved.conf"
        success "NM configuré pour déléguer le DNS à systemd-resolved."
    else
        info "Configuration DNS NM déjà présente."
    fi
fi

# ---------------------------------------------------------------------------
# ÉTAPE 5 — Application netplan
# ---------------------------------------------------------------------------
info "[5/6] Application de la configuration netplan"

# Vérifier la syntaxe avant d'appliquer
if netplan generate --debug &>/dev/null 2>&1; then
    success "Syntaxe netplan valide."
else
    # Pas fatal : generate --debug peut échouer même si la config est correcte
    warning "netplan generate a retourné une erreur — on tente quand même l'application."
fi

# Choisir entre "try" (avec rollback automatique) et "apply" (immédiat)
if [[ $FORCE_APPLY -eq 1 ]]; then
    info "Mode --force-apply : utilisation de 'netplan apply'."
    netplan apply
elif netplan try --help &>/dev/null 2>&1; then
    info "Utilisation de 'netplan try' (timeout ${NETPLAN_TIMEOUT}s)."
    info "→ Appuyer sur ENTRÉE pour confirmer, ou attendre l'expiration du timeout pour rollback."
    netplan try --timeout "$NETPLAN_TIMEOUT" || {
        error "netplan try a expiré ou a été refusé — rollback automatique effectué."
        die "Vérifiez la configuration netplan et relancez le script."
    }
else
    warning "'netplan try' indisponible — utilisation de 'netplan apply'."
    netplan apply
fi

success "Configuration netplan appliquée."

# ---------------------------------------------------------------------------
# ÉTAPE 6 — Démarrage et vérification de NetworkManager
# ---------------------------------------------------------------------------
info "[6/6] Démarrage et vérification de NetworkManager"

systemctl enable --now NetworkManager.service 2>/dev/null \
    && success "NetworkManager activé et démarré." \
    || warning "Problème lors du démarrage de NetworkManager."

# Laisser NM s'initialiser
sleep 2

# Vérification : NM gère-t-il des interfaces ?
if command -v nmcli &>/dev/null; then
    NM_STATUS=$(nmcli general status 2>/dev/null | tail -n +2 | head -1 || true)
    if [[ -n "$NM_STATUS" ]]; then
        success "nmcli répond : $NM_STATUS"
    else
        warning "nmcli ne retourne pas de statut — NM est peut-être encore en cours d'initialisation."
    fi

    # Lister les interfaces gérées
    MANAGED_IFACES=$(nmcli device status 2>/dev/null | awk 'NR>1 && $3 == "connected" {print $1}' || true)
    if [[ -n "$MANAGED_IFACES" ]]; then
        success "Interfaces connectées via NM : $MANAGED_IFACES"
    else
        warning "Aucune interface connectée pour l'instant (normal si DHCP est en cours)."
    fi
fi

# ---------------------------------------------------------------------------
# Résumé final
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Basculement vers NetworkManager terminé${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo "  Fichiers importants :"
echo "    Backup netplan   : $backup_tar"
echo "    Config netplan   : $NM_YAML"
echo "    Config NM/DNS    : /etc/NetworkManager/conf.d/dns-resolved.conf"
if [[ $disabled_count -gt 0 ]]; then
echo "    Anciens YAML     : /etc/netplan/*.yaml.disabled-$ts"
fi
echo ""
echo "  Restauration d'urgence :"
echo "    tar -xzf $backup_tar -C /"
echo "    netplan apply"
echo ""
echo -e "${YELLOW}  → Un redémarrage est conseillé pour s'assurer que${NC}"
echo -e "${YELLOW}    tous les services démarrent dans le bon ordre.${NC}"
echo ""
