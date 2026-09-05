# install_command-not-found.sh

> Script : [`install_command-not-found.sh`](../install_command-not-found.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install_command-not-found.sh` installe le paquet `command-not-found` sur une VM Debian et construit sa base de suggestions — celle qui propose `apt install paquet-x` quand une commande tapée dans le shell n'existe pas. Il installe le paquet s'il est absent, rafraîchit le cache APT (`apt-get update`), puis reconstruit la base via `/usr/sbin/update-command-not-found`. Cette reconstruction est relancée à **chaque exécution**, y compris quand le paquet était déjà présent : c'est elle qui tient la liste de suggestions à jour après l'ajout d'un dépôt ou de nouveaux paquets. Le script ne configure ni `sudo`, ni `apt-file`, ni aucun autre des paquets installés par `install_tp.sh` : il ne s'occupe que de `command-not-found`. Il est appelé par `install_tp.sh`, mais peut aussi tourner seul, par exemple après un ajout de dépôt APT.

---

## Section utilisateur

### Description

Sans ce paquet, taper une commande absente du `PATH` renvoie un simple « command not found » de bash. Avec lui, un shell interactif interroge une base locale et suggère le paquet APT qui fournit la commande (« La commande « xyz » n'a pas été trouvée, mais peut être installée avec : sudo apt install xyz »).

Le script fait deux choses, dans l'ordre :

1. **Installation** : `apt-get install -y command-not-found`, sautée si le paquet est déjà présent.
2. **Configuration** : `apt-get update` puis `update-command-not-found`, pour construire ou rafraîchir la base de suggestions à partir des index APT courants.

Il diffère des autres scripts `install_*` du dépôt en ce qu'il n'installe qu'un seul paquet ciblé, sans toucher au réseau, à sudo ou aux comptes utilisateurs — contrairement à `install_tp.sh` qui l'appelle au passage.

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| `sudo` | Le script se relance lui-même via sudo s'il n'est pas déjà root | `command -v sudo` |
| `apt-get` | Installation du paquet et rafraîchissement du cache | `command -v apt-get` |
| `/usr/sbin/update-command-not-found` | Fourni par le paquet une fois installé ; reconstruit la base | `test -x /usr/sbin/update-command-not-found` |

### Syntaxe

```
sudo ./install_command-not-found.sh [-h|--help]
```

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `-h`, `--help` | — | — | Affiche le bloc d'en-tête (NAME/SYNOPSIS/…) et quitte, sans demander de mot de passe ni toucher au système. |

### Exemples d'utilisation

```bash
# Installation et configuration, depuis la VM Debian
sudo ./install_command-not-found.sh
```

Sortie réelle :

```
===== 2026-09-05 10:00:00 | install_command-not-found.sh  | root@debian12 =====

=== Installation et configuration de command-not-found ===

[INFO]      Rafraîchissement du cache APT (apt-get update)...
[INFO]      Installation de command-not-found...
[OK]        command-not-found installé.
[INFO]      Reconstruction de la base command-not-found...
[OK]        Base command-not-found à jour.

command-not-found installé et configuré.

  Journal      : /var/log/tp-install/install_command-not-found.log

  Test rapide  : tapez une commande inexistante dans un nouveau shell
```

```bash
# Relance après un paquet déjà installé : seule la base est reconstruite
sudo ./install_command-not-found.sh
```

```
[INFO]      Rafraîchissement du cache APT (apt-get update)...
[INFO]      command-not-found déjà installé (version 23.04.0).
[INFO]      Reconstruction de la base command-not-found...
[OK]        Base command-not-found à jour.
```

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès. |
| 1 | Option inconnue, `apt-get` introuvable, échec de « apt-get update », échec de l'installation du paquet, ou échec de la reconstruction de la base. |

## Section développeur

### Architecture interne

`main()` enchaîne, dans l'ordre :

1. `setup_logging` — bascule stdout/stderr vers un tee (écran + `/var/log/tp-install/install_command-not-found.log`) et pose le `trap cleanup EXIT`.
2. `check_prerequisites` — présence de `apt-get`.
3. `refresh_apt_cache` — `apt-get update -q`, nécessaire aussi bien pour installer le paquet que pour que `update-command-not-found` dispose d'index à jour.
4. `install_package` — installe `command-not-found` si `dpkg -s` ne le trouve pas déjà.
5. `rebuild_database` — appelle `/usr/sbin/update-command-not-found` s'il est exécutable, avertit sinon sans faire échouer le script.
6. `print_summary` — rappel du journal et invitation à tester.

Le parsing des arguments et l'élévation de privilèges (auto-relance sudo, Tier 1) ont lieu **avant**, en haut du fichier, hors de toute fonction.

### Détail des choix techniques

- **`refresh_apt_cache` est inconditionnel** : contrairement à `install_network-manager.sh`, qui ne fait `apt-get update` que si le paquet est absent, ce script le fait à chaque exécution. La base de suggestions dépend des index APT (nouveaux dépôts, nouveaux paquets) et pas seulement de la présence du paquet lui-même ; sauter la mise à jour rendrait la reconstruction de la base inutile la plupart du temps.
- **`rebuild_database` tourne à chaque exécution, même si le paquet était déjà installé** : c'est la partie « configuration » demandée, distincte de l'installation. Un paquet déjà présent n'implique pas une base à jour.
- **Absence d'échec dur si `update-command-not-found` est introuvable** : ce binaire n'existe pas sur toutes les variantes du paquet (Ubuntu récent utilise `/usr/lib/cnf-update-db`, appelé automatiquement par un hook APT). Le script avertit plutôt que d'échouer, pour rester utilisable si le paquet évolue.
- **Pas d'option `--force`** : contrairement à `install_eth0.sh` ou `install_network-manager.sh`, il n'y a ici aucune étape coûteuse ou destructrice à sauter par défaut — `apt-get install` sur un paquet déjà présent ne fait rien, et reconstruire la base est sans risque. Une option qui n'aurait rien à forcer aurait été de la complexité inutile.
- **Plage d'aide délimitée par une expression régulière** (`sed -n '2,/^# =\{10,\}$/p'`), comme dans `install_eth0.sh` et `install_network-manager.sh` : rallonger l'en-tête ne tronque pas l'aide silencieusement.
- **Un seul `trap EXIT`** : `cleanup` restaure uniquement les descripteurs, ce script n'ayant pas de fichier temporaire à nettoyer.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4 | Substitution de processus `>()` de `setup_logging` |
| `sudo` | — | Auto-relance Tier 1 |
| `apt-get`, `dpkg` | — | Installation et détection du paquet |
| `/usr/sbin/update-command-not-found` (fourni par `command-not-found`) | — | Reconstruction de la base de suggestions |

### Points d'extension

**Basculer sur `/usr/lib/cnf-update-db`** si une future version Debian remplace `update-command-not-found` par ce binaire (déjà le cas sur Ubuntu récent) : ajouter une seconde constante et choisir le premier binaire exécutable trouvé plutôt que d'en coder un seul en dur.

```bash
readonly UPDATE_BINS=("/usr/sbin/update-command-not-found" "/usr/lib/cnf-update-db")

rebuild_database() {
    local bin
    for bin in "${UPDATE_BINS[@]}"; do
        if [ -x "$bin" ]; then
            info "Reconstruction de la base command-not-found ($bin)..."
            "$bin" || die "Échec de $bin."
            success "Base command-not-found à jour."
            return 0
        fi
    done
    warn "Aucun binaire de reconstruction trouvé parmi : ${UPDATE_BINS[*]}"
}
```

### Notes de maintenance

- Le nom exact et l'emplacement du binaire de reconstruction ont varié selon les versions du paquet (`update-command-not-found` sur Debian, `cnf-update-db` + hook APT sur Ubuntu récent). Si le script est déployé sur une machine où `/usr/sbin/update-command-not-found` n'existe plus, il se contente d'avertir : vérifier alors le contenu réel du paquet (`dpkg -L command-not-found`) avant de conclure à une régression.
- Le script fait un `apt-get update` complet à chaque exécution, ce qui peut ralentir un enchaînement scripté si le cache vient d'être rafraîchi juste avant (c'est le cas dans `install_tp.sh`, qui installe d'autres paquets avant d'appeler ce script). Ce n'est pas actuellement optimisé, le coût restant faible.
