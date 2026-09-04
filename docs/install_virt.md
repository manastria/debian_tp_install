# install_virt.sh

> Script : [`install_virt.sh`](../install_virt.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install_virt.sh` installe les outils invité correspondant à l'hyperviseur sur lequel tourne la VM, sans qu'on ait à le préciser : il interroge `systemd-detect-virt` puis, sur VirtualBox, délègue à `install_guest_additions.sh`, et sur VMware installe `open-vm-tools`. Sur une machine physique ou un hyperviseur inconnu il n'installe rien et sort en succès, ce qui permet de l'enchaîner sans condition dans `tp_cli.sh`. Il ne fait **que** les outils invité : ni pilote graphique tiers, ni configuration réseau, ni paquets de TP. La seule option courante est `--desktop`, qui ajoute `open-vm-tools-desktop` sur une VM VMware graphique (presse-papier partagé, redimensionnement de l'écran). Relancé une deuxième fois, il constate que les paquets sont déjà installés et ne refait pas d'`apt-get update`.

---

## Section utilisateur

### Description

Chaque hyperviseur a ses outils invité : sans eux, la VM fonctionne mais on perd le redimensionnement de l'écran, le presse-papier partagé, les dossiers partagés et la synchronisation de l'heure. Le script évite d'avoir à s'en souvenir : il détecte l'hyperviseur et fait ce qu'il faut.

| Détection `systemd-detect-virt` | Action |
|---|---|
| `oracle` (VirtualBox) | Délègue à `install_guest_additions.sh`, dans le même répertoire |
| `vmware` | Installe `open-vm-tools`, plus `open-vm-tools-desktop` avec `--desktop` |
| `none` (machine physique) | Ne fait rien, sort en succès |
| autre (`kvm`, `qemu`, `lxc`…) | Avertit et ne fait rien, sort en succès |

Le script ne prend pas en charge les Guest Additions lui-même : sur VirtualBox il appelle `install_guest_additions.sh`, qui télécharge l'ISO et gère le compilateur de modules. C'est la raison pour laquelle les deux scripts vivent côte à côte.

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| `sudo` | Le script se relance lui-même via sudo s'il n'est pas déjà root | `command -v sudo` |
| `systemd-detect-virt` (paquet `systemd`) | Détecte l'hyperviseur | `systemd-detect-virt` |
| `apt-get`, `dpkg` | Installation et test de présence des paquets VMware | `command -v apt-get` |
| `install_guest_additions.sh` | Requis uniquement sur VirtualBox ; doit être dans le même répertoire | `ls install_guest_additions.sh` |

### Syntaxe

```
sudo ./install_virt.sh [-g|--desktop] [-h|--help]
```

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `-g`, `--desktop` | — | désactivé | Ajoute `open-vm-tools-desktop` sur une VM VMware. Sans effet sur VirtualBox et sur machine physique. |
| `-h`, `--help` | — | — | Affiche le bloc d'en-tête (NAME/SYNOPSIS/…) et quitte, sans demander de mot de passe ni toucher au système. |

### Exemples d'utilisation

```bash
# Cas courant : la VM se débrouille avec ce qu'elle détecte
sudo ./install_virt.sh
```

Sortie réelle sur une VM VMware, avec les extras graphiques :

```
===== 2026-09-04 20:36:14 | install_virt.sh --desktop | root@debian12 =====

=== Outils invité de virtualisation ===

[INFO]      Hyperviseur détecté : vmware
[INFO]      Installation de : open-vm-tools open-vm-tools-desktop
Atteint :1 http://deb.debian.org/debian bookworm InRelease
Les NOUVEAUX paquets suivants seront installés :
  open-vm-tools open-vm-tools-desktop
Paramétrage de open-vm-tools ...
[OK]        Installé : open-vm-tools open-vm-tools-desktop

Terminé.
```

Sur une machine physique, ou sur un hyperviseur non pris en charge :

```
[INFO]      Hyperviseur détecté : none
[INFO]      Machine physique : aucun outil invité à installer.

Terminé.
```

```
[INFO]      Hyperviseur détecté : kvm
[ATTENTION] Hyperviseur « kvm » non pris en charge : rien à installer.

Terminé.
```

```bash
# Vérifier après coup ce que le script a vu, et ce qui tourne
systemd-detect-virt
systemctl status open-vm-tools     # VMware
lsmod | grep vboxguest             # VirtualBox
```

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès, hyperviseur non pris en charge, ou machine physique (rien à faire). |
| 1 | Option inconnue, `systemd-detect-virt` absent, `install_guest_additions.sh` introuvable ou non exécutable, ou échec de `apt-get`. |

## Section développeur

### Architecture interne

`main()` enchaîne, dans l'ordre :

1. `setup_logging` — bascule stdout/stderr vers un tee (écran + `/var/log/tp-install/install_virt.log`) et pose le `trap cleanup EXIT`.
2. `detect_hypervisor` — appelle `systemd-detect-virt`.
3. Un `case` sur le résultat : `install_virtualbox_tools`, `install_vmware_tools`, ou simple message.

`install_packages` est l'utilitaire commun : il filtre les paquets déjà présents avec `dpkg -s`, et ne lance `apt-get update` que s'il reste quelque chose à installer.

Le parsing des arguments et l'élévation de privilèges (auto-relance sudo, Tier 1) ont lieu **avant**, en haut du fichier, hors de toute fonction.

### Détail des choix techniques

- **Le boilerplate BASH3 (b3bp) a été retiré** : l'ancienne version sourçait `main.sh` (452 lignes) et `custom.sh` pour n'utiliser au bout du compte qu'un `case` sur `systemd-detect-virt` et deux appels à `aptitude`. Les 584 lignes de l'ensemble sont devenues un script autonome. `main.sh` n'ayant plus aucun utilisateur, il a été supprimé du dépôt en même temps.
- **`systemd-detect-virt || true`** : la commande sort en code 1 quand elle ne détecte aucune virtualisation, tout en affichant `none`. Sans le `|| true`, `set -e` interromprait le script sur une machine physique — cas parfaitement normal, puisque `tp_cli.sh` l'enchaîne sans condition.
- **Chemin absolu pour `install_guest_additions.sh`** : l'ancienne version appelait `./install_guest_additions.sh`, ce qui échouait dès qu'on ne lançait pas le script depuis le répertoire du dépôt. Le chemin est maintenant résolu à partir de `readlink -f "$0"`, ce qui survit à l'auto-relance sudo comme à un appel par chemin absolu.
- **`apt-get` et non `aptitude`** : `aptitude` n'est pas installé par défaut sur Debian 12, l'ancienne version échouait donc sur une netinst fraîche.
- **`apt-get update` conditionnel** : `install_packages` ne rafraîchit les index que s'il reste effectivement un paquet à installer. Sur une VM déjà équipée, le script ne fait plus aucun accès réseau.
- **Un hyperviseur inconnu n'est pas une erreur** : le script avertit et sort en 0. C'est délibéré — `tp_cli.sh` l'appelle sans garde, et une VM KVM ou un conteneur ne doit pas faire échouer toute la chaîne d'installation.
- **Plage d'aide délimitée par une expression régulière** (`sed -n '2,/^# =\{10,\}$/p'`) plutôt que par des numéros de ligne : rallonger l'en-tête ne tronque plus l'aide.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4 | Substitution de processus `>()` de `setup_logging`, tableaux |
| `sudo` | — | Auto-relance Tier 1 |
| `systemd-detect-virt` (systemd ≥ 197) | — | Détection de l'hyperviseur |
| `apt-get`, `dpkg` | — | Installation et test de présence des paquets |

### Points d'extension

**Prendre en charge KVM/QEMU**, ce qui est le cas non couvert le plus probable — une seule branche à ajouter dans le `case` de `main()` :

```bash
        kvm|qemu)
            install_packages qemu-guest-agent
            ;;
