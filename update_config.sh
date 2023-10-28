#!/usr/bin/env bash

# Variables pour les dépôts

# Dotfiles
DOTFILES_REPO_HTTPS="https://github.com/manastria/dotfile.git"
DOTFILES_REPO_SSH="git@github.com:manastria/dotfile.git"
DOTFILES_BRANCH="main"

# Debian installation
DEBIAN_INSTALL_REPO_HTTPS="https://github.com/manastria/debian_tp_install.git"
DEBIAN_INSTALL_REPO_SSH="git@github.com:manastria/debian_tp_install.git"
DEBIAN_INSTALL_BRANCH="debian_12"

# Debian configuration
DEBIAN_CONFIG_REPO_HTTPS="https://github.com/manastria/debian_config.git"
DEBIAN_CONFIG_REPO_SSH="git@github.com:manastria/debian_config.git"
DEBIAN_CONFIG_BRANCH="main"

# Fonctions

configure_git_repo() {
    local repo_path=$1
    local repo_https=$2
    local repo_ssh=$3
    echo "Configuration des URLs pour le dépôt $repo_path"
    git -C $repo_path remote set-url origin $repo_https
    git -C $repo_path remote set-url origin --push $repo_ssh
}

pull_latest_changes() {
    local repo_path=$1
    local branch_name=$2
    echo "Récupération des dernières modifications pour le dépôt $repo_path"
    git -C $repo_path pull origin $branch_name
}

update_submodules() {
    local submodule_name=$1
    local repo_https=$2
    local repo_ssh=$3
    echo "Mise à jour des sous-modules pour $submodule_name"
    git config submodule.$submodule_name.url $repo_https
    git config submodule.$submodule_name.pushurl $repo_ssh
    git submodule sync
    git submodule update --init --recursive
    git submodule update --remote
}

# Script principal

# Configuration et mise à jour du dépôt Debian Install
configure_git_repo "." $DEBIAN_INSTALL_REPO_HTTPS $DEBIAN_INSTALL_REPO_SSH
pull_latest_changes "." $DEBIAN_INSTALL_BRANCH
update_submodules "debian_config" $DEBIAN_CONFIG_REPO_HTTPS $DEBIAN_CONFIG_REPO_SSH
