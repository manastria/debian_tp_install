# prepare-ova-export.sh

> Script : [`prepare-ova-export.sh`](../prepare-ova-export.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`prepare-ova-export.sh` prépare une VM Debian/Ubuntu à l'export en `.ova` : il purge les caches APT, les journaux, les fichiers temporaires et les historiques shell de tous les utilisateurs, efface les identifiants qui doivent être uniques par clone (`machine-id`, baux DHCP), arme la réinitialisation du nom d'hôte et des clés SSH au premier démarrage, remplit l'espace libre de zéros pour que l'OVA compresse bien, puis éteint la VM. Il n'installe **pas** lui-même le mécanisme de réinitialisation : il arme le relais partagé du dépôt et, s'il manque, tente de l'installer en appelant `make_rclocal.sh` — sans ce relais il conserve délibérément les clés SSH, plutôt que de produire un clone injoignable. Comme `clean_system.sh`, il doit être **sourcé** depuis un shell root (le script refuse de s'exécuter directement), mais en plus complet : cache APT, logs, zerofill et extinction automatique inclus. Les options utiles sont `--dry-run` pour voir ce qui serait fait, et `--no-zerofill` quand on est pressé, le zerofill étant de loin l'étape la plus longue.

---

## Section utilisateur

### Description

Un template exporté en OVA doit être générique : deux VM issues du même fichier ne doivent partager ni nom d'hôte, ni clés d'hôte SSH, ni `machine-id`, et le fichier doit être aussi petit que possible. Le script traite les deux problèmes en six étapes :

