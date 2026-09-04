# Vider le cache SSSD

SSSD met en cache les identités (utilisateurs, groupes) et les
identifiants dans `/var/lib/sss/`. C'est ce cache qui permet l'ouverture
de session hors ligne, mais c'est aussi lui qui **retient les anciennes
réponses** — y compris les négatives — après un changement de config ou
côté AD.

Deux méthodes, à choisir selon la gravité du symptôme.

---

## 1. Invalidation logique — `sss_cache`

Marque les entrées comme périmées, sans arrêter le service ni toucher aux
fichiers. Au prochain lookup, SSSD réinterroge l'AD au lieu de servir le
cache.

```bash
sudo sss_cache -E              # invalide tout (users, groups, netgroups...)
sudo sss_cache -u jdupont      # un utilisateur précis
sudo sss_cache -g adminposte   # un groupe précis
```

**Limite à connaître :** `sss_cache` n'efface **pas** les entrées
négatives ni le *memory cache* mmap (`/var/lib/sss/mc/`). Un utilisateur
qui a été résolu comme « inexistant » une fois, ou un ancien UID encore
présent en mémoire, peut survivre à un `sss_cache -E`.

## 2. Purge physique

La seule méthode fiable après un changement de config qui touche au
**format des identités** ou au **mapping d'UID** (`use_fully_qualified_names`,
`ldap_id_mapping`, `override_homedir`…), ou face à des entrées négatives
persistantes.

```bash
sudo systemctl stop sssd
sudo rm -f /var/lib/sss/db/* /var/lib/sss/mc/*
sudo systemctl start sssd
```

Points d'attention :

- **Arrêter sssd avant de supprimer.** Si le démon tourne encore, il garde
  les fichiers ouverts et peut réécrire l'ancien contenu à l'arrêt.
- `/var/lib/sss/db/` — bases LDB (users, groups, credentials mis en cache).
- `/var/lib/sss/mc/` — memory cache mmap, souvent oublié, et c'est lui qui
  continue à servir les vieux UID à NSS même après une purge de `db/`.
- Ça efface aussi les **credentials mis en cache**
  (`cache_credentials = true`) : sur un poste déconnecté du domaine, les
  utilisateurs ne pourront plus ouvrir de session tant que le contrôleur
  n'est pas de nouveau joignable. Sans conséquence sur les postes de TP
  câblés.

