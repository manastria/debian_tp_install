# install_eth0.sh

> Script : [`install_eth0.sh`](../install_eth0.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install_eth0.sh` rétablit les noms d'interfaces réseau historiques — `eth0`, `eth1`, … — sur une VM Debian, en désactivant le nommage prédictible de systemd. Concrètement il ajoute `net.ifnames=0` et `biosdevname=0` à la variable `GRUB_CMDLINE_LINUX` de `/etc/default/grub`, sauvegarde le fichier au passage, puis régénère la configuration GRUB avec `update-grub`. Il ne configure **aucune adresse IP** et n'installe pas NetworkManager : c'est `install_network-manager.sh` qui s'en charge. Le renommage ne prend effet **qu'au redémarrage**, et le script prévient si `/etc/network/interfaces` mentionne encore des noms qui vont disparaître. Relancé une deuxième fois, il constate que les deux paramètres sont déjà là et ne touche à rien, sauf si on lui passe `--force`.

---

## Section utilisateur

### Description

Depuis systemd 197, Debian nomme les interfaces réseau d'après leur emplacement matériel : `enp0s3`, `ens33`, `eno1`… Ces noms sont stables d'un démarrage à l'autre, mais ils varient d'une VM à l'autre selon le nombre de contrôleurs et leur position sur le bus PCI, ce qui rend illisible un sujet de TP qui parle d'« eth0 ».

Le script désactive ce mécanisme en ajoutant deux paramètres à la ligne de commande du noyau :

- `net.ifnames=0` désactive le nommage prédictible de systemd/udev ;
- `biosdevname=0` désactive le schéma concurrent de Dell (`em1`, `p1p1`), au cas où le paquet serait installé.

Il diffère de ses deux voisins :

- [`install_network-manager.sh`](install_network-manager.md) confie les interfaces à NetworkManager ; il ne les renomme pas.
- `switch-to-networkmanager.sh` fait la même chose sur les machines Ubuntu/XUbuntu pilotées par netplan.

`install_eth0.sh` ne touche qu'à GRUB, donc uniquement aux **noms** des interfaces. Il ne configure ni adresse, ni passerelle, ni DNS.

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| `sudo` | Le script se relance lui-même via sudo s'il n'est pas déjà root | `command -v sudo` |
| GRUB (`/etc/default/grub`) | Fichier de configuration modifié par le script | `test -f /etc/default/grub` |
| `update-grub` ou `grub-mkconfig` (paquet `grub2-common`) | Régénère `/boot/grub/grub.cfg` à partir du fichier modifié | `command -v update-grub` |
| `ip` (paquet `iproute2`) | Affiche les noms d'interfaces actuels — facultatif, le script s'en passe | `command -v ip` |

### Syntaxe

```
sudo ./install_eth0.sh [--force] [-h|--help]
```

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `--force` | — | désactivé | Réécrit `/etc/default/grub` et relance `update-grub` même si les deux paramètres sont déjà présents. Utile après une modification manuelle du fichier. |
| `-h`, `--help` | — | — | Affiche le bloc d'en-tête (NAME/SYNOPSIS/…) et quitte, sans demander de mot de passe ni toucher au système. |

### Exemples d'utilisation

```bash
# Bascule vers les noms classiques, depuis la VM Debian
sudo ./install_eth0.sh
```

Sortie réelle :

```
===== 2026-09-04 20:18:08 | install_eth0.sh  | root@debian12 =====

=== Noms d'interfaces réseau classiques (eth0) ===

[INFO]      Interfaces actuelles : enp0s3
[INFO]      Ancienne valeur : GRUB_CMDLINE_LINUX=""
[OK]        Sauvegarde : /etc/default/grub.bak-20260904-201808
[OK]        GRUB_CMDLINE_LINUX = "net.ifnames=0 biosdevname=0"
[INFO]      Régénération de la configuration GRUB...
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.1.0-23-amd64
Found initrd image: /boot/initrd.img-6.1.0-23-amd64
done
[OK]        Configuration GRUB régénérée.
[ATTENTION] Ces fichiers désignent des interfaces qui n'existeront plus après redémarrage :
[ATTENTION]     - /etc/network/interfaces
[ATTENTION] Adaptez-les (eth0, eth1, …) avant de redémarrer, sous peine de démarrer sans réseau.

Noms d'interfaces classiques configurés.

  Sauvegarde   : /etc/default/grub.bak-20260904-201808
  Journal      : /var/log/tp-install/install_eth0.log

  Restauration : sudo cp -a /etc/default/grub.bak-20260904-201808 /etc/default/grub && sudo update-grub

[ATTENTION] Le renommage en eth0 ne prend effet qu'au prochain redémarrage.
```

```bash
# Relance immédiate : le script constate que tout est déjà en place
sudo ./install_eth0.sh
```

```
[INFO]      Interfaces actuelles : enp0s3
[OK]        net.ifnames=0 et biosdevname=0 sont déjà dans GRUB_CMDLINE_LINUX.
[INFO]      Rien à faire. Utilisez --force pour réécrire et régénérer GRUB malgré tout.
```

```bash
# Vérifier le résultat après redémarrage
ip -br link show
cat /proc/cmdline

# Revenir en arrière (la sauvegarde est horodatée, choisir la plus ancienne)
sudo cp -a /etc/default/grub.bak-20260904-201808 /etc/default/grub
sudo update-grub
```

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès, ou paramètres déjà présents (le script n'a rien modifié). |
| 1 | Option inconnue, `/etc/default/grub` introuvable, ni `update-grub` ni `grub-mkconfig` disponibles, ou échec de la régénération GRUB. |

## Section développeur

### Architecture interne

`main()` enchaîne, dans l'ordre :

1. `setup_logging` — bascule stdout/stderr vers un tee (écran + `/var/log/tp-install/install_eth0.log`) et pose le `trap cleanup EXIT`.
2. `check_prerequisites` — présence de `/etc/default/grub` et d'un générateur GRUB.
3. `show_current_interfaces` — affiche les noms actuels, pour comparaison après redémarrage.
4. `read_current_cmdline` puis `build_new_cmdline` — calcul de la nouvelle valeur ; si elle est identique à l'ancienne et que `--force` est absent, le script s'arrête ici en code 0.
5. `backup_grub` — copie horodatée du fichier.
6. `write_cmdline` — réécriture de la ligne `GRUB_CMDLINE_LINUX`.
7. `regenerate_grub` — `update-grub`, ou `grub-mkconfig -o /boot/grub/grub.cfg` en repli.
8. `check_config_references` — avertit si un fichier ifupdown désigne encore une interface au nom prédictible.
9. `print_summary` — sauvegarde, journal, commande de restauration, rappel du redémarrage.

Le parsing des arguments et l'élévation de privilèges (auto-relance sudo, Tier 1) ont lieu **avant**, en haut du fichier, hors de toute fonction.

### Détail des choix techniques

- **`/etc/default/grub` est sourcé, pas analysé à coups de `sed`** : c'est un fragment shell, et c'est exactement ainsi que `grub-mkconfig` le lit. Le sourcer dans un sous-shell (`read_current_cmdline`) donne la valeur réellement effective de `GRUB_CMDLINE_LINUX`, guillemets et échappements résolus, y compris quand le fichier contient plusieurs affectations successives — cas où un parseur naïf lirait la mauvaise. Le sous-shell passe en `set +u` car le fichier peut référencer des variables non définies.
- **Les paramètres existants sont conservés** : l'ancienne version écrasait la ligne entière par `GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"`, ce qui supprimait sans prévenir tout ce qui s'y trouvait (`ipv6.disable=1`, `console=ttyS0`…). `build_new_cmdline` ajoute uniquement ce qui manque, la comparaison étant faite sur la chaîne encadrée d'espaces pour ne pas confondre `net.ifnames=0` avec un `xxx.net.ifnames=01`.
- **Sauvegarde horodatée plutôt que `.jpde` fixe** : l'ancienne version copiait toujours vers `/etc/default/grub.jpde`. Au deuxième lancement, elle y écrivait le fichier **déjà modifié** et détruisait donc la seule copie d'origine. Le suffixe `.bak-<horodatage>` rend chaque exécution non destructrice.
- **`awk` avec `ENVIRON` plutôt que `sed s///`** : la valeur de remplacement peut contenir `/`, `&` ou `\`, tous significatifs dans la partie droite d'un `sed`. Le passage par une variable d'environnement évite en plus l'interprétation des échappements que ferait `awk -v`.
- **Les affectations en double sont supprimées** : `write_cmdline` remplace la première ligne `GRUB_CMDLINE_LINUX=` et retire les suivantes. Le fichier étant sourcé de haut en bas, une affectation laissée plus bas écraserait la valeur qu'on vient d'écrire.
- **Le motif exige le `=` collé au nom** : `^[[:space:]]*GRUB_CMDLINE_LINUX=` ne matche pas `GRUB_CMDLINE_LINUX_DEFAULT=`, qu'il ne faut surtout pas toucher.
- **`GRUB_CMDLINE_LINUX` et non `GRUB_CMDLINE_LINUX_DEFAULT`** : le second ne s'applique qu'aux entrées de menu normales, pas aux entrées de secours. Un noyau démarré en mode recovery retrouverait alors les noms prédictibles, avec un `/etc/network/interfaces` qui ne correspondrait plus.
- **`update-grub` préféré à `grub-mkconfig -o …`** : le wrapper Debian connaît le bon chemin de sortie en BIOS comme en UEFI. Le `grub-mkconfig -o /boot/grub/grub.cfg` n'est qu'un repli pour les systèmes qui n'ont pas le wrapper.
- **Plage d'aide délimitée par une expression régulière** (`sed -n '2,/^# =\{10,\}$/p'`) et non par des numéros de ligne comme dans `configure-sudo.sh` : rallonger l'en-tête ne tronque plus l'aide silencieusement.
- **Un seul `trap EXIT`** : `cleanup` restaure les descripteurs *et* supprime le fichier temporaire de `write_cmdline`, conformément à la règle « un seul trap EXIT par script » de `CLAUDE.md`. Le test de présence y est écrit en bloc `if` et non en `[ … ] && rm`, qui renverrait un statut non nul depuis le gestionnaire sous `set -e`.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4 | Substitution de processus `>()` de `setup_logging`, tableaux |
| `sudo` | — | Auto-relance Tier 1 |
| `update-grub` / `grub-mkconfig` (`grub2-common`) | — | Régénération de `/boot/grub/grub.cfg` |
| `awk`, `sed`, `install`, `mktemp` | — | Réécriture du fichier et trace de log |
| `ip` (`iproute2`) | — | Affichage des interfaces actuelles ; absence tolérée |

### Points d'extension

**Ajouter une option `--revert`** qui retire les deux paramètres au lieu de les ajouter — utile pour repasser une VM en nommage prédictible sans éditer le fichier à la main :

```bash
strip_params() {
    local new=""
    local param
    for param in $1; do
        case " ${GRUB_PARAMS[*]} " in
            *" $param "*) continue ;;   # paramètre géré par le script : on le retire
        esac
        new="${new:+$new }$param"
    done
    printf '%s' "$new"
}
```

À brancher dans `main()` en remplacement de `build_new_cmdline` quand `REVERT=1`, le reste de l'enchaînement (sauvegarde, écriture, `update-grub`) étant identique.

**Ajouter d'autres paramètres noyau** (par exemple `ipv6.disable=1` pour un TP IPv4) : les déclarer dans la constante `GRUB_PARAMS`, tout le reste suit.

### Notes de maintenance

- Chaque exécution qui modifie le fichier laisse une sauvegarde `/etc/default/grub.bak-<horodatage>`. Sur une VM relancée souvent, elles s'accumulent : c'est volontaire (on ne détruit jamais une copie antérieure), mais un ménage manuel est parfois utile.
- Le renommage ne prend effet qu'au redémarrage. Tant que la VM n'a pas redémarré, `ip link` montre encore les anciens noms — ne pas en conclure que le script a échoué.
- `check_config_references` n'inspecte que `/etc/network/interfaces` et `interfaces.d/`. Un profil NetworkManager attaché à `enp0s3` (`/etc/NetworkManager/system-connections/*.nmconnection`, clé `interface-name`) n'est pas détecté et devra être corrigé à la main.
- Le script ne touche pas à `/etc/udev/rules.d/70-persistent-net.rules`. Si une VM clonée en contient un, il prendra le pas sur le nommage et donnera un `eth1` là où on attend `eth0`.
- La trace `/var/log/tp-install/install_eth0.log` est ouverte en ajout. Prévoir le fichier logrotate décrit dans `CLAUDE.md` si le script est relancé en boucle.
