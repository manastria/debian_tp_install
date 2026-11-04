# install_telnetd.sh

> Script : [`install_telnetd.sh`](../install_telnetd.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install_telnetd.sh` prépare une VM de TP pour le cours SSH : il installe le client `telnet` et le serveur `telnetd` (avec le superserveur `inetutils-inetd`), puis laisse le service **désactivé**, port 23 fermé. Il désactive la ligne telnet d'inetd avec `update-inetd --disable telnet` et arrête `inetutils-inetd`, ce qui permet à l'étudiant de l'activer lui-même en séance avec `update-inetd --enable telnet`. Il vérifie le résultat (paquets, ligne `#<off># telnet`, rien sur le port 23). Il ne crée aucun compte, n'installe ni SSH ni Wireshark (voir `install_wireshark.sh`) et n'a aucune option utile : on le lance sans argument, depuis l'image avant `prepare-ova-export.sh`. Il peut être relancé sans risque.

---

## Section utilisateur

### Description

Le cours `015-ssh-fondamentaux` (partie 1, « Ce que voit celui qui écoute ») fait activer un serveur telnet, capturer la connexion avec Wireshark, puis refermer telnet. La séance se fait sans Internet : le serveur doit donc déjà être dans l'image `.ova`. Mais telnet transmet les mots de passe en clair, et le compte de test a un mot de passe connu de toute la classe : le serveur ne doit jamais écouter hors séance.

Le script amène la VM à l'état « installé mais désactivé » :

1. **Installation** : `telnet` et `telnetd` (sautée si déjà présents).
2. **Désactivation** : `update-inetd --disable telnet`, qui préfixe la ligne de `/etc/inetd.conf` par `#<off>#`.
3. **Arrêt** de `inetutils-inetd`, qui avait pu démarrer avec telnet actif juste après l'installation.
4. **Vérification** : paquets présents, ligne `#<off># telnet` présente, rien n'écoute sur le port 23.

Ce sont les contrôles de `public/vm/verifier-vm.sh` pour le cours 015 (lignes `paquet telnetd`, `inetd-disabled telnet`, `port-ferme 23`, `commande telnet`) : le script prépare l'état, `verifier-vm.sh` le contrôle sur la VM, sans `sudo`.

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| `sudo` | Le script se relance lui-même via sudo s'il n'est pas déjà root | `command -v sudo` |
| `apt-get`, `dpkg` | Installation des paquets | `command -v apt-get` |
| `systemctl` | Arrêt de `inetutils-inetd` | `command -v systemctl` |
| `ss` (iproute2) | Contrôle du port 23 | `command -v ss` |
| Accès aux dépôts APT | Seulement si telnet n'est pas encore installé | `apt-get update` |

### Syntaxe

```
./install_telnetd.sh [-h|--help]
```

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `-h`, `--help` | — | — | Affiche le bloc d'en-tête et quitte, sans demander de mot de passe. |

### Exemples d'utilisation

```bash
# Préparer l'image : telnet installé, serveur désactivé
./install_telnetd.sh

# Contrôler ensuite, avec le script du dépôt cours_astro
bash public/vm/verifier-vm.sh 015-ssh-fondamentaux
```

Sortie attendue (extrait) :

```
=== Installation de telnet (serveur désactivé) ===

[INFO]      Installation de telnet telnetd...
[OK]        telnet telnetd installé(s).
[INFO]      Ligne telnet active dans inetd : désactivation.
[INFO]      Arrêt de inetutils-inetd.service (il écoutait peut-être sur le port 23)...
[OK]        telnet désactivé dans inetd.
[OK]        Paquets présents : telnet telnetd.
[OK]        Ligne telnet présente et commentée (« #<off># »).
[OK]        Rien n'attend sur le port 23.
```

> Cette sortie est reconstituée d'après les messages du script : il n'a pas encore été lancé sur une VM (voir « Notes de maintenance »).

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès : telnet installé, désactivé, port 23 fermé |
| 1 | Option inconnue, `apt-get`, `systemctl` ou `ss` absent, échec d'installation, ligne telnet introuvable dans inetd, ou port 23 encore ouvert |

---

## Section développeur

### Architecture interne

`main()` enchaîne :

1. `setup_logging` — trace dans `/var/log/tp-install/install_telnetd.log`.
2. `check_prerequisites` — `apt-get`, `dpkg`, `systemctl`, `ss`.
3. `install_packages` — `apt-get install telnet telnetd` pour ceux qui manquent.
4. `disable_telnet` — `update-inetd --disable`, puis arrêt d'`inetutils-inetd`.
5. `verify_state` — paquets, ligne `#<off>#`, port 23.
6. `print_summary` — rappelle les commandes d'activation et de fermeture du cours.

### Détail des choix techniques

- **Désactiver explicitement, ne pas compter sur le paquet** : les notes de séance du cours supposaient que `telnetd` « s'installe avec le service désactivé ». Le relevé de la VM de vérification du 2 novembre 2026 (`lab/verif-015-20261102-205629/`) montre le contraire : `inetutils-inetd` actif, ligne telnet non commentée dans `inetd.conf`, port 23 ouvert. Sans cette étape, l'image sortirait avec un serveur telnet actif, et le contrôle `inetd-disabled` de `verifier-vm.sh` échouerait.
- **`update-inetd --disable`, pas la suppression de la ligne** : la ligne est conservée avec le préfixe `#<off>#`, seul état que `update-inetd --enable` sait rétablir (étape 3 du cours). Supprimer la ligne ou la commenter avec un simple `#` rendrait `--enable` sans effet.
- **Arrêt d'`inetutils-inetd` après la désactivation** : inetd ne relit sa configuration qu'au redémarrage. Arrêté, il ne repart pas non plus au démarrage de la VM : son unité porte `ExecCondition=grep -qr ^[0-9A-Za-z/] /etc/inetd.conf /etc/inetd.d/`, qui échoue tant qu'aucune ligne n'est active. À l'étape 3, `systemctl restart` le relance une fois telnet réactivé.
- **Paquets `telnet` et `telnetd`** : ce sont des paquets de transition qui dépendent de `inetutils-telnet` et `inetutils-telnetd`. On installe les noms que cite le cours et que contrôle `verifier-vm.sh` ; `telnetd` apporte `update-inetd` et `inetutils-inetd`.
- **Test de port avec `ss -H`** : sans en-tête, une sortie vide signifie « rien n'écoute » (sans `-H`, `ss` affiche toujours la ligne d'en-tête).
- **Fichiers inetd** : la recherche couvre `/etc/inetd.conf` et `/etc/inetd.d/*`, comme `verifier-vm.sh`, car `inetutils-inetd` lit les deux. `update-inetd`, lui, ne gère que `inetd.conf`.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4.4 | `"${ORIG_ARGS[@]}"` vide sous `set -u` ; `>()` de `setup_logging` ; `mapfile` |
| `update-inetd` (paquet `update-inetd`) | — | Désactivation de la ligne telnet |
| `systemctl` | — | Arrêt d'`inetutils-inetd` |
| `ss` (iproute2) | — | Contrôle du port 23 |

