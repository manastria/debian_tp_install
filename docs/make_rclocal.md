# make_rclocal.sh

> Scripts : [`make_rclocal.sh`](../make_rclocal.sh) et sa charge utile [`rc.local`](../rc.local)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`make_rclocal.sh` installe sur une VM le relais qui, au premier démarrage d'un clone, lui donne un nom d'hôte aléatoire `vm-XXXXXXXX` et de nouvelles clés d'hôte SSH. Il pose trois pièces : `/etc/rc.local` copié depuis le dépôt, l'unité `rc-local.service` qui l'exécute, et `ssh-regen-keys.service` qui régénère les clés avant le démarrage de `ssh.service`. Le relais reste **inerte** tant que le drapeau `/etc/do_first_boot` n'existe pas ; c'est ce drapeau, planté par `clean_system.sh`, par `prepare-ova-export.sh` ou par l'option `--arm`, qui déclenche la réinitialisation au démarrage suivant, une seule fois. Il ne nettoie ni les logs, ni l'historique, ni le cache APT, et n'éteint pas la VM — c'est le travail des deux scripts d'export, dont il n'est que le préalable obligatoire : sans lui, tous deux refusent de supprimer les clés SSH d'un template. Les deux options utiles sont `--arm`, à lancer juste avant d'éteindre une VM à cloner, et `--force`, pour réinstaller le relais après modification du `rc.local` du dépôt.

---

## Section utilisateur

### Description

Deux clones d'une même VM qui partagent leur nom d'hôte et leurs clés d'hôte SSH posent deux problèmes : ils sont indiscernables sur le réseau, et SSH signale une usurpation dès qu'on se connecte au second après le premier. La réinitialisation doit donc avoir lieu **au premier démarrage du clone**, pas au moment de l'export.

Le mécanisme tient en trois pièces :

| Pièce | Rôle |
|---|---|
| `/etc/rc.local` | Charge utile exécutée à chaque démarrage. Sort immédiatement, sauf si le drapeau est présent. |
| `/etc/systemd/system/rc-local.service` | Unité systemd qui exécute `rc.local` après `network.target` et `dbus.service`. |
| `/etc/systemd/system/ssh-regen-keys.service` | Régénère les clés d'hôte SSH **avant** `ssh.service`, dès lors qu'elles sont absentes. Sans drapeau : sa condition est l'absence de la clé ed25519. |
| `/etc/do_first_boot` | Drapeau. Sa présence déclenche la réinitialisation du nom d'hôte ; il est supprimé une fois le travail fait. |

Au démarrage qui suit la pose du drapeau, `rc.local` génère un nom d'hôte `vm-XXXXXXXX`, met à jour la ligne `127.0.1.1` de `/etc/hosts`, régénère les clés d'hôte SSH avec `ssh-keygen -A`, redémarre le service SSH, puis supprime le drapeau. Toute la trace part dans `/var/log/tp-install/first-boot.log`.

**Répartition des rôles dans le dépôt** — un seul mécanisme, un seul installeur, deux armeurs :

```
INSTALLATION (une fois, à la construction du template)
  tp_cli.sh ──> make_rclocal.sh
                  ├── /etc/rc.local + rc-local.service     (nom d'hôte, sur drapeau)
                  └── ssh-regen-keys.service               (clés SSH, avant ssh.service)

ARMEMENT (avant clonage ou export) — personne ne réinstalle, tout le monde arme
  clean_system.sh        ──> vérifie le relais, puis touch /etc/do_first_boot
  prepare-ova-export.sh  ──> idem, plus son propre travail (APT, logs, zerofill, arrêt)
```