C'est exactement ce que fait [`fix-ad-nss.sh`](../fix-ad-nss.sh) (voir
[diagnostic-ad.md](diagnostic-ad.md#3-les-deux-scripts)), qui enchaîne la
purge avec la réactivation des sockets `sssd-nss`/`sssd-pam` et une
vérification finale.

## Quel niveau choisir ?

| Situation | Méthode |
|---|---|
| Nouvel utilisateur AD non visible | `sss_cache -E` |
| Changement d'appartenance à un groupe | `sss_cache -E` (ou `-g <groupe>`) |
| Changement de `use_fully_qualified_names`, `override_homedir`, `ldap_id_mapping` | Purge physique |
| UID/GID qui changent côté AD, entrées négatives qui persistent après `sss_cache -E` | Purge physique |
| `id user@domaine` échoue alors que `wbinfo -u` ou `sssctl domain-status` répond | Purge physique |

---

## Débogage

### Vérifier que la purge a servi à quelque chose

```bash
id jdupont
getent passwd jdupont
getent passwd jdupont@edgand.fr
```

Comparer les trois : voir la table d'interprétation du
[§5 de diagnostic-ad.md](diagnostic-ad.md#5-interprétation-du-résultat) si
le nom court et le nom complet ne se comportent pas pareil.

### État du domaine et de la connectivité

```bash
sudo sssctl domain-status edgand.fr
sudo sssctl domain-status edgand.fr --online     # force un test réseau
```

`domain-status` distingue *online*/*offline* : si SSSD croit être hors
ligne, il sert le cache sans même essayer d'interroger l'AD, quelle que
soit la purge effectuée — vérifier d'abord ça avant d'incriminer le cache.

### Vérification statique d'un compte (`account` PAM)

```bash
sudo sssctl user-checks jdupont
sudo sssctl user-checks jdupont -a auth      # inclut la phase d'authentification
```

Attention : sans `-a auth`, ce test ne déroule que la phase `account` de
PAM. Un compte avec le flag AD « doit changer le mot de passe » peut
répondre `Permission denied` à ce test isolé alors qu'un vrai login
fonctionne normalement — cas rencontré et documenté dans
[journal-ad-N212-32.md](journal-ad-N212-32.md#2026-09-04-plus-tard--tests-en-console-uniquement--rlebonlegay-se-connecte-tout-semble-fonctionner).
Ne pas conclure à un problème de cache sur la seule foi de ce test.

### Suivre le cache en temps réel

```bash
sudo journalctl -u sssd -f
```

Ouvrir ce flux **avant** de reproduire le problème (nouveau login,
`getent`, etc.), pas après — sinon l'événement intéressant est déjà
passé.

Si le niveau de log par défaut ne suffit pas, augmenter temporairement le
niveau de debug dans `/etc/sssd/sssd.conf` (section `[domain/edgand.fr]`
et/ou `[nss]`) :

```ini
debug_level = 7
```

Puis `sudo systemctl restart sssd` et revenir à `debug_level` par défaut
(ou supprimer la ligne) une fois le diagnostic terminé — niveau 7 est
verbeux et écrit vite.

### Inspecter le contenu du cache directement

```bash
sudo ls -la /var/lib/sss/db/
sudo ls -la /var/lib/sss/mc/
```

Présence de fichiers `.mpg`/`.ldb` récents après une purge + redémarrage =
SSSD a bien recréé le cache. Absents ou vieux malgré un `systemctl start`
= le service ne tourne probablement pas (`systemctl status sssd`) ou n'a
pas pu se reconnecter au DC.

### Comparer avant/après sur toute la chaîne

Pour un diagnostic complet plutôt qu'un simple test de cache, utiliser
[`diag-ad.sh`](../diag-ad.sh) (lecture seule) avant et après l'opération :

```bash
sudo ./diag-ad.sh jdupont      # avant
sudo sss_cache -E              # ou purge physique
sudo ./diag-ad.sh jdupont      # après, pour comparaison
```

Voir la procédure complète dans
[diagnostic-ad.md §4](diagnostic-ad.md#4-procédure).

### Piège fréquent : confondre cache et DNS/Kerberos

Si `sss_cache -E` et la purge physique n'apportent **aucun** changement,
le problème n'est probablement pas le cache. Vérifier plutôt :

```bash
sudo klist -k                                  # keytab machine présent ?
host -t SRV _ldap._tcp.edgand.fr               # DNS SRV du contrôleur
sudo realm list                                # jonction toujours active ?
```

Ce sont les sections **6** (Kerberos) et **11** (DNS/SRV) du rapport
`diag-ad.sh` — voir
[diagnostic-ad.md §5](diagnostic-ad.md#5-interprétation-du-résultat).

---

## 3. Mot de passe AD expiré ou à changer — l'étudiant est bloqué à SDDM

Symptôme différent du cache : l'étudiant retape son mot de passe, SDDM
refuse, boucle indéfiniment. Ce n'est en général **pas** un problème de
cache SSSD, mais le flag AD *« l'utilisateur doit changer son mot de passe
à la prochaine connexion »* (compte neuf, ou mot de passe arrivé à
expiration).

### Pourquoi ça bloque précisément à cet écran

Une authentification passe par trois phases PAM enchaînées :

1. **`auth`** — le mot de passe fourni est-il correct ?
2. **`account`** — le compte est-il autorisé (pas verrouillé, pas expiré) ?
3. **`password`** — un changement est-il exigé ?

`pam_sss` relaie chacune de ces phases à `sssd`, qui les traduit en
échanges Kerberos avec le contrôleur de domaine. Quand le KDC répond
« mot de passe expiré » ou « changement obligatoire », PAM ne se contente
pas d'ajouter un champ : il ouvre une **conversation interactive** à
plusieurs prompts successifs (`Current password:`, `New password:`,
`Retype new password:`). C'est au **client PAM** — pas à SSSD — de savoir
dérouler cette conversation à l'écran.

`login` (console TTY) et OpenSSH gèrent nativement ces prompts multiples.
Le greeter Breeze de SDDM ne les affiche pas : il attend un unique champ
mot de passe. Ce n'est pas une erreur de configuration NSS/PAM/SSSD —
`diag-ad.sh` rapportera un poste parfaitement sain — c'est une limitation
du greeter lui-même, documentée dans
[diagnostic-ad.md §6](diagnostic-ad.md#6-cas-annexe--affichage-dans-lécran-de-connexion-sddm)
et observée en conditions réelles dans
[journal-ad-N212-32.md](journal-ad-N212-32.md).

### Débloquer l'étudiant : canaux qui ne passent pas par SDDM

Point clé : `Ctrl+Alt+F3` n'ouvre pas un terminal dans une session
existante, c'est un **second écran de connexion**, indépendant de SDDM et
servi par `login`(1). L'étudiant s'y authentifie avec son mot de passe
initial, et c'est PAM — pas le greeter — qui enchaîne sur le changement.

| Canal | Commande | Où l'exécuter | Prérequis |
|---|---|---|---|
| Console TTY (`login`) | se connecter normalement, suivre l'invite | Sur le poste : `Ctrl+Alt+F3` puis, une fois fait, `Ctrl+Alt+F1` (ou F7) pour revenir à SDDM | Aucun — chemin standard, toujours disponible |
| `kpasswd` | `kpasswd etudiant@EDGAND.FR` | N'importe quel shell : session du prof sur ce poste, autre TTY, poste distant | Paquet `krb5-user` ; port 464 (TCP+UDP) ouvert vers le DC |
| `smbpasswd -r` | `smbpasswd -r <DC> -U etudiant` | Idem | Paquet `samba-common-bin` |
| SSH vers le poste | `ssh etudiant@nom-du-poste` | Depuis une autre machine du labo | `openssh-server` actif sur le poste, `KbdInteractiveAuthentication yes` dans `sshd_config` |
| Poste Windows joint (si le labo en compte) | `Ctrl+Alt+Suppr` → *Changer le mot de passe* | Sur ce poste Windows | Le poste doit être joint au même domaine |

`kpasswd` mérite d'être retenu en priorité pour un dépannage rapide en
salle : il demande l'ancien mot de passe puis le nouveau, dialogue
directement avec le KDC, **fonctionne même si l'ancien est expiré**, et ne
nécessite qu'un shell quelconque — pas une session de l'étudiant
lui-même. Un enseignant peut donc débloquer un compte depuis sa propre
session, sans toucher à l'AD.

`passwd` (sans arguments) fait la même chose mais **exige une session déjà
ouverte** — utile pour un changement volontaire une fois connecté,
inutilisable pour débloquer un compte qui n'a encore jamais réussi à se
connecter.

Une fois le mot de passe changé par n'importe lequel de ces canaux, le
flag AD est levé **définitivement** : l'étudiant se reconnecte
normalement via SDDM, plus aucun blocage.

### Faut-il changer la configuration du poste ?

Non, dans le cas général. Cette limitation vient du greeter Breeze
lui-même, pas d'un défaut de jonction ou de SSSD — un `diag-ad.sh` propre
sur le poste concerné suffit à l'écarter. Vous restant sur SDDM/Breeze
(choix confirmé), ce tableau **est** la procédure de dépannage standard à
appliquer, pas un contournement temporaire.

Deux signaux qui, eux, justifieraient d'agir sur la configuration plutôt
que de répéter la procédure à chaque fois :

- **Ça se reproduit à chaque nouveau compte** plutôt qu'occasionnellement
  → envisager de lever le flag « doit changer le mot de passe » côté AD
  au moment de la création des comptes étudiants, pour ne jamais
  atterrir dans ce cas de figure en salle.
- **Un compte pourtant déjà utilisé se remet à boucler** → ce n'est
  probablement plus ce problème-ci ; repartir sur le cache (§1-2
  ci-dessus) ou un `diag-ad.sh` complet.

### Trancher définitivement : PAM/SSSD ou greeter ? (`pamtester`)

Le doute qui reste après tout ce qui précède : est-ce vraiment le greeter
Breeze qui ne relaie pas la conversation de changement de mot de passe,
ou une case de configuration PAM oubliée sur ce poste précis ?
`pamtester` permet de trancher **sans passer par un vrai login SDDM**, en
rejouant le fichier `/etc/pam.d/sddm` réel du poste depuis un terminal.

```bash
sudo apt install pamtester   # non installé par défaut
```

```bash
sudo pamtester -v sddm etudiant_test authenticate
sudo pamtester -v sddm etudiant_test acct_mgmt
sudo pamtester -v sddm etudiant_test chauthtok
```

Utiliser un compte AD réellement marqué « doit changer le mot de passe »
pour que le test ait un sens — pas un compte déjà valide.

Lecture des trois résultats :

| Commande | Résultat attendu | Si absent/différent |
|---|---|---|
| `authenticate` | Réussit avec l'ancien mot de passe | Le mot de passe fourni est faux, ou `pam_sss` n'est pas dans `/etc/pam.d/sddm` — pas un sujet greeter. |
| `acct_mgmt` | Échoue en signalant `PAM_NEW_AUTHTOK_REQD` (visible dans la trace `-v`, ligne `pam_sss`) | Si ça réussit sans le signaler, le flag AD n'est peut-être pas celui qu'on croit — vérifier côté AD (`samba-tool user show`). |
| `chauthtok` | Propose `Current password:` / `New password:` / `Retype new password:` **dans ce terminal**, et le changement aboutit | Échec ou absence de prompt → vrai problème de config : `/etc/pam.d/sddm` sans `@include common-password`, ou `pam_sss` absent de `common-password`. |

**Interprétation :**

- Les trois étapes réussissent en ligne de commande → la chaîne
  PAM/SSSD est prouvée correcte pour le service `sddm` sur ce poste. Le
  blocage observé à l'écran est alors **forcément** un défaut de rendu du
  greeter Breeze (il ne relaie pas les prompts de `chauthtok`, contrairement
  au terminal de `pamtester`) — pas une configuration à corriger.
- `chauthtok` échoue ou ne propose aucun prompt → configuration PAM
  réellement fautive sur ce poste. Comparer `/etc/pam.d/sddm` avec un
  poste sain, et vérifier la présence de `pam_sss` dans
  `/etc/pam.d/common-password` (section 4 du rapport `diag-ad.sh`).

À noter : `pamtester` fournit sa **propre** conversation en terminal, pas
celle de SDDM/Qt. Un `chauthtok` réussi ici prouve que PAM/SSSD font
correctement leur travail — il ne prouve pas que le greeter Breeze
afficherait la même chose à l'écran. C'est justement cette distinction qui
permet de trancher entre « à corriger sur ce poste » et « limitation du
greeter, procédure de contournement à appliquer » (§3 ci-dessus).
