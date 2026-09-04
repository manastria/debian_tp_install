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
