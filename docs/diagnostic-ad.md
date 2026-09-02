# Diagnostic — utilisateurs AD non visibles après `join-ad.sh`

Procédure à suivre quand un poste est **correctement joint** au domaine
Samba-AD `edgand.fr` mais que `id <utilisateur>` ne trouve aucun compte du
domaine.

Contexte : Kubuntu 26.04, domaine `edgand.fr`, jonction faite par
[`join-ad.sh`](../join-ad.sh).

---

## 1. Comprendre le symptôme

Trois situations très différentes se cachent derrière « les utilisateurs ne
sont pas visibles ». Il faut les distinguer **avant** de corriger quoi que ce
soit.

| Symptôme | Interprétation |
|---|---|
| `id user` fonctionne, `getent passwd` ne les liste pas | **Comportement normal.** SSSD n'énumère pas le domaine par défaut (`enumerate = False`). Les comptes sont pleinement utilisables. |
| `id user` fonctionne, mais les comptes n'apparaissent pas dans l'écran de connexion SDDM | Problème d'affichage du greeter, pas de résolution. Voir §6. |
| `id user` **échoue** | Problème réel de résolution. C'est le cas traité ci-dessous. |

## 2. Cause la plus probable

`realm join` **peut réussir sans que `libnss-sss` et `libpam-sss` soient
installés** : la jonction est effectuée par `adcli`, qui ne passe pas par NSS.

Résultat : le compte machine existe bel et bien côté AD, `realm list` affiche
le domaine, le keytab est présent… mais rien côté système ne sait interroger
SSSD. C'est exactement le tableau « la machine est jointe, aucun utilisateur
n'est visible ».

`join-ad.sh` n'installe aucun paquet : il suppose que la chaîne
NSS/PAM est déjà en place.

## 3. Les deux scripts

### [`diag-ad.sh`](../diag-ad.sh) — lecture seule

Ne modifie **rien**. Collecte l'état complet du poste en 12 sections :

1. Système, noyau, et **horloge** (Kerberos refuse tout ticket au-delà de 5 min de dérive)
2. Paquets installés (`realmd`, `sssd*`, `libnss-sss`, `libpam-sss`, `adcli`…)
3. NSS — lignes `passwd`/`group`/`shadow` de `nsswitch.conf`
4. PAM — profils disponibles et `pam_sss` dans `common-*`
5. realmd — `realm list`, `/etc/realmd.conf`
6. Kerberos — `/etc/krb5.keytab`, `klist -k`, `krb5.conf`
7. Configuration SSSD (secrets masqués), `sssctl config-check`
8. Services et sockets SSSD, journal `journalctl -u sssd`
9. État du domaine — `sssctl domain-status`
10. Résolution des utilisateurs, **en nom court ET en nom complet**
11. DNS et enregistrements SRV vers le contrôleur de domaine
12. Synthèse automatique en OK/KO

Le rapport est écrit dans `/tmp/rapport-ad-<hôte>-<horodatage>.txt`.

### [`fix-ad-nss.sh`](../fix-ad-nss.sh) — correctif

Idempotent, relançable sans risque. Ne rejoint **pas** le domaine : il ne
traite que la visibilité des comptes.

- installe `realmd sssd sssd-tools sssd-ad libnss-sss libpam-sss libsss-sudo
  adcli samba-common-bin krb5-user packagekit` ;
- ajoute `sss` aux lignes `passwd`/`group`/`shadow` de `/etc/nsswitch.conf`
  si absent (sauvegarde horodatée `/etc/nsswitch.conf.bak-<date>`) ;
- active les profils PAM `sss` et `mkhomedir` via `pam-auth-update` ;
- redémarre sssd **en purgeant `/var/lib/sss/db`** — un simple `restart` ne
  suffit pas : les entrées négatives et les anciens UID restent en cache ;
- vérifie la résolution et discrimine lui-même les trois issues (§5).

## 4. Procédure

L'ordre est important : lancer le correctif en premier détruirait
l'information sur l'état laissé par `join-ad.sh`, et la cause réelle
deviendrait indéterminable.

```bash
cd ~/projets/debian_tp_install

sudo ./diag-ad.sh jdupont      # 1) AVANT toute modification
sudo ./fix-ad-nss.sh jdupont   # 2) correctif
sudo ./diag-ad.sh jdupont      # 3) APRÈS, pour comparaison
```

Remplacer `jdupont` par un compte AD réel ; sans argument, les scripts le
demandent de façon interactive.

Les deux scripts suivent le **Tier 1** du [CLAUDE.md](../CLAUDE.md)
(auto-relance `exec sudo "$(readlink -f "$0")"`), donc `sudo` est facultatif
dans les commandes ci-dessus.

Éléments à conserver pour analyse : les **deux** rapports
`/tmp/rapport-ad-*.txt` (avant et après) et la sortie finale de
`fix-ad-nss.sh`.

## 5. Interprétation du résultat

| Résultat après `fix-ad-nss.sh` | Conclusion | Suite |
|---|---|---|
| `id jdupont` répond | C'était bien NSS/PAM. | Terminé. |
| Seul `id jdupont@edgand.fr` répond | `use_fully_qualified_names` a été écrit dans la mauvaise section de `sssd.conf`. | Bug de détection de section dans [`join-ad.sh`](../join-ad.sh) (lignes 82-91) — à corriger. |
| Aucune des deux formes ne répond | Le problème est en amont de NSS. | Sections **6** (Kerberos), **8** (journal sssd) et **11** (DNS/SRV) du rapport. |

## 6. Cas annexe — affichage dans l'écran de connexion SDDM

Si `id user` fonctionne mais que les comptes n'apparaissent pas dans le
greeter Plasma, deux blocages se cumulent :

- SDDM construit sa liste depuis NSS **filtrée par UID**
  (`MinimumUid`/`MaximumUid`, 1000–60000 par défaut). Or avec
  `ldap_id_mapping = True` (défaut de `realm join`), les UID AD sont générés
  à partir des SID et dépassent 1 000 000 000 → hors plage.
- Sans `enumerate = True` dans `sssd.conf`, il n'y a de toute façon aucune
  liste à filtrer.

Sur un poste de TP, la bonne réponse n'est **pas** d'énumérer tout l'AD dans
le greeter, mais de permettre la saisie manuelle du login. Piste à valider
sur une machine, dans `/etc/sddm.conf.d/50-ad.conf` :

```ini
[Theme]
Current=breeze

[Users]
HideUsers=
MaximumUid=2000000000
```

Le comportement exact du thème Breeze de Plasma 6 sur Kubuntu 26.04
(présence ou non d'un champ « Autre… ») reste **à vérifier** avant tout
déploiement en salle.

## 7. Point annexe — attributs RFC2307

Si le Samba-AD publie `uidNumber`/`gidNumber` (fréquent quand l'AD a été
peuplé avec les extensions Unix), le mapping automatique génère des UID qui
ne correspondent pas à ceux du serveur. Il faut alors
`ldap_id_mapping = False` et `ldap_schema = ad` dans `sssd.conf`.

Cela n'empêche pas la résolution des comptes, mais casse les droits sur les
partages. À vérifier côté contrôleur de domaine.