### Points d'extension

**Laisser telnet activé** (pour préparer une VM de démonstration plutôt que l'image) : retirer l'appel à `disable_telnet` de `main()` et adapter `verify_state`, qui exigerait sinon une ligne commentée.

**Autre service inetd** : `INETD_NAME` et `PORT` en tête de script désignent la ligne et le port ; changer les deux (et `PACKAGES`) suffit pour un autre service géré par `update-inetd`.

### Notes de maintenance

- **Non testé sur une VM** : le script a été écrit d'après le relevé du 2 novembre 2026 (Ubuntu 26.04, `inetutils` 2:2.7-2ubuntu1.1) et vérifié pour la syntaxe et l'aide seulement. À lancer une première fois sur un clone de l'image, puis à contrôler avec `verifier-vm.sh 015-ssh-fondamentaux`.
- Le client `telnet` est celui d'`inetutils`. Une version de `inetutils-telnetd` antérieure au correctif de CVE-2026-24061 (janvier 2026 : session root sans mot de passe) ne doit pas rester dans l'image, même désactivée : `apt-get upgrade` avant l'export.
- Si une version future d'Ubuntu abandonne `inetutils-inetd` pour un autre superserveur, `INETD_SERVICE` et le test de port sont à revoir, ainsi que la table `EXIGENCES` de `verifier-vm.sh` et l'étape 3 du cours.
