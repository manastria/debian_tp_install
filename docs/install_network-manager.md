# install_network-manager.sh

> Script : [`install_network-manager.sh`](../install_network-manager.sh)

## En bref

> Paragraphe de rappel, à coller tel quel dans le mémo.

`install_network-manager.sh` confie le réseau d'une VM **Debian** à NetworkManager, à la place d'ifupdown. Il installe le paquet `network-manager`, sauvegarde puis réduit `/etc/network/interfaces` au seul loopback, dépose un fragment `managed=true` dans `/etc/NetworkManager/conf.d/`, et redémarre le service — les interfaces se pilotent ensuite avec `nmtui` ou `nmcli`. À ne pas confondre avec `switch-to-networkmanager.sh`, qui fait le même travail sur les machines **Ubuntu/XUbuntu** pilotées par netplan : ici, la détection de netplan interrompt l'exécution. Il ne renomme pas les interfaces en `eth0`, ce qui est le rôle de `install_eth0.sh`. Les deux options utiles au quotidien sont `--yes`, qui supprime la confirmation demandée en session SSH, et `--force`, qui réapplique la configuration sur une machine déjà basculée.

---

## Section utilisateur

### Description

Sur une installation Debian minimale, le réseau est piloté par **ifupdown** : les interfaces sont déclarées dans `/etc/network/interfaces`, montées au démarrage par `networking.service`, et se configurent en éditant ce fichier. NetworkManager, lui, ignore par défaut toute interface qui y figure — c'est le sens de `managed=false` livré par Debian dans `/etc/NetworkManager/NetworkManager.conf`.

Le script effectue la bascule sur les deux tableaux, ce qui est nécessaire pour que NetworkManager prenne réellement la main :

1. il retire les interfaces de `/etc/network/interfaces` (réduit au loopback), pour qu'ifupdown ne les monte plus ;
2. il pose `managed=true` pour le greffon ifupdown, pour que NetworkManager cesse de les considérer comme chasse gardée.

Les interfaces se configurent ensuite avec `nmtui` (interface texte) ou `nmcli`, ce qui est l'objectif pédagogique : c'est l'outil qu'on retrouve sur toutes les distributions de la famille.

Trois voisins à ne pas confondre :

| Script | Cible | Rôle |
|---|---|---|
| `install_network-manager.sh` | Debian, ifupdown | Bascule d'ifupdown vers NetworkManager |
| `switch-to-networkmanager.sh` | Ubuntu/XUbuntu, netplan | Bascule du renderer netplan vers NetworkManager |
| [`install_eth0.sh`](install_eth0.md) | Debian | Renomme les interfaces en `eth0`, sans toucher à leur configuration |

Le script refuse de s'exécuter si netplan est détecté, précisément pour éviter qu'on l'applique à une machine Ubuntu où il ne servirait à rien.

### Prérequis

| Outil | Rôle | Commande de vérification |
|---|---|---|
| `sudo` | Le script se relance lui-même via sudo s'il n'est pas déjà root | `command -v sudo` |
| `apt-get`, `dpkg` | Installation du paquet `network-manager` et test de présence | `command -v apt-get` |
| `systemd` (`systemctl`) | Activation, redémarrage et test d'état du service NetworkManager | `command -v systemctl` |
| Accès réseau au dépôt Debian | Nécessaire uniquement si `network-manager` n'est pas déjà installé | `apt-get -s install network-manager` |
| Absence de netplan | Garde-fou : netplan signale une machine Ubuntu, hors cible | `command -v netplan` (doit être vide) |

### Syntaxe

```
sudo ./install_network-manager.sh [--force] [-y|--yes] [-h|--help]
```

| Option | Argument | Défaut | Description |
|---|---|---|---|
| `--force` | — | désactivé | Réapplique toute la configuration même si la machine est déjà basculée, **et** passe outre la détection de netplan. |
| `-y`, `--yes` | — | désactivé | Ne pose aucune question. Seule question existante : la confirmation demandée quand une session SSH est détectée. |
| `-h`, `--help` | — | — | Affiche le bloc d'en-tête (NAME/SYNOPSIS/…) et quitte, sans demander de mot de passe ni toucher au système. |

