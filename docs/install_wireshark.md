# install_wireshark.sh

> Script : [`install_wireshark.sh`](../install_wireshark.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install_wireshark.sh` installe Wireshark sur une VM de TP et autorise la capture de paquets sans `sudo` : c'est l'équivalent scripté de `sudo dpkg-reconfigure wireshark-common` avec la réponse « Oui », suivi de l'ajout du compte au groupe `wireshark`. Il crée ainsi le groupe `wireshark`, réserve `dumpcap` à ce groupe en lui donnant les capacités de capture, puis vérifie le tout par une vraie capture d'une seconde sous l'identité du compte. Lancé par un étudiant sur sa VM, sans option, il ajoute au groupe le compte qui l'a lancé ; depuis un shell root (`sudo -i`), pour préparer l'image, il exige le compte étudiant : `-u sysadmin` (répétable). Il ne lance pas Wireshark et ne règle aucune autre option du paquet. L'appartenance au groupe ne compte qu'à la prochaine ouverture de session.

---

## Section utilisateur

### Description

Par défaut, `apt install wireshark` répond « Non » à la question « Should non-superusers be able to capture packets? » : seul root peut capturer, et un étudiant doit alors lancer Wireshark avec `sudo`, ce qui fait tourner toute l'interface graphique en root. Le script répond « Oui » sans interaction, ce que recommande le paquet lui-même : seul le petit programme `dumpcap` reçoit des droits élevés, et seulement pour les membres du groupe `wireshark`.

Le script fait, dans l'ordre :

1. **Réponse debconf** : enregistre `wireshark-common/install-setuid = true`.
2. **Installation** : `wireshark` (et `libcap2-bin` si `setcap` manque), sautée si déjà présents.
3. **Configuration** : `dpkg-reconfigure -f noninteractive wireshark-common`, à chaque exécution, pour appliquer la réponse même si le paquet avait été installé avec « Non ».
4. **Comptes** : `usermod -aG wireshark` pour chaque compte.
5. **Vérification** : capacités de `dumpcap`, puis capture d'une seconde sur `lo` sous l'identité de chaque compte.

Il sert à préparer l'image distribuée aux étudiants, avant `prepare-ova-export.sh`. Il ne touche ni à `tcpdump` (qui reste réservé à root, via `sudo`), ni aux préférences de Wireshark.

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| `sudo` | Le script se relance lui-même via sudo s'il n'est pas déjà root | `command -v sudo` |
| `apt-get`, `debconf-set-selections`, `dpkg-reconfigure` | Installation et réponse à la question du paquet | `command -v debconf-set-selections` |
| `runuser` (util-linux) | Capture d'essai sous l'identité d'un compte | `command -v runuser` |
| Accès aux dépôts APT | Seulement si Wireshark n'est pas encore installé | `apt-get update` |

### Syntaxe

```
./install_wireshark.sh [-u|--user NOM]... [-h|--help]
```

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `-u`, `--user` | nom de compte | le compte qui a lancé le script | Compte à ajouter au groupe `wireshark`. Répétable. **Obligatoire depuis un shell root** (`sudo -i`, `su`) : sans lui, le script s'arrête plutôt que d'ajouter le compte qui a ouvert ce shell. Le script s'arrête aussi si le compte n'existe pas. |
| `-h`, `--help` | — | — | Affiche le bloc d'en-tête et quitte, sans demander de mot de passe. |

### Exemples d'utilisation

```bash
# Étudiant, sur sa propre VM : s'ajoute lui-même au groupe
./install_wireshark.sh

# Enseignant, pour préparer l'image, depuis un shell root
sudo -i
./install_wireshark.sh -u sysadmin

# Depuis un shell root, sans -u : arrêt, rien n'est modifié
./install_wireshark.sh
# [ERREUR]    Lancé depuis un shell root : préciser le compte étudiant avec -u NOM (ex. -u sysadmin).

# Plusieurs comptes
./install_wireshark.sh -u sysadmin -u profadmin

# Contrôle, après une nouvelle ouverture de session
getent group wireshark
getcap /usr/bin/dumpcap
```

Sortie attendue (pas encore relevée sur une VM, à remplacer par une sortie réelle) :

```
===== 2026-11-02 21:30:00 | install_wireshark.sh  | root@sysadmin-VirtualBox =====

=== Installation de Wireshark (capture sans root) ===

[INFO]      Compte(s) à ajouter au groupe wireshark : sysadmin (compte qui a lancé le script)
[INFO]      Réponse debconf : wireshark-common/install-setuid = true
[INFO]      wireshark déjà installé (version 4.6.4-1).
[INFO]      Reconfiguration de wireshark-common...
[OK]        Groupe wireshark présent ; dumpcap : -rwxr-xr-- root:wireshark
[OK]        sysadmin ajouté au groupe wireshark.
[OK]        Capacités de dumpcap : cap_net_admin,cap_net_raw=eip
[OK]        Capture d'essai réussie sous l'identité de sysadmin.

Wireshark installé, capture autorisée au groupe wireshark.

  Comptes      : sysadmin
  Journal      : /var/log/tp-install/install_wireshark.log

  Le groupe ne compte qu'à la prochaine ouverture de session :
  se déconnecter puis se reconnecter (ou redémarrer la VM).
```

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès. |
| 1 | Option inconnue, shell root sans `-u`, compte inexistant, outil manquant, échec d'`apt-get`, de `debconf-set-selections` ou de `dpkg-reconfigure`, groupe non créé, ou capture d'essai impossible. |

## Section développeur

### Architecture interne

Avant `main()`, hors fonction : parsing des options (dans `USERS`), auto-relance Tier 1 avec les arguments d'origine (`ORIG_ARGS`), puis choix du compte par défaut, ou arrêt si le script tourne depuis un shell root sans `-u`.

`main()` enchaîne :

1. `setup_logging` — tee vers `/var/log/tp-install/install_wireshark.log`, `trap cleanup EXIT`.
2. `check_prerequisites` — outils présents, comptes existants.
3. `preseed_debconf` — `debconf-set-selections`.
4. `install_packages` — `wireshark` et `libcap2-bin` si absents.
5. `configure_dumpcap` — avertit d'un `dpkg-statoverride`, lance `dpkg-reconfigure`, contrôle le groupe.
6. `add_users` — `usermod -aG wireshark`.
7. `verify_capture` — capacités de `dumpcap`, puis capture d'essai par compte.
8. `print_summary`.

### Détail des choix techniques

- **Réponse debconf puis `dpkg-reconfigure`, plutôt que `setcap` à la main** : le `postinst` de `wireshark-common` crée le groupe, change le propriétaire et les droits de `dumpcap` (`root:wireshark`, `0754`) puis pose `cap_net_raw,cap_net_admin=eip`, avec un repli setuid si `setcap` échoue. Refaire ces étapes à la main dupliquerait sa logique et serait défait à la prochaine mise à jour du paquet, qui relit la réponse debconf.
- **`dpkg-reconfigure` à chaque exécution** : `debconf-set-selections` seul ne suffit pas sur une image où le paquet est déjà installé avec « Non » ; c'est la reconfiguration qui relance le `postinst`.
- **Droits `0754` sur `dumpcap`** : les autres comptes ne peuvent même pas l'exécuter. C'est ce qui rend les capacités sans danger pour eux, et pourquoi l'ajout au groupe est indispensable.
- **`libcap2-bin`** : sans `setcap`, le `postinst` rend `dumpcap` setuid root, solution que le paquet présente comme moins sûre.
- **Vérification par une vraie capture, avec `runuser`** : `getcap` ne prouve pas que le compte peut capturer. `runuser -u` recharge les groupes depuis `/etc/group`, donc l'ajout fait par le script compte déjà, alors que la session graphique en cours ne le verra qu'après reconnexion. Le dossier de sortie est créé au nom du compte dans un `mktemp -d` en `0711`.
- **`ORIG_ARGS`** : le parsing consomme les arguments avec `shift` ; sans copie, l'auto-relance sudo les perdrait.
- **Compte par défaut : `SUDO_USER` seulement si `SUDO_COMMAND` contient le nom du script** : dans un shell ouvert par `sudo -i`, `SUDO_USER` vaut le compte qui a ouvert ce shell, en général celui de l'enseignant, et non le compte étudiant de l'image. `SUDO_COMMAND` distingue les cas : il contient le chemin du script quand sudo a lancé le script lui-même (auto-relance, `sudo ./install_wireshark.sh`, `sudo bash install_wireshark.sh`), et seulement le shell (`/bin/bash`) dans un shell root. Dans ce dernier cas, et sous `su` où `SUDO_USER` est vide, le script exige `-u` plutôt que de deviner.
- **Test d'appartenance au groupe sans pipe** : avec `set -o pipefail`, `id -nG | grep -q` peut échouer quand `grep` se ferme avant la fin de l'écriture (SIGPIPE).

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4.4 | `"${ORIG_ARGS[@]}"` vide sous `set -u` ; `>()` de `setup_logging` |
| `debconf-set-selections`, `dpkg-reconfigure` | — | Réponse à la question du paquet |
| `setcap`, `getcap` (`libcap2-bin`) | — | Capacités de `dumpcap` |
| `dumpcap` (`wireshark-common`) | — | Capture d'essai (`-a duration:1`) |
| `runuser` (util-linux) | — | Capture sous l'identité du compte |

### Points d'extension

**Ajouter tous les membres d'un groupe** (par exemple tous les comptes étudiants d'un poste partagé), plutôt que de les nommer un par un :

```bash
-g|--group)
  mapfile -t members < <(getent group "$2" | cut -d: -f4 | tr ',' '\n')
  USERS+=("${members[@]}"); shift 2 ;;
```

### Notes de maintenance

- Ubuntu 26.04, `wireshark-common` 4.6.4-1 : le `postinst` pose `cap_net_raw,cap_net_admin=eip`. Si `getcap` n'affiche qu'une partie des capacités, `cap_net_raw` suffit à capturer ; la capture d'essai tranche.
- Si un `dpkg-statoverride` existe sur `dumpcap`, le `postinst` ne change rien : le script l'affiche, il faut le retirer (`dpkg-statoverride --remove /usr/bin/dumpcap`) et relancer.
- Si le nom de la question debconf change dans une version future, `debconf-show wireshark-common` donne le nouveau nom.
