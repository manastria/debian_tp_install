#!/bin/bash

# Obtenir le répertoire du script
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Chemin absolu du fichier rc.local attendu
RC_LOCAL_SRC="$SCRIPT_DIR/rc.local"
RC_LOCAL_DEST="/etc/rc.local"
SERVICE_FILE="/etc/systemd/system/rc-local.service"

# Vérifier si le script est exécuté avec les privilèges root
if [[ $EUID -ne 0 ]]; then
    echo "Erreur : Ce script doit être exécuté avec les privilèges root."
    exit 1
fi

# Vérifier si le fichier rc.local existe dans le répertoire du script
if [[ ! -f "$RC_LOCAL_SRC" ]]; then
    echo "Erreur : Le fichier rc.local est introuvable dans le répertoire $SCRIPT_DIR."
    exit 1
fi

# Créer le fichier rc-local.service
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=/etc/rc.local
ConditionPathExists=$RC_LOCAL_DEST

[Service]
Type=forking
ExecStartPre=/bin/sleep 3
ExecStart=$RC_LOCAL_DEST start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF

# Copier le fichier rc.local vers /etc et s'assurer qu'il est exécutable
cp "$RC_LOCAL_SRC" "$RC_LOCAL_DEST"
chmod +x "$RC_LOCAL_DEST"

# Activer le service rc-local
systemctl enable rc-local.service

echo "Le service rc-local a été configuré avec succès."