### Exemples d'utilisation

```bash
# Bascule complète, depuis la console de la VM Debian
sudo ./install_network-manager.sh
```

Sortie réelle :

```
===== 2026-09-04 20:18:43 | install_network-manager.sh  | root@debian12 =====

=== Bascule du réseau vers NetworkManager (Debian) ===

[INFO]      network-manager déjà installé (version 1.42.4-1).
[OK]        Sauvegarde : /etc/network/interfaces.bak-20260904-201843
[INFO]      Interfaces retirées d'ifupdown : eth0
[OK]        /etc/network/interfaces réduit au loopback.
[OK]        Greffon ifupdown en mode « managed » (/etc/NetworkManager/conf.d/99-tp-ifupdown-managed.conf).
[INFO]      Greffon ifupdown actif dans /etc/NetworkManager/NetworkManager.conf.
[INFO]      Activation et redémarrage de NetworkManager...
[OK]        État de NetworkManager : connected
[INFO]      Périphériques vus par NetworkManager :
DEVICE       TYPE       STATE          CONNECTION
eth0         ethernet   connected      Connexion filaire 1
lo           loopback   connected (externally) lo

Réseau confié à NetworkManager.

  Sauvegarde   : /etc/network/interfaces.bak-20260904-201843
  Greffon      : /etc/NetworkManager/conf.d/99-tp-ifupdown-managed.conf
  Journal      : /var/log/tp-install/install_network-manager.log

  Piloter le réseau : nmtui  (ou nmcli device status)

  Restauration :
      sudo cp -a /etc/network/interfaces.bak-20260904-201843 /etc/network/interfaces
      sudo rm -f /etc/NetworkManager/conf.d/99-tp-ifupdown-managed.conf
      sudo systemctl restart NetworkManager networking

[ATTENTION] Un redémarrage est conseillé pour repartir d'un état propre.
```

```bash
# Relance immédiate : rien à refaire
sudo ./install_network-manager.sh
```

```
[OK]        NetworkManager est déjà installé, actif et maître des interfaces.
[INFO]      Rien à faire. Utilisez --force pour tout réappliquer.
```

Lancé par erreur sur une machine Ubuntu/XUbuntu, le garde-fou s'interpose :

```
[ATTENTION] netplan est installé sur cette machine.
[ATTENTION] Ce script cible Debian/ifupdown ; sur Ubuntu/XUbuntu, utilisez plutôt
[ATTENTION]     ./switch-to-networkmanager.sh
[ERREUR]    Interrompu. Relancez avec --force pour passer outre.
```

```bash
# Bascule assumée depuis une session SSH (pas de confirmation)
sudo ./install_network-manager.sh --yes

# Vérifications après coup
nmcli device status
nmtui                      # configuration interactive d'une interface
ip -br addr show
```

### Codes de retour