```

**Prendre en charge Hyper-V** de la même façon, avec `linux-image-cloud-amd64` ou les paquets `hyperv-daemons` selon la distribution.

**Ajouter les extras graphiques VirtualBox** : ils sont gérés par `install_guest_additions.sh`, pas ici. L'option `--desktop` n'est transmise à personne sur VirtualBox — c'est à `install_virtualbox_tools` qu'il faudrait la passer si `install_guest_additions.sh` acquérait une option équivalente.

### Notes de maintenance

- Le script délègue entièrement VirtualBox à `install_guest_additions.sh`, qui cible XUbuntu d'après son propre en-tête. Sur une VM Debian CLI, l'alternative « paquets Debian » (`virtualbox-guest-utils`, sans X) n'est pas proposée : à ajouter dans `install_virtualbox_tools` si le besoin se présente.
- `install_guest_additions.sh` se relance avec `exec sudo -E`, motif que `CLAUDE.md` range parmi les motifs interdits. Comme `install_virt.sh` l'appelle en étant déjà root, la branche `-E` n'est pas empruntée dans ce chemin — mais elle reste à corriger le jour où ce script sera repris.
- `--desktop` n'a d'effet que sur VMware. Le passer sur une VM VirtualBox ne provoque ni erreur ni avertissement : le script l'ignore silencieusement.
- La trace `/var/log/tp-install/install_virt.log` est ouverte en ajout. Prévoir le fichier logrotate décrit dans `CLAUDE.md` si le script est relancé en boucle.
