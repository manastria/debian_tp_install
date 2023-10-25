#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse
import os
import subprocess
import sys

# Adresse du proxy par défaut si le fichier ~/.proxyconfig n'existe pas
DEFAULT_PROXY = '172.16.0.1:3128'

# Fichier de configuration du proxy
PROXY_CONFIG_FILE = os.path.expanduser('~/.proxyconfig')

# Noms des applications supportées
SUPPORTED_APPS = ['git', 'apt', 'env']

def configure_proxy(apps, enable=True, proxy=None):
    """
    Configure le proxy pour les applications données dans 'apps'. Si 'enable' est True, configure le proxy
    avec l'adresse spécifiée dans 'proxy' (ou l'adresse de proxy par défaut si 'proxy' est None).
    Si 'enable' est False, désactive le proxy pour les applications spécifiées.

    Args:
        apps (list): Liste des applications pour lesquelles configurer le proxy ('git', 'apt' et/ou 'env').
        enable (bool): Active ou désactive le proxy (par défaut: True).
        proxy (str): Adresse du proxy à utiliser (par défaut: DEFAULT_PROXY).

    Raises:
        ValueError: Si une application spécifiée n'est pas prise en charge.
    """
    proxy = proxy or DEFAULT_PROXY
    for app in apps:
        if app == 'git':
            git_proxy_cmd = ['git', 'config', '--global']
            git_proxy_cmd.extend(['http.proxy', proxy])
            git_proxy_cmd.extend(['https.proxy', proxy])
            git_proxy_cmd.extend(['url."https://".insteadOf', 'git://'])
            subprocess.run(git_proxy_cmd)
        elif app == 'apt':
            apt_config_file = '/etc/apt/apt.conf.d/80proxy'
            if enable:
                with open(apt_config_file, 'w') as f:
                    f.write('Acquire::http::Proxy "http://{}/";\n'.format(proxy))
                    f.write('Acquire::https::Proxy "http://{}/";\n'.format(proxy))
            else:
                if os.path.exists(apt_config_file):
                    os.remove(apt_config_file)
        elif app == 'env':
            set_proxy_env(proxy)
        else:
            raise ValueError("L'application {} n'est pas prise en charge".format(app))


def show_proxy_status():
    """
    Affiche le statut de la configuration du proxy.
    """
    print('Git proxy:')
    subprocess.run(['git', 'config', '--global', '--get', 'http.proxy'])
    subprocess.run(['git', 'config', '--global', '--get', 'https.proxy'])
    print('Apt proxy:')
    if os.path.exists('/etc/apt/apt.conf.d/80proxy'):
        with open('/etc/apt/apt.conf.d/80proxy') as f:
            print(f.read())
    else:
        print('Not configured')
    print('Environment variables:')
    for var in ['http_proxy', 'https_proxy', 'HTTP_PROXY', 'HTTPS_PROXY']:
        print(var + '=' + os.environ.get(var, 'Not set'))
    print('no_proxy=' + os.environ.get('no_proxy', 'Not set'))

def parse_arguments(parser):
    """
    Parse les arguments de la ligne de commande.

    Args:
        parser (argparse.ArgumentParser): Objet ArgumentParser.

    Returns:
        Les arguments de la ligne de commande sous forme d'un objet 'Namespace'.
    """

    parser.add_argument('--all', action='store_true', help='Activer le proxy pour toutes les applications')
    parser.add_argument('--git', action='store_true', help='Activer le proxy pour git')
    parser.add_argument('--apt', action='store_true', help='Activer le proxy pour apt')
    parser.add_argument('--env', action='store_true', help='Activer le proxy pour les variables d\'environnement')
    parser.add_argument('--disable', action='store_true', help='Désactiver le proxy')
    parser.add_argument('--status', action='store_true', help='Afficher le statut de la configuration du proxy')
    parser.add_argument('--proxy', type=str, help='Adresse du proxy à utiliser')
    parser.add_argument('--bashrc', type=str, default='~/.bashrc', help='Fichier bashrc à modifier (défaut: ~/.bashrc)')
    parser.add_argument('--update-bashrc', action='store_true', help='Mettre à jour le fichier bashrc automatiquement')

    args = parser.parse_args()
    return args


