#!/usr/bin/env python3

import subprocess
import sys

# Détecter la distribution
def detect_distro():
    try:
        with open("/etc/os-release") as f:
            content = f.read()
            if "Debian" in content:
                return "Debian"
            elif "Ubuntu" in content:
                return "Ubuntu"
            else:
                return "Unknown"
    except FileNotFoundError:
        return "Unknown"

# Fonction pour obtenir la version du noyau
def get_kernel_headers_package():
    try:
        kernel_version = subprocess.check_output(["uname", "-r"]).decode().strip()
        return f"linux-headers-{kernel_version}"
    except subprocess.CalledProcessError as e:
        print(f"Erreur lors de la récupération de la version du noyau : {e}")
        sys.exit(1)

# Dictionnaire des paquets par groupe, avec une section "base" pour les paquets communs
PACKAGES = {
    "base": {
        "base": [
            "aptitude",
            "acl",
            "bash-completion",
            "bat",
            "build-essential",
            "byobu",
            "ccze",
            "curl",
            "git",
            "gnupg2",
            "haveged",
            "less",
            get_kernel_headers_package(),
            "lnav",
            "locales-all",
            "most",
            "multitail",
            "parted",
            "reptyr",
            "screen",
            "screenfetch",
            "neofetch",
            "sudo",
            "tmux",
            "tree",
            "unzip",
            "vim",
            "yadm",
            "zip",
            "zsh",
        ],
        "Debian": [
            "mlocate",
            "rng-tools",
        ],
        "Ubuntu": [
            "plocate",
        ],
    },
    "tp": {
        "base": [
            "apt-file",
            "avahi-daemon",
            "command-not-found",
            "dfc",
            "etckeeper",
            "glances",
            "htop",
            "libnss-mdns",
            "sl",
            "sudo",
            "tftp-hpa",
            "tty-clock",
            "bpytop",
            "fasd",
            "fzf",
            "lsd",
            "net-tools",
            "snapd",
        ],
        "Debian": [],  
        
    },
    "mysql": {
        "base": ["mysql-server", "mysql-client"],
        "Debian": [],  # Pas de paquets spécifiques à Debian ici
    },
    
}

# Fonction pour obtenir la liste complète des paquets à installer
def get_packages(group, distro):
    if group not in PACKAGES:
        print(f"Groupe de paquets {group} non reconnu")
        sys.exit(1)

    base_packages = PACKAGES[group].get("base", [])
    distro_specific_packages = PACKAGES[group].get(distro, [])

    # Combiner les paquets de base et les paquets spécifiques à la distribution
    return list(set(base_packages + distro_specific_packages))

# Fonction pour installer les paquets
def install_packages(packages, dry_run=False):
    if dry_run:
        print(f"Paquets à installer : {', '.join(packages)}")
    else:
        try:
            print(f"Installation des paquets: {', '.join(packages)}")
            subprocess.run(["sudo", "apt", "install", "-y"] + packages, check=True)
        except subprocess.CalledProcessError as e:
            print(f"Erreur lors de l'installation : {e}")
            sys.exit(1)

# Main
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python install.py <group_name> [--dry-run]")
        sys.exit(1)

    group = sys.argv[1].lower()  # Argument du groupe de paquets
    dry_run = "--dry-run" in sys.argv  # Vérifier si le mode dry-run est activé
    distro = detect_distro()  # Détecter la distribution
    print(f"Distribution détectée : {distro}")

    packages = get_packages(group, distro)  # Obtenir les paquets à installer
    if not packages:
        print(f"Aucun paquet à installer pour le groupe {group}")
        sys.exit(1)

    install_packages(packages, dry_run=dry_run)  # Soit lister soit installer les paquets