| Code | Signification |
|---|---|
| 0 | Succès, ou configuration déjà en place (le script n'a rien modifié). |
| 1 | Option inconnue, netplan détecté sans `--force`, confirmation refusée en session SSH, absence de terminal pour confirmer sans `--yes`, échec de `apt-get update`/`apt-get install`, ou échec du redémarrage de NetworkManager. |

## Section développeur

### Architecture interne

`main()` enchaîne, dans l'ordre :

1. `setup_logging` — bascule stdout/stderr vers un tee (écran + `/var/log/tp-install/install_network-manager.log`) et pose le `trap cleanup EXIT`.
2. `check_prerequisites` — présence d'`apt-get`, garde-fou netplan.
3. `is_already_configured` — quatre conditions (paquet installé, service actif, fragment `managed=true` présent, plus aucune interface dans ifupdown) ; si toutes sont vraies et que `--force` est absent, sortie en code 0.
4. `confirm_if_ssh` — confirmation uniquement si `SSH_CONNECTION`/`SSH_CLIENT` est défini ; placé avant l'installation pour qu'un refus laisse la machine intacte.
5. `install_network_manager` — `apt-get update` puis `apt-get install`, sautés si `dpkg -s` répond.
6. `reset_interfaces_file` — sauvegarde horodatée, réécriture du fichier au loopback, avertissement si `interfaces.d/` n'est pas vide.
7. `configure_nm_snippet` — dépose `conf.d/99-tp-ifupdown-managed.conf`.
8. `check_ifupdown_plugin` — vérifie que le greffon est bien listé dans `NetworkManager.conf` (non bloquant).
9. `restart_network_manager` — `enable`, `restart`, puis état via `nmcli`.
10. `print_summary` — sauvegarde, greffon, journal, procédure de restauration.

Le parsing des arguments et l'élévation de privilèges (auto-relance sudo, Tier 1) ont lieu **avant**, en haut du fichier, hors de toute fonction.

### Détail des choix techniques

- **Un fragment dans `conf.d/` plutôt que la réécriture de `NetworkManager.conf`** : l'ancienne version écrasait intégralement `/etc/NetworkManager/NetworkManager.conf`, détruisant tout réglage local et se faisant écraser en retour à la prochaine mise à jour du paquet. NetworkManager lit `conf.d/` après le fichier principal et les valeurs y sont prioritaires : `99-tp-ifupdown-managed.conf` obtient le même effet sans toucher au fichier de la distribution, et le retirer suffit à revenir en arrière. Le préfixe `99-` garantit qu'il est lu en dernier.
- **Sauvegarde de `/etc/network/interfaces` avant écrasement** : l'ancienne version écrivait le nouveau fichier sans copie préalable. Une VM configurée en IP statique perdait son adresse sans trace, et il fallait la retrouver de mémoire. La sauvegarde est horodatée : une relance ne détruit pas la copie précédente.
- **`apt-get` et non `aptitude`** : l'ancienne version passait par `checkpackage()` de `custom.sh`, qui appelait `aptitude install`. `aptitude` n'est pas installé par défaut sur Debian 12, ce qui faisait échouer l'installation sur une netinst fraîche.
- **Les paquets recommandés sont conservés** (`apt-get install -y network-manager`, sans `--no-install-recommends`, contrairement à `switch-to-networkmanager.sh`) : `wpasupplicant` et `ppp` en font partie, et leur absence ne se remarque qu'au moment où la VM doit servir de client Wi-Fi ou de routeur. Sur une VM de TP le surcoût est négligeable.
- **Garde-fou netplan** : sur une machine Ubuntu, vider `/etc/network/interfaces` ne change rien, puisque c'est netplan qui pilote le réseau — le script donnerait l'illusion d'avoir travaillé. La détection est faite sur la simple présence du binaire, et `--force` permet de passer outre en connaissance de cause.
- **Confirmation limitée à la session SSH** : la bascule coupe brièvement l'interface, ce qui interrompt une session distante. En console (cas normal en TP, et cas de `tp_cli.sh`) aucune question n'est posée, ce qui préserve l'enchaînement non interactif. `--yes` couvre le cas d'un pipeline lancé volontairement en SSH ; sans terminal et sans `--yes`, le script s'arrête plutôt que de bloquer indéfiniment sur un `read`.
- **Les deux mécanismes appliqués ensemble** : vider `/etc/network/interfaces` suffirait presque, `managed=true` seul aussi. Les deux sont posés parce qu'ils couvrent des cas différents — un fragment oublié dans `interfaces.d/` d'un côté, une interface ajoutée à la main de l'autre.
- **`list_ifupdown_interfaces` analyse aussi `interfaces.d/`** : le fichier principal continue de sourcer ce répertoire, un fragment qui y traîne redonnerait la main à ifupdown. La fonction ignore les lignes commentées, de sorte qu'une strophe mise en commentaire ne fasse pas croire que la bascule est incomplète. Le test de présence des fichiers est écrit en bloc `if` et non en `[ -f … ] && …` : sous `set -e`, un test faux sur le dernier élément de la liste ferait sortir la fonction avant l'`awk`, donc renvoyer une liste vide — soit exactement l'inverse du résultat attendu.
- **Idempotence sur quatre conditions et non sur la seule présence du paquet** : une machine où `network-manager` est installé mais où `/etc/network/interfaces` déclare encore `eth0` n'est pas basculée. Tester le paquet seul ferait sortir le script en croyant le travail fait.
- **Plage d'aide délimitée par une expression régulière** (`sed -n '2,/^# =\{10,\}$/p'`) et non par des numéros de ligne comme dans `configure-sudo.sh` : rallonger l'en-tête ne tronque plus l'aide silencieusement.

### Dépendances externes

| Binaire | Version minimale | Fonctionnalité qui l'impose |
|---|---|---|
| `bash` | ≥ 4 | `mapfile`, substitution de processus `>()` de `setup_logging` |
| `sudo` | — | Auto-relance Tier 1 |
| `apt-get`, `dpkg` | — | Installation et détection du paquet `network-manager` |
| `systemctl` (systemd) | — | `enable`, `restart` et `is-active` sur `NetworkManager.service` |
| `nmcli` (paquet `network-manager`) | — | Vérification finale ; absence tolérée, le script saute l'étape |
| `awk`, `sed`, `install` | — | Analyse d'`interfaces`, dépôt des fichiers, trace de log |

### Points d'extension

**Déléguer le DNS à `systemd-resolved`** (comportement de `switch-to-networkmanager.sh` sur Ubuntu), en ajoutant un second fragment dans `configure_nm_snippet` :

```bash
cat > "${NM_CONF_DIR}/98-tp-dns-resolved.conf" <<'EOF'
[main]
dns=systemd-resolved
EOF
chmod 0644 "${NM_CONF_DIR}/98-tp-dns-resolved.conf"
systemctl enable --now systemd-resolved.service
```

**Poser une IP statique juste après la bascule**, pour une VM serveur de TP :

```bash
nmcli connection modify "Connexion filaire 1" \
    ipv4.method manual \
    ipv4.addresses 192.168.1.10/24 \
    ipv4.gateway 192.168.1.254 \
    ipv4.dns "192.168.1.254"
nmcli connection up "Connexion filaire 1"
```

**Vider `interfaces.d/`** plutôt que se contenter d'un avertissement : déplacer les fragments vers `interfaces.d/<nom>.disabled-<horodatage>` dans `reset_interfaces_file`, sur le modèle de ce que fait `switch-to-networkmanager.sh` avec les YAML netplan.

### Notes de maintenance

- Le script ne désactive pas `networking.service` et ne désinstalle pas `ifupdown`. C'est volontaire : le service devient inoffensif une fois le fichier réduit au loopback, et le paquet reste utile pour montrer les deux approches en TP. Conséquence : un fragment déposé plus tard dans `interfaces.d/` reprendra la main sur l'interface concernée.
- Une VM qui avait une **IP statique** dans `/etc/network/interfaces` se retrouve en DHCP après la bascule : NetworkManager crée un profil par défaut pour l'interface libérée. Son adresse change donc, ce qui est sans conséquence en TP mais surprend sur une VM serveur — relire la sauvegarde pour retrouver l'ancienne configuration et la reposer avec `nmcli`.
- L'ancienne adresse peut rester configurée sur l'interface jusqu'au redémarrage : ifupdown ne la relâche pas quand on vide son fichier. D'où le conseil de redémarrage en fin d'exécution.
- `check_ifupdown_plugin` n'est **pas** bloquant. Si la ligne `plugins` disparaissait de `NetworkManager.conf` dans une version future de Debian, le script continuerait en affichant un simple avertissement, et la bascule serait silencieusement incomplète. C'est le premier point à vérifier si des interfaces restent « unmanaged ».
- La trace `/var/log/tp-install/install_network-manager.log` est ouverte en ajout. Prévoir le fichier logrotate décrit dans `CLAUDE.md` si le script est relancé en boucle.
