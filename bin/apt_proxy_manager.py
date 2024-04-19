#!/usr/bin/env python3

import re
import sys

def modify_sources_list(action, proxy_url=None):
    # URL par défaut pour le proxy
    default_proxy_url = "http://172.25.253.25:3142"

    # Utiliser l'URL par défaut si aucune URL n'est fournie
    if proxy_url is None:
        proxy_url = default_proxy_url

    path = '/etc/apt/sources.list'
    try:
        with open(path, 'r') as file:
            lines = file.readlines()

        new_lines = []
        # Expression régulière ajustée pour conserver le chemin après le domaine
        pattern = re.compile(r'^deb (http://[^/]+)')
        
        for line in lines:
            match = pattern.match(line)
            if match:
                domain_url = match.group(1)  # extrait l'URL du domaine
                # Remplacement qui inclut maintenant le chemin après le domaine
                if action == "add" or action == "update":
                    new_line = line.replace(domain_url, f"{proxy_url}/{domain_url[7:]}")
                    new_lines.append(new_line)
                elif action == "remove":
                    new_line = line.replace(f"{proxy_url}/", "")
                    new_lines.append(new_line)
            else:
                new_lines.append(line)

        with open(path, 'w') as file:
            file.writelines(new_lines)
        print(f"Successfully completed {action} action.")
    except Exception as e:
        print(f"Failed to modify {path}: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python modify_sources.py <action> [<proxy_url>]")
        print("<action> can be 'add', 'update', or 'remove'")
        print("<proxy_url> is optional and will default to 'http://default-server:3142' if not provided")
    else:
        action = sys.argv[1]
        proxy_url = sys.argv[2] if len(sys.argv) > 2 else None
        modify_sources_list(action, proxy_url)
