#!/usr/bin/env python3


import argparse
import os
import subprocess
import sys
import time
import yaml
import apt

CACHE_UPDATE_INTERVAL = 7200  # Mettre à jour le cache des paquets toutes les 2 heures (en secondes)

import apt

def find_file(filename):
    """
    Cherche le fichier en suivant un ordre défini :
    - Répertoire de l'utilisateur actuel
    - Répertoire du script
    - Répertoire HOME de l'utilisateur
    Retourne le chemin complet du fichier s'il est trouvé, sinon None.
    """
    # Répertoire de l'utilisateur actuel
    current_dir = os.getcwd()
    if os.path.exists(os.path.join(current_dir, filename)):
        return os.path.join(current_dir, filename)
    
    # Répertoire du script
    script_dir = os.path.dirname(os.path.realpath(__file__))
    if os.path.exists(os.path.join(script_dir, filename)):
        return os.path.join(script_dir, filename)
    
    # Répertoire HOME de l'utilisateur
    home_dir = os.path.expanduser("~")
    if os.path.exists(os.path.join(home_dir, filename)):
        return os.path.join(home_dir, filename)
    
    return None


def install_packages(packages):
    """
    Installe les packages spécifiés en utilisant la bibliothèque python3-apt.
    Les packages déjà installés sont affichés en vert avec leur numéro de version.
    Les packages à installer sont affichés en bleu.
    Les packages qui n'existent pas sont affichés en rouge.
    Prend en compte les paquets virtuels.
    """

    # Initialise un cache APT qui permet de rechercher et manipuler les paquets
    cache = apt.Cache()

    # Initialise trois dictionnaires pour stocker les paquets déjà installés, les paquets à installer et les paquets inexistants
    installed_packages = {}
    to_install_packages = []
    non_existent_packages = []

    # Parcourt la liste des paquets et vérifie s'ils sont déjà installés ou s'ils existent
    for package_name in packages:
        if package_name in cache:
            package = cache[package_name]
            if package.is_installed:
                # Si le paquet est déjà installé, stocke le numéro de version dans le dictionnaire installed_packages
                installed_packages[package_name] = package.installed.version
            else:
                # Si le paquet n'est pas installé, l'ajoute à la liste des paquets à installer
                to_install_packages.append(package_name)
        else:
            # Vérifie si le paquet est un paquet virtuel
            is_virtual_package = False
            for pkg in cache.get_providing_packages(package_name):
                is_virtual_package = True
                if pkg.is_installed:
                    installed_packages[package_name] = pkg.installed.version
                    break
                else:
                    to_install_packages.append(pkg.name)
            if not is_virtual_package:
                non_existent_packages.append(package_name)

    # Affiche les paquets déjà installés en vert avec leur numéro de version
    if installed_packages:
        print('Packages already installed:')
        for package, version in installed_packages.items():
            print(f'\033[92m{package} ({version})\033[0m')

    # Affiche les paquets inexistants en rouge
    if non_existent_packages:
        print('Non-existent packages:')
        for package in non_existent_packages:
            print(f'\033[91m{package}\033[0m')

    # Si des paquets doivent être installés, affiche-les en bleu et installe-les
    if to_install_packages:
        print('Packages to install:')
        for package in to_install_packages:
            print(f'\033[94m{package}\033[0m')
        cache.update()  # Met à jour le cache des paquets
        cache.open(None)  # Ouvre le cache à nouveau pour prendre en compte les modifications
        for package in to_install_packages:
            if package in cache:
                cache[package].mark_install()  # Marque les paquets pour l'installation
        cache.commit()  # Commence l'installation des paquets marqués
    else:
        # Si aucun paquet n'a besoin d'être installé et aucun paquet inexistant, affiche un message approprié
        if not non_existent_packages:
            print('No new packages to install.')



def create_parser():
    """
    Crée et retourne le parser des arguments de la ligne de commande.
    """
    parser = argparse.ArgumentParser(description='Script pour installer des packages à partir d’un fichier YAML.')
    parser.add_argument('-f', '--file', help='Path to the YAML file containing the packages to install', default='packages.yaml')
    parser.add_argument('-c', '--category', help='Name of the category to install')
    parser.add_argument('-s', '--subcategories', help='Name of the subcategories to install', nargs='*', default=[])
    return parser

def parse_arguments(parser):
    """
    Parse les arguments de la ligne de commande en utilisant le parser donné et les retourne sous forme d'un objet argparse.Namespace.
    """
    return parser.parse_args()

def display_help(parser):
    """
    Affiche l'aide du parser.
    """
    print(parser.format_help())

def check_root():
    """
    Vérifie si l'utilisateur est root. Si ce n'est pas le cas, affiche un message d'erreur et quitte le script.
    """
    if os.geteuid() != 0:
        print('This script must be run as root!')
        sys.exit(1)

def load_yaml_file(file_path):
    """
    Charge le fichier YAML et retourne son contenu.
    """
    with open(file_path) as f:
        return yaml.load(f, Loader=yaml.FullLoader)

def get_packages_to_install(data, category, subcategories):
    """
    Retourne la liste des packages à installer en fonction de la catégorie et des sous-catégories spécifiées.
    """
    packages = []
    for subcategory in subcategories:
        if subcategory in data[category]:
            packages += data[category][subcategory]
    if 'other_packages' in data[category]:
        packages += data[category]['other_packages']
    
    # Remplacer le mot clé 'linux_headers' par 'linux-headers-$(uname -r)'
    if 'linux_headers' in packages:
        packages.remove('linux_headers')
        linux_headers_pkg = f'linux-headers-{os.uname().release}'
        packages.append(linux_headers_pkg)
    
    # Supprime les doublons
    return list(set(packages))

def check_last_update():
    """
    Vérifie l'heure du dernier apt-get update et le met à jour si nécessaire.
    """
    dotfile_path = os.path.expanduser('~/.install_packages_last_update')
    if os.path.exists(dotfile_path):
        with open(dotfile_path, 'r') as f:
            last_update_time = int(f.read())
    else:
        last_update_time = 0

    current_time = time.time()
    if current_time - last_update_time > CACHE_UPDATE_INTERVAL:
        print('Updating package cache...')
        command = ['apt-get', 'update', '-y']
        subprocess.run(command)
        with open(dotfile_path, 'w') as f:
            f.write(str(int(current_time)))

def main():
    """
    Fonction principale du script. Analyse les arguments de la ligne de commande, charge le fichier YAML, installe les packages et affiche un message de succès.
    """
    parser = create_parser()
    args = parse_arguments(parser)
    check_root()

    # Vérifier que le fichier spécifié existe
    if not os.path.exists(args.file):
        if args.file == 'packages.yaml':
            # Si le fichier n'est pas spécifié par l'utilisateur, recherchez-le en utilisant find_file
            found_file_path = find_file(args.file)
            if found_file_path:
                args.file = found_file_path
            else:
                print("Fichier par défaut 'packages.yaml' non trouvé!")
                display_help(parser)
                sys.exit(1)
        else:
            print(f"Fichier '{args.file}' non trouvé!")
            sys.exit(1)

    data = load_yaml_file(args.file)
    if args.category not in data:
        print(f'Category "{args.category}" not found in the YAML file!')
        sys.exit(1)

    packages = get_packages_to_install(data, args.category, args.subcategories)
    check_last_update()
    install_packages(packages)
    print('Success!')
    sys.exit(0)

    
if __name__ == '__main__':
    main()