- `clean_system.sh` **dépend** de ce relais : avant de supprimer les clés d'hôte SSH d'un template, il vérifie que `/etc/rc.local` est exécutable, qu'il contient `do_first_boot` et que `rc-local.service` est activé. Sinon il conserve les clés et affiche « Lancez make_rclocal.sh ».
- `prepare-ova-export.sh` applique les mêmes vérifications, à ceci près qu'il tente d'abord d'installer le relais en appelant `make_rclocal.sh` s'il le trouve à côté de lui. Il embarquait auparavant son propre mécanisme (`random-hostname.service`, sentinelle `/etc/hostname-initialized`, nom d'hôte `labo-XXXX`) ; il le **retire** désormais des VM où il traîne encore, pour qu'aucune machine ne se retrouve avec deux générateurs de nom d'hôte au même démarrage.

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| `sudo` | Le script se relance lui-même via sudo s'il n'est pas déjà root | `command -v sudo` |
| `systemd` (`systemctl`) | Création et activation de `rc-local.service` | `command -v systemctl` |
| `rc.local` du dépôt | Charge utile copiée vers `/etc/rc.local` ; doit être à côté du script | `ls rc.local` |
| `hostnamectl`, `ssh-keygen` | Utilisés au **démarrage** par `rc.local` et par `ssh-regen-keys.service`, pas par ce script | `command -v hostnamectl` |

### Syntaxe

```
sudo ./make_rclocal.sh [--arm] [--force] [-h|--help]
```

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `--arm` | — | désactivé | Crée `/etc/do_first_boot` : la réinitialisation aura lieu au prochain démarrage. |
| `--force` | — | désactivé | Réinstalle `/etc/rc.local` et l'unité systemd même si tout est déjà en place et identique. |
| `-h`, `--help` | — | — | Affiche le bloc d'en-tête (NAME/SYNOPSIS/…) et quitte, sans demander de mot de passe ni toucher au système. |

### Exemples d'utilisation

```bash
# À la construction du template : poser le relais (une fois)
sudo ./make_rclocal.sh
```

Sortie réelle :

```
===== 2026-09-04 20:35:41 | make_rclocal.sh  | root@debian12 =====

=== Relais de réinitialisation au premier démarrage ===

[OK]        /etc/rc.local installé (exécutable).
[OK]        /etc/systemd/system/rc-local.service créé.
[OK]        rc-local.service activé au démarrage.
[OK]        ssh-regen-keys.service activé (régénération des clés avant ssh.service).
[OK]        Contrat attendu par clean_system.sh satisfait.

Relais de réinitialisation en place.

  Script au démarrage : /etc/rc.local
  Unité hostname      : /etc/systemd/system/rc-local.service
  Unité clés SSH      : /etc/systemd/system/ssh-regen-keys.service
  Journal de ce script: /var/log/tp-install/make_rclocal.log
  Journal du 1er boot : /var/log/tp-install/first-boot.log

  Le relais est inerte tant que /etc/do_first_boot n'existe pas.
  Pour armer : sudo ./make_rclocal.sh --arm   (ou clean_system.sh)
```

```bash
# Juste avant de cloner ou d'exporter : armer, puis éteindre
sudo ./make_rclocal.sh --arm
sudo shutdown -h now
```

```
[INFO]      rc.local et rc-local.service sont déjà en place et à jour.
[OK]        Contrat attendu par clean_system.sh satisfait.
[OK]        Drapeau /etc/do_first_boot planté.
[ATTENTION] Au prochain démarrage : nouveau nom d'hôte et nouvelles clés d'hôte SSH.
```

```bash
# Vérifier, après le premier démarrage du clone, que le relais a bien tourné
hostnamectl
cat /var/log/tp-install/first-boot.log
systemctl status rc-local.service
ls -l /etc/do_first_boot          # doit être absent : le drapeau est consommé
```

Trace attendue dans `/var/log/tp-install/first-boot.log` :

```
2026-09-04 20:36:00 | ===== Premier démarrage : réinitialisation =====
2026-09-04 20:36:00 | Nom d'hôte : vm-pa59t83s
2026-09-04 20:36:00 | /etc/hosts mis à jour.
ssh-keygen: generating new host keys: RSA ECDSA ED25519
2026-09-04 20:36:00 | Clés d'hôte SSH régénérées.
2026-09-04 20:36:00 | Réinitialisation terminée.
```

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès, ou relais déjà installé et à jour (rien à réinstaller). |
| 1 | Option inconnue, `rc.local` introuvable dans le dépôt, `systemctl` absent, échec de l'activation du service, ou contrat `clean_system.sh` non satisfait en fin d'exécution. |

`rc.local`, lui, sort en `0` à chaque démarrage normal, en `0` après une réinitialisation réussie, et en `1` si la génération du nom d'hôte échoue — le drapeau est alors conservé et une nouvelle tentative a lieu au démarrage suivant.

## Section développeur

### Architecture interne

`main()` de `make_rclocal.sh` enchaîne :

1. `setup_logging` — tee vers l'écran et `/var/log/tp-install/make_rclocal.log`, `trap cleanup EXIT`.
2. `check_prerequisites` — présence de `rc.local` dans le dépôt et de `systemctl`.
3. `is_already_installed` — six tests (fichier exécutable, identique à la source via `cmp`, les deux unités présentes et activées) ; si tous passent et que `--force` est absent, l'installation est sautée.
4. `install_rc_local`, `install_service_unit` puis `install_ssh_regen_unit` — copie et deux unités, chacune suivie de `daemon-reload` puis `enable`.
5. `verify_contract` — rejoue les trois tests de `clean_system_rc_local_ready()`.
6. `arm_first_boot` si `--arm`, puis `print_summary`.

`rc.local`, exécuté au démarrage, suit un enchaînement linéaire : sortie immédiate sans drapeau, puis nom d'hôte, `/etc/hosts`, clés SSH, et enfin suppression du drapeau.

### Détail des choix techniques

- **Le nom du drapeau `do_first_boot` est un contrat, pas un détail** : `clean_system.sh` fait un `grep -q "do_first_boot" /etc/rc.local` avant d'accepter de supprimer les clés SSH d'un template. Renommer le drapeau casserait silencieusement la sécurité de `clean_system.sh`, qui se rabattrait alors sur « clés conservées ». C'est pour rendre ce couplage visible que `verify_contract` rejoue les trois mêmes tests en fin d'exécution.
- **Tier 1 à la place du refus pur et simple** : l'ancienne version affichait « Ce script doit être exécuté avec les privilèges root » et sortait en 1, motif que `CLAUDE.md` range parmi les motifs interdits — `~/.local/bin` n'étant pas dans le `secure_path` de sudo, l'utilisateur devait retaper le chemin complet. Le script se relance désormais lui-même.
- **`Type=oneshot` au lieu de `Type=forking`** : `rc.local` ne se dédouble pas. L'unité d'origine de Debian s'en tire avec `forking` grâce à `GuessMainPID=no`, absent de l'ancienne unité de ce dépôt — systemd cherchait donc un processus principal qui n'existait pas. `oneshot` + `RemainAfterExit=yes` décrit exactement ce que fait le script.
- **`ConditionFileIsExecutable` au lieu de `ConditionPathExists`** : c'est la condition de l'unité Debian d'origine, et elle correspond au besoin réel — un `/etc/rc.local` présent mais non exécutable ne servirait à rien.
- **`After=network.target dbus.service`** : `hostnamectl` passe par dbus pour parler à `systemd-hostnamed`. L'`ExecStartPre=/bin/sleep 3` de l'ancienne unité a été conservé par-dessus, comme filet sur les démarrages les plus rapides : trois secondes une seule fois dans la vie d'un clone ne coûtent rien face à un nom d'hôte non réinitialisé.
- **`SysVStartPriority=99` retiré** : option héritée de sysvinit, ignorée par systemd.
- **La régénération SSH est confiée à une unité dédiée, pas au seul `rc.local`** : `ssh-regen-keys.service` se déclenche sur la condition « clé ed25519 absente », donc sans drapeau, et surtout **avant** `ssh.service`. Avec `rc.local` seul, `sshd` démarrait d'abord sans clé, échouait, et n'était relancé qu'ensuite — la VM était injoignable pendant cette fenêtre et laissait une unité en échec dans `systemctl status`. L'idée vient de `prepare-ova-export.sh`, qui la mettait déjà en œuvre ; elle a été reprise ici pour qu'il n'existe qu'un seul mécanisme. `rc.local` appelle malgré tout `ssh-keygen -A`, sans effet lorsque l'unité a déjà fait le travail : c'est le filet pour les VM où elle manquerait.
- **`ssh-keygen -A` au lieu de `dpkg-reconfigure openssh-server`** : c'est ce que fait `dpkg-reconfigure` en interne pour les clés, mais sans passer par debconf. Au démarrage, aucun terminal ne peut répondre à une question debconf — le risque de blocage était réel, et un `DEBIAN_FRONTEND=noninteractive` n'aurait fait que masquer le problème.
- **Le drapeau est supprimé en dernier** : si la génération du nom d'hôte échoue, `rc.local` sort en 1 sans consommer le drapeau, et une nouvelle tentative a lieu au démarrage suivant. Un échec silencieux et définitif serait pire, puisqu'il ne se verrait qu'au moment où deux clones se marchent dessus sur le réseau.
- **`sed` supprime la ligne `127.0.1.1` avant de la réécrire** : l'ancien script `randomhost` (supprimé) écrasait la **ligne 2** de `/etc/hosts`, quelle qu'elle soit. Sur un fichier où `127.0.1.1` n'est pas en deuxième position, il détruisait une autre entrée.
- **La trace va dans `/var/log/tp-install/first-boot.log`** et non dans l'ancien `/var/log/hostname-regenerate.log` : même répertoire que tous les autres scripts du dépôt, conformément à `CLAUDE.md`. Aucun autre script ne lisait l'ancien fichier.
- **Pas de `set -e` dans `rc.local`** : un démarrage ne doit pas être interrompu par une commande annexe qui échoue. Les erreurs qui comptent sont testées une par une, et journalisées.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4 | Substitution de processus `>()` de `setup_logging` |
| `sudo` | — | Auto-relance Tier 1 |
| `systemctl` (systemd) | — | `daemon-reload`, `enable`, `is-enabled` |
| `cmp` (coreutils) | — | Test d'idempotence entre le `rc.local` du dépôt et celui installé |
| `hostnamectl` (systemd) | — | Utilisé par `rc.local` au démarrage |
| `ssh-keygen` (openssh-client) | — | Régénération des clés d'hôte au démarrage |

### Points d'extension

**Changer le préfixe du nom d'hôte** — la constante est en tête de `rc.local` :

```bash
readonly HOSTNAME_PREFIX="vm"     # -> labo, tp, poste…
```

Aligner sur le `labo-XXXX` de `prepare-ova-export.sh` demande de changer cette seule ligne.

**Ajouter une action au premier démarrage** (régénérer le `machine-id`, réinitialiser une base de TP, remettre un mot de passe par défaut) : insérer une étape numérotée dans `rc.local` **avant** la suppression du drapeau, pour qu'un échec laisse une nouvelle chance au démarrage suivant.

```bash
# --- 2 bis. machine-id ------------------------------------------------------
if [ -s /etc/machine-id ]; then
    truncate -s 0 /etc/machine-id
    log "machine-id remis à zéro (regénéré au prochain démarrage)."
fi
```

### Notes de maintenance

- **Le dépôt ne compte plus qu'un seul mécanisme de réinitialisation.** `prepare-ova-export.sh` embarquait le sien jusqu'en septembre 2026 ; il arme désormais celui-ci. Une VM préparée avant ce changement peut encore porter l'ancien (`random-hostname.service`, `/usr/local/bin/set-random-hostname.sh`, `/etc/hostname-initialized`) : `prepare-ova-export.sh` le retire au passage, mais une VM qui ne repasserait jamais par lui garderait les deux. Le symptôme est un nom d'hôte `labo-XXXX` là où on attend `vm-XXXXXXXX`.
- `ssh-regen-keys.service` n'a **pas** de drapeau : sa condition `ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key` suffit. Il se réarme donc tout seul si les clés sont supprimées à nouveau, y compris hors de tout export.
- L'unité écrite dans `/etc/systemd/system/rc-local.service` **masque** celle que Debian fournit dans `/lib/systemd/system/`. C'est voulu : l'unité Debian n'a pas de section `[Install]`, donc `systemctl enable` échoue dessus, alors que `clean_system.sh` teste `is-enabled`.
- Modifier le `rc.local` du dépôt ne change rien sur une VM déjà installée : il faut relancer `make_rclocal.sh` (le test `cmp` détecte la différence et réinstalle, sans même avoir besoin de `--force`).
- `rc.local` n'est **pas** un script du dépôt qu'on lance à la main : c'est une charge utile déposée dans `/etc`. Le lancer depuis le dépôt ne ferait rien, faute de drapeau — et le lancer avec un drapeau posé réinitialiserait la machine courante.
- La trace `/var/log/tp-install/first-boot.log` n'est écrite qu'aux démarrages où le drapeau est présent. Un fichier absent signifie que le relais n'a jamais été armé, pas qu'il a échoué.