| Étape | Contenu |
|---|---|
| 1/6 | Cache APT, paquets orphelins, listes de dépôts |
| 2/6 | Journaux systemd et `/var/log`, `/tmp`, caches utilisateurs, core dumps |
| 3/6 | Historiques bash et zsh de **tous** les utilisateurs |
| 4/6 | `machine-id`, baux DHCP, règles udev réseau |
| 5/6 | Armement de la réinitialisation au premier démarrage (nom d'hôte + clés SSH) |
| 6/6 | Zerofill de l'espace libre |

Puis il affiche la marche à suivre pour l'export et **éteint la VM** au bout de dix secondes.

**Il ne possède pas le mécanisme de réinitialisation** : celui-ci est installé par `make_rclocal.sh` (voir [sa page](make_rclocal.md)) et se compose de `/etc/rc.local`, `rc-local.service` et `ssh-regen-keys.service`. `prepare-ova-export.sh` se contente de le vérifier et de l'armer en créant `/etc/do_first_boot` — exactement comme `clean_system.sh`. S'il ne trouve pas le relais, il l'installe via `make_rclocal.sh` situé à côté de lui ; à défaut, il **conserve les clés SSH** et le signale.

Deux voisins à ne pas confondre :

| Script | Nettoyage | Zerofill | Extinction | Mode d'appel |
|---|---|---|---|---|
| `prepare-ova-export.sh` | complet | oui | oui, automatique | **sourcé** obligatoirement |
| `clean_system.sh` | léger par défaut, complet sur demande | non | non | **sourcé** obligatoirement |

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| Shell root | Le script ne se relance pas via sudo et refuse de s'exécuter directement : il doit être sourcé depuis un shell déjà root | `sudo -i` puis `id -u` |
| Debian ou Ubuntu | Vérifié dans `/etc/os-release` ; un autre système déclenche une demande de confirmation | `grep -iE 'debian\|ubuntu' /etc/os-release` |
| `make_rclocal.sh` et `rc.local` | Dans le même répertoire, pour installer le relais s'il manque | `ls make_rclocal.sh rc.local` |
| Espace disque libre | Le zerofill remplit tout l'espace disponible avant de le libérer | `df -h /` |

### Syntaxe

```
sudo -i
source /chemin/vers/prepare-ova-export.sh [OPTIONS]
```

Le script refuse de s'exécuter directement (`./prepare-ova-export.sh` ou `bash prepare-ova-export.sh`) : il doit être sourcé, sans quoi il affiche une erreur et quitte avec le code 1.

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `--no-ssh-regen` | — | régénération active | Conserve les clés d'hôte SSH. Tous les clones partageront alors les mêmes. |
| `--no-random-hostname` | — | nom aléatoire actif | N'arme pas `/etc/do_first_boot` : le nom d'hôte du template est conservé. |
| `--no-zerofill` | — | zerofill actif | Saute le remplissage de zéros. Bien plus rapide, mais l'OVA sera plus gros. |
| `--dry-run` | — | désactivé | Affiche toutes les actions sans en exécuter aucune, sans confirmation et **sans éteindre**. |
| `-h`, `--help` | — | — | Affiche l'en-tête du script et quitte. |

En fin d'exécution le script fait `unset HISTFILE`, ce qui empêche le shell appelant d'écrire son historique à l'extinction — y compris la commande `source` elle-même.

### Exemples d'utilisation

```bash
# Voir ce qui serait fait, sans rien toucher ni éteindre
sudo -i
source /chemin/vers/prepare-ova-export.sh --dry-run
```

Sortie réelle (extrait) :

```
  ╔═══════════════════════════════════════════════════╗
  ║   Préparation VM pour export OVA (labo étudiant) ║
  ╚═══════════════════════════════════════════════════╝

  SSH regen ......... oui
  Random hostname ... oui
  Zerofill .......... oui
  Dry-run ........... oui

══════════════════════════════════════════════
  4/6 — Identifiants réseau
══════════════════════════════════════════════
  ⏭ Réinitialisation de machine-id (sera régénéré au boot) (dry-run)
  ⏭ Suppression des baux DHCP (dry-run)
  ⏭ Suppression des règles udev persistantes (interfaces réseau) (dry-run)

══════════════════════════════════════════════
  5/6 — Réinitialisation au premier démarrage
══════════════════════════════════════════════
  ⏭ Installation du relais via make_rclocal.sh (dry-run)
  ⏭ Suppression des clés d'hôte SSH (régénérées par ssh-regen-keys.service) (dry-run)
  ⏭ Armement de /etc/do_first_boot (hostname vm-XXXXXXXX au prochain démarrage) (dry-run)

══════════════════════════════════════════════
  6/6 — Zerofill (optimisation compression)
══════════════════════════════════════════════
  ⏭ Zerofill (dry-run)
```

Quand le relais est absent et que `make_rclocal.sh` est introuvable, l'étape 5 protège la VM :

```
  ! Relais de réinitialisation indisponible (make_rclocal.sh introuvable ?)
  ! Clés d'hôte SSH CONSERVÉES : aucune régénération garantie.
  !   -> lancez make_rclocal.sh sur cette VM, puis relancez ce script.
```

```bash
# Préparation réelle, sans trace dans l'historique (la VM s'éteint à la fin)
sudo -i
source /chemin/vers/prepare-ova-export.sh

# Variante rapide, sans zerofill
source /chemin/vers/prepare-ova-export.sh --no-zerofill
```

```bash
# Depuis l'hôte, une fois la VM éteinte
VBoxManage export <nom-vm> -o template.ova
xz -9 template.ova        # optionnel, compression supplémentaire
```

Vérifications au premier démarrage d'un clone :

```bash
hostnamectl                              # doit afficher vm-XXXXXXXX
cat /var/log/tp-install/first-boot.log
ls -l /etc/ssh/ssh_host_*                # clés recréées, datées du jour
systemctl status ssh-regen-keys.service
```

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès (en `--dry-run`, ou après extinction demandée), ou annulation à la confirmation. |
| 1 | Script exécuté au lieu d'être sourcé, option inconnue, ou lancé sans être root. |

Le script s'exécute sous `set -euo pipefail` : une commande non protégée qui échoue interrompt l'ensemble. La plupart des étapes destructrices sont suffixées de `|| true`, précisément pour qu'un fichier déjà absent n'arrête pas la préparation.

## Section développeur

### Architecture interne

Le script est linéaire, pas organisé en `main()` : il est prévu pour être **sourcé**, et un `main "$@"` compliquerait la propagation de `unset HISTFILE` au shell appelant.

1. Sauvegarde des options du shell appelant (`set +o`), `set -euo pipefail`, `trap ... RETURN` pour les restaurer à la sortie.
2. Garde-fou « doit être sourcé » (`BASH_SOURCE[0]` vs `$0`), résolution de `SCRIPT_DIR` depuis `BASH_SOURCE`.
3. Parsing des options (via `return`, jamais `exit`, pour ne pas tuer le shell appelant), définition des helpers `log_*` et `run`.
4. Trois fonctions dédiées au relais : `first_boot_relay_ready`, `ensure_first_boot_relay`, `remove_legacy_hostname_mechanism`.
5. Garde root, garde distribution, résumé des options, confirmation.
6. Les six sections, dans l'ordre.
7. Résumé, `unset HISTFILE`, `shutdown -h now` après dix secondes.

`run "description" "commande"` centralise le mode `--dry-run` : en dry-run il affiche la description et n'évalue rien.

### Détail des choix techniques

- **Le mécanisme de réinitialisation a été sorti du script** (septembre 2026). Il écrivait auparavant lui-même `/usr/local/bin/set-random-hostname.sh` et `random-hostname.service`, avec une sentinelle `/etc/hostname-initialized` et un nom `labo-XXXX`, alors que `rc.local` + `make_rclocal.sh` couvraient déjà le même besoin avec un nom `vm-XXXXXXXX`. Une VM ayant reçu les deux se retrouvait avec deux générateurs de nom d'hôte au même démarrage, dans un ordre non garanti. Le script arme désormais le relais partagé, comme `clean_system.sh`.
- **`first_boot_relay_ready` duplique volontairement `clean_system_rc_local_ready`** de `clean_system.sh`, à l'identique. Factoriser les deux imposerait un fichier de fonctions commun à sourcer, alors que `clean_system.sh` est justement conçu pour être autonome ; le contrat étant de trois lignes, la duplication assumée coûte moins cher que le couplage.
- **Les clés SSH ne sont supprimées que si leur régénération est garantie** : sans relais, un clone démarrerait sans clé d'hôte, donc injoignable en SSH. Un template dont les clones partagent leurs clés est un défaut ; un template dont les clones sont inaccessibles est une panne. Le script préfère le défaut et le dit.
- **`remove_legacy_hostname_mechanism` s'exécute avant l'armement** : sur une VM préparée par une version antérieure, l'ancien service est retiré au passage. Sans cela, la coexistence ne se verrait qu'au premier démarrage du clone.
- **`SCRIPT_DIR` est résolu depuis `BASH_SOURCE` et non depuis `$0`** : le script est prévu pour être sourcé, cas où `$0` vaut le nom du shell appelant et non le chemin du fichier. Même raison pour l'option `-h`/`--help`, qui relit son propre en-tête via `"${BASH_SOURCE[0]}"`.
- **Pas d'auto-relance sudo (Tier 1)**, contrairement au reste du dépôt : `exec sudo` sur un script sourcé remplacerait le shell root de l'utilisateur. Toutes les sorties anticipées (option invalide, refus de confirmation, garde root) utilisent `return`, jamais `exit`, pour ne pas tuer ce shell.
- **Le script refuse de s'exécuter directement** (`[[ "${BASH_SOURCE[0]}" == "${0}" ]]`) : ce garde-fou existe pour que `return` soit toujours valide plus loin — `return` hors d'une fonction ou d'un script sourcé est une erreur bash. Il a aussi pour effet de forcer la seule procédure qui garantit l'absence de trace dans l'historique.
- **Les options du shell appelant sont sauvegardées (`set +o`) puis restaurées via `trap ... RETURN`** : sans ça, un shell root sourçant ce script resterait en `set -euo pipefail` après coup, ce qui surprendrait s'il continue à s'en servir. `RETURN` se déclenche à la fin d'un script sourcé (fin normale ou `return` anticipé) ; il ne se déclenche jamais pour un script exécuté comme process séparé — situation de toute façon exclue par le garde-fou précédent.
- **`--dry-run` considère le relais comme disponible** même s'il ne l'est pas, afin d'afficher les deux étapes suivantes. L'intérêt du mode est de montrer le plan complet ; les avertissements réels n'apparaissent qu'en exécution.
- **Le zerofill passe par `dd` et non `fstrim` ou `zerofree`** : `dd if=/dev/zero` fonctionne sur tout système de fichiers monté en lecture-écriture, sans paquet supplémentaire ni démontage.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4 | `[[ ]]`, tableaux, `BASH_SOURCE` |
| `systemctl` (systemd) | — | Arrêt de rsyslog, vérification du relais, `journalctl --vacuum` |
| `apt-get` | — | Nettoyage APT |
| `dd`, `find`, `truncate` (coreutils, findutils) | — | Zerofill et purge des journaux |
| `make_rclocal.sh` + `rc.local` | — | Installation du relais quand il manque ; facultatif si le relais est déjà posé |

### Points d'extension

**Ajouter une étape de nettoyage** : suivre l'idiome `run`, qui gère seul le mode dry-run.

```bash
run "Suppression des dépôts de test" \
    "rm -f /etc/apt/sources.list.d/*-test.list 2>/dev/null || true"
```

**Ajouter une action au premier démarrage** (mot de passe par défaut, base de TP réinitialisée) : ce n'est pas ici qu'il faut la mettre, mais dans `rc.local`, avant la suppression du drapeau — voir la page `make_rclocal.md`, section *Points d'extension*.

**Changer le format du nom d'hôte** : la constante `HOSTNAME_PREFIX` est en tête de `rc.local`, pas ici. Ce script ne fait qu'armer le drapeau.

### Notes de maintenance

- Le script **éteint la VM** dix secondes après la fin, sauf en `--dry-run`. Un `Ctrl+C` pendant le compte à rebours annule l'extinction, mais pas le nettoyage, qui est déjà fait et irréversible.
- L'étape 2 supprime tous les `*.log` de `/var/log`, y compris `/var/log/tp-install/*.log`. C'est voulu — un template ne doit pas embarquer l'historique d'installation — mais cela signifie que la trace des scripts du dépôt disparaît à l'export. La trace du **premier démarrage** du clone, elle, est écrite après coup et survit.
- `run()` évalue ses arguments avec `eval`. Toute nouvelle étape doit donc être écrite en tenant compte de la double expansion : préférer les guillemets simples autour du corps de la commande, comme le font les étapes existantes multi-lignes.
- La suppression des règles udev `70-persistent-net.rules` fait double emploi avec `install_eth0.sh`, qui désactive le nommage prédictible par GRUB. Les deux peuvent coexister sans conflit, mais sur une VM passée par `install_eth0.sh` cette ligne n'a plus d'objet.
- Le script n'écrit pas de trace dans `/var/log/tp-install/` contrairement aux autres scripts du dépôt : ce serait contre-productif, puisque l'étape 2 vient précisément de vider ce répertoire. C'est l'exception assumée à la règle de `CLAUDE.md`.
