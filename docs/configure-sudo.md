# configure-sudo.sh

> Script : [`configure-sudo.sh`](../configure-sudo.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`configure-sudo.sh` met en place deux groupes sudo pour les étudiants d'un labo Debian/Ubuntu : **adminpwd** (sudo avec mot de passe) et **admins** (sudo sans mot de passe). Il crée les groupes système s'ils n'existent pas encore, dépose deux fichiers dans `/etc/sudoers.d/` — un pour les privilèges des deux groupes, un pour conserver des variables d'environnement comme `DISPLAY` à travers `sudo` — puis rappelle la commande `usermod -aG` à utiliser pour rattacher un étudiant à l'un des deux groupes. Il ne crée **pas** les comptes utilisateurs eux-mêmes, voir `create_user.sh` pour ça. Le script est idempotent : le relancer écrase les fichiers `sudoers.d` avec le même contenu et ne recrée pas les groupes déjà présents.

---

## Section utilisateur

### Description

Ce script prépare l'infrastructure sudo d'un poste de labo pour deux niveaux d'étudiants :

- `adminpwd` : sudo classique, avec mot de passe, pour les étudiants qui doivent comprendre le mécanisme d'authentification.
- `admins` : sudo sans mot de passe, pensé comme béquille pour les débutants qui butent encore sur la saisie du mot de passe en TP.

Il diffère de `create_user.sh` : ce dernier crée les comptes, `configure-sudo.sh` ne fait que préparer les groupes et les règles sudo associées. Un compte créé par `create_user.sh` doit ensuite être rattaché à `adminpwd` ou `admins` via `usermod -aG` (voir Exemples ci-dessous) pour obtenir des droits sudo.

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| `sudo` | Le script se relance lui-même via sudo s'il n'est pas déjà root | `command -v sudo` |
| `visudo` | Valide la syntaxe de chaque fichier déposé dans `/etc/sudoers.d/` avant de l'accepter | `command -v visudo` |
| `groupadd`, `getent` | Créent et vérifient l'existence des groupes système (paquet `passwd`, présent par défaut) | `command -v groupadd` |

### Syntaxe

```
sudo ./configure-sudo.sh [-h|--help]
```

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `-h`, `--help` | — | — | Affiche l'aide (bloc NAME/SYNOPSIS/…) et quitte, sans relancer en root ni toucher au système. |

### Exemples d'utilisation

```bash
# Mise en place initiale des groupes et des règles sudo
sudo ./configure-sudo.sh
```

Sortie réelle (extrait) :

```
=== Configuration de sudo ===

[INFO]      Configuration des variables d'environnement conservées par sudo...
[OK]        Environnement sudo configuré (/etc/sudoers.d/env_custom).
[OK]        Groupe 'admins' créé.
[OK]        Groupe 'adminpwd' créé.
[INFO]      Configuration des privilèges sudo pour les groupes de labo...
[OK]        Privilèges sudo configurés (/etc/sudoers.d/admins).

Configuration de sudo terminée avec succès !

Pour donner les droits sudo à un utilisateur :

  Deux groupes sont disponibles selon le niveau de l'étudiant :

    - adminpwd : sudo AVEC mot de passe
    - admins   : sudo SANS mot de passe
  ...
```

```bash
# Rattacher un étudiant à l'un des deux groupes (après création du compte)
sudo usermod -aG adminpwd etudiant1   # sudo AVEC mot de passe
sudo usermod -aG admins   etudiant2   # sudo SANS mot de passe

# Vérifier l'appartenance (effective à la prochaine session)
groups etudiant1
```

**Migrer un utilisateur d'un groupe vers l'autre** — `usermod -aG` n'a pas d'équivalent « retirer » : il faut passer par `gpasswd -d` (ou `deluser`, équivalent) pour quitter l'ancien groupe avant de rejoindre le nouveau.

```bash
# Exemple : faire passer etudiant2 de "admins" (sans mot de passe)
# vers "adminpwd" (avec mot de passe)
sudo gpasswd -d etudiant2 admins       # retire du groupe admins
sudo usermod -aG adminpwd etudiant2    # ajoute au groupe adminpwd

# Vérifier le résultat (effectif à la prochaine connexion)
groups etudiant2
```

Ne jamais utiliser `usermod -G adminpwd etudiant2` seul (sans `-a`) pour faire la migration : `-G` sans `-a` **remplace** la liste complète des groupes secondaires de l'utilisateur, ce qui le retire aussi de tout autre groupe auquel il appartenait (`sudo`, `wireshark`, etc.) sans avertissement.

**Utilisateur présent dans les deux groupes à la fois** — le script ne l'empêche pas : `adminpwd` et `admins` sont deux groupes secondaires indépendants, rien n'interdit d'appartenir aux deux en même temps (par exemple pendant une migration faite dans le mauvais ordre, ou par erreur). Dans ce cas, ce n'est **ni un mélange des deux règles ni la plus stricte des deux qui l'emporte** : `/etc/sudoers.d/admins` déclare `%adminpwd` puis `%admins` dans cet ordre (voir le fichier généré par `configure_lab_privileges`), et sudo applique la **dernière entrée qui correspond** à la commande demandée. Un utilisateur membre des deux groupes hérite donc du comportement de `%admins`, listée en second : sudo **sans** mot de passe, malgré son appartenance à `adminpwd`.

Pour vérifier concrètement le comportement effectif d'un utilisateur :

```bash
sudo -l -U etudiant2
```

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès. |
| 1 | Option inconnue passée en argument, ou fichier `sudoers.d` généré jugé invalide par `visudo -cf` (le fichier est supprimé avant de sortir, sudo n'est pas modifié). |

## Section développeur

### Architecture interne

`main()` enchaîne, dans l'ordre :

1. `setup_logging` — bascule stdout/stderr vers un tee (écran + `/var/log/tp-install/configure-sudo.log`) et pose le `trap cleanup EXIT`.
2. `configure_env_keep` — écrit `/etc/sudoers.d/env_custom`, valide avec `visudo -cf`.
3. `create_lab_groups` — crée `admins` et `adminpwd` s'ils manquent (idempotent via `getent group`).
4. `configure_lab_privileges` — écrit `/etc/sudoers.d/admins`, valide avec `visudo -cf`.
5. `print_usage_hint` — rappelle la syntaxe `usermod -aG` à l'écran.

L'élévation de privilèges (auto-relance sudo Tier 1) et le parsing des arguments ont lieu **avant** ces étapes, en haut du fichier, hors de toute fonction.

### Détail des choix techniques

- **`-h` traité avant la relance sudo** : le parsing d'arguments (bloc `while [[ $# -gt 0 ]]`) est placé avant le bloc d'élévation de privilèges. Sans cet ordre, consulter l'aide déclencherait une demande de mot de passe pour rien.
- **`trap cleanup EXIT` posé dans `setup_logging`, pas au niveau supérieur du script** : si le trap était posé immédiatement après la définition de `cleanup`, il se déclencherait aussi sur le chemin `-h` (qui sort avant tout appel à `setup_logging`) et tenterait de restaurer des descripteurs 3/4 jamais dupliqués. Le poser à la fin de `setup_logging`, une fois la redirection réellement active, évite l'erreur.
- **`visudo -cf` suivi d'un `rm -f` en cas d'échec** : un fragment invalide laissé dans `/etc/sudoers.d/` peut casser `sudo` pour **tout le système**, pas seulement pour les groupes de labo. Le script ne se contente donc plus d'avertir (comportement de l'ancienne version) : il supprime le fichier fautif et interrompt l'exécution.
- **`env_keep` pour `DISPLAY`/`XAUTHORITY`/`SSH_AUTH_SOCK`** : sans ça, une application graphique lancée en `sudo` (gestionnaire de paquets, éditeur de fichiers système) échoue à s'afficher — un problème récurrent en salle de TP où les étudiants travaillent en session graphique.
- **Deux groupes plutôt qu'un seul avec un booléen** : `adminpwd`/`admins` correspondent à deux étapes pédagogiques distinctes (béquille intermédiaire vs béquille débutant), documentées comme telles dans le fichier sudoers.d généré.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4 | Substitution de processus `>()` utilisée par `setup_logging` |
| `sudo` | — | Auto-relance Tier 1 et exécution effective des commandes root |
| `visudo` (paquet `sudo`) | — | Validation syntaxique des fichiers sudoers.d avant activation |

### Points d'extension

Ajouter un troisième niveau de groupe (par exemple `admins-readonly` avec une liste de commandes limitée) se fait en étendant `configure_lab_privileges` :

```bash
cat > "$SUDOERS_ADMINS_FILE" << EOF
%adminpwd        ALL=(ALL:ALL)   PASSWD: ALL
%admins          ALL=(ALL:ALL)   NOPASSWD: ALL
%admins-readonly ALL=(ALL:ALL)   NOPASSWD: /usr/bin/apt, /usr/bin/systemctl status *
EOF
```

et en ajoutant le `groupadd` correspondant dans `create_lab_groups`.

### Notes de maintenance

- Le groupe `admins` accorde `NOPASSWD: ALL`, soit un accès root complet sans mot de passe. Ce script est pensé pour des VM de TP jetables — ne pas l'appliquer tel quel sur un poste de production.
- Contrairement à `switch-to-networkmanager.sh`, ce script ne sauvegarde pas les fichiers `sudoers.d` existants avant de les écraser. Un `/etc/sudoers.d/admins` modifié manuellement par un enseignant serait perdu sans avertissement au prochain lancement.
- Les fichiers `sudoers.d` sont réécrits intégralement à chaque exécution (pas de fusion) : toute personnalisation ajoutée à la main dans `env_custom` ou `admins` sera écrasée au prochain `./configure-sudo.sh`.
- L'ordre des lignes `%adminpwd` puis `%admins` dans `configure_lab_privileges` est significatif, pas cosmétique : sudo applique la dernière entrée qui correspond, donc un utilisateur membre des deux groupes se retrouve en `NOPASSWD` (voir « Utilisateur présent dans les deux groupes à la fois » ci-dessus). Inverser l'ordre des deux lignes inverserait ce comportement — à garder en tête si `configure_lab_privileges` est modifié.