def set_proxy_env(proxy, bashrc_file='~/.bashrc', update_bashrc=False):
    """
    Définit ou supprime les variables d'environnement pour le proxy.

    Args:
        proxy (str): Adresse du proxy à utiliser. Si None, supprime les variables d'environnement.
        bashrc_file (str): Chemin vers le fichier .bashrc ou .zshrc à modifier.
    """
    if proxy is None:
        os.environ.pop('http_proxy', None)
        os.environ.pop('https_proxy', None)
        os.environ.pop('HTTP_PROXY', None)
        os.environ.pop('HTTPS_PROXY', None)
        os.environ.pop('no_proxy', None)
    else:
        os.environ['http_proxy'] = 'http://' + proxy
        os.environ['https_proxy'] = 'http://' + proxy
        os.environ['HTTP_PROXY'] = 'http://' + proxy
        os.environ['HTTPS_PROXY'] = 'http://' + proxy
        os.environ['no_proxy'] = 'localhost,127.0.0.1'

    # Modifier le fichier .bashrc/.zshrc si nécessaire
    if update_bashrc:
        if os.path.exists(os.path.expanduser(bashrc_file)):
            with open(os.path.expanduser(bashrc_file)) as f:
                lines = f.readlines()
            with open(os.path.expanduser(bashrc_file), 'w') as f:
                for line in lines:
                    if not line.startswith('export http_proxy=') and not line.startswith('export https_proxy=') and not line.startswith('export HTTP_PROXY=') and not line.startswith('export HTTPS_PROXY=') and not line.startswith('export no_proxy='):
                        f.write(line)

            if proxy is not None:
                with open(os.path.expanduser(bashrc_file), 'a') as f:
                    f.write('\n# Proxy configuration\n')
                    f.write('export http_proxy="http://{}"\n'.format(proxy))
                    f.write('export https_proxy="http://{}"\n'.format(proxy))
                    f.write('export HTTP_PROXY="http://{}"\n'.format(proxy))
                    f.write('export HTTPS_PROXY="http://{}"\n'.format(proxy))
                    f.write('export no_proxy="localhost,127.0.0.1"\n')


def main():
    """
    Fonction principale.
    """
    parser = argparse.ArgumentParser(description='Script pour configurer le proxy.')
    args = parse_arguments(parser)

    if len(sys.argv)==1:
        parser.print_help(sys.stderr)
        sys.exit(1)

    # Vérifier que le fichier de configuration existe ou utiliser l'adresse par défaut ou l'adresse de l'utilisateur
    if args.proxy:
        proxy_config = 'git={}\napt={}\nenv={}\n'.format(args.proxy, args.proxy, args.proxy)
    elif os.path.exists(PROXY_CONFIG_FILE):
        with open(PROXY_CONFIG_FILE) as f:
            proxy_config = f.read()
    else:
        proxy_config = 'git={}\napt={}\nenv={}\n'.format(DEFAULT_PROXY, DEFAULT_PROXY, DEFAULT_PROXY)

    # Parser le fichier de configuration
    proxies = {}
    for line in proxy_config.splitlines():
        line = line.strip()
        if line and not line.startswith('#'):
            app, proxy = line.split('=')
            proxies[app] = proxy

    # Choisir les applications à configurer
    if args.all:
        apps = SUPPORTED_APPS
    else:
        apps = []
        if args.git:
            apps.append('git')
        if args.apt:
            apps.append('apt')
        if args.env:
            apps.append('env')

    # Configurer ou désactiver le proxy pour les applications sélectionnées
    if args.disable:
        configure_proxy(apps, enable=False)
        set_proxy_env(None, args.bashrc, args.update_bashrc)
    elif args.status:
        show_proxy_status()
    else:
        configure_proxy(apps, enable=True, proxy=args.proxy)
        proxy = proxies.get('env', DEFAULT_PROXY) if args.env else None
        set_proxy_env(proxy, args.bashrc, args.update_bashrc)


if __name__ == '__main__':
    main()
