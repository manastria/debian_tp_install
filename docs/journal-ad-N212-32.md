# Journal de diagnostic AD — poste N212-32

Suivi au fil de l'eau de la session de diagnostic AD sur le poste `N212-32`
(domaine `edgand.fr`). Complète [`diagnostic-ad.md`](diagnostic-ad.md) (qui
décrit la procédure générale) : ce fichier trace ce qui a été **observé et
conclu sur cette machine précise**, dans l'ordre chronologique.

Format : une entrée par étape, avec un statut à la fin de chaque entrée.
Statuts utilisés : 🟢 résolu / normal — 🟡 à surveiller, pas bloquant — 🔴
problème ouvert.

---

## 2026-09-04 — Rapport initial `diag-ad.sh`

Fichier analysé : `rapport-ad-N212-32-20260904-094114.txt` (exécution de
[`diag-ad.sh`](../diag-ad.sh) avec `ylassaoui` / groupe `adminposte`).

### Ce que dit la synthèse automatique (section 12 du rapport)

Tout est vert : paquets présents, `nsswitch.conf` correct, `pam_sss` actif,
service `sssd` actif, keytab présent, section `[domain/edgand.fr]` présente,
`use_fully_qualified_names = False` appliqué, `id ylassaoui` et
`id ylassaoui@edgand.fr` résolvent tous les deux.

**Important** : cette synthèse ne teste que la résolution NSS (`id`,
`getent`). Elle ne teste pas l'autorisation réelle de connexion. Voir la
distinction faite dans [diagnostic-ad.md, §1](diagnostic-ad.md#1-comprendre-le-symptôme).

### Point relevé en lecture manuelle (section 10 du rapport)

```
$ sssctl user-checks ylassaoui
pam_acct_mgmt: Permission denied
```

Repéré à première lecture comme suspect : NSS résout bien l'utilisateur
(uid/gid/gecos corrects), mais la phase `account` de PAM le refuse — ce qui
aurait pu vouloir dire que la connexion réelle échoue malgré un `id` qui
répond.

**Corrélé aux logs journalctl (section 8)** : plusieurs entrées
`krb5_child: Password has expired` le 04/09 entre 08:46:23 et 08:47:26.

### Clarification apportée par l'utilisateur

Le compte `ylassaoui` est **OK** : c'est sa toute première connexion sur le
domaine, et AD impose un changement de mot de passe à la première connexion
(`pwdLastSet = 0` côté AD). Le `pam_acct_mgmt: Permission denied` et les
`Password has expired` du journal correspondent à ce mécanisme normal, pas à
un défaut de jonction / NSS / PAM.

**Statut : 🟢 résolu.** Pas d'action requise sur `fix-ad-nss.sh` pour ce
point — la cause n'était pas dans la chaîne NSS/PAM.

Point resté ouvert pour une prochaine session si besoin : confirmer que le
poste (SDDM / greeter) propose bien une invite de changement de mot de passe
à la première connexion plutôt qu'un simple rejet silencieux — pas encore
vérifié.

### Points annexes relevés dans le même rapport, sans rapport avec le sujet ci-dessus

- 🟡 `sssctl config-check` (section 7) signale une erreur : `Attribute
  'config_file_version' is not allowed in section 'sssd'`. Code retour non
  nul. À vérifier — possible faux positif du validateur `sssctl`, à confirmer
  sur une version de référence de `sssd.conf`.
- 🟡 `libsss-sudo` non installé (section 2, `[un ]`). Sans impact sur la
  résolution des comptes ; à installer seulement si des règles `sudo`
  doivent être portées par des groupes AD (ex. `adminposte`).
- 🟡 `krb5_child[8850]: Preauthentication failed` à 09:33:16, isolé, sans
  lien identifié avec le diagnostic lui-même (ni `id` ni `sssctl
  user-checks` ne déclenchent normalement de `krb5_child`). Pourrait être
  une tentative de connexion concurrente sur le poste au même moment. Pas de
  conclusion tirée faute de contexte — à surveiller si le symptôme
  réapparaît.

---

## 2026-09-04 — Suite : connexion confirmée fonctionnelle

L'utilisateur `ylassaoui` ne pouvait pas se connecter au moment du rapport,
et la connexion fonctionne maintenant.

### Reconstitution à partir des logs `journalctl -u sssd` du rapport

1. **08:46:23 – 08:47:26** : premières tentatives de connexion →
   `krb5_child: Password has expired` (x5). Le KDC AD refuse la préauth
   Kerberos car le compte a le flag *« doit changer le mot de passe à la
   prochaine ouverture de session »* — comportement normal pour un compte
   fraîchement créé.
2. **09:41 (au moment du diagnostic)** : `sssctl user-checks` affiche
   encore `pam_acct_mgmt: Permission denied`. Cohérent : ce test est une
   vérification statique de l'état du compte, pas une authentification
   interactive — il reflète l'état « mot de passe non changé » tant que le
   changement obligatoire n'a pas été effectué via un vrai flux de
   connexion.
3. Le changement de mot de passe a depuis été effectué → le flag AD est
   levé → l'authentification passe normalement.

### Conclusion

Le blocage était **côté AD** (politique de changement de mot de passe
obligatoire à la première connexion), pas dans la chaîne NSS/PAM/SSSD du
poste `N212-32`. `join-ad.sh` et `fix-ad-nss.sh` n'ont pas de responsabilité
ici ; pas de nouvelle exécution nécessaire pour ce point.

**Statut : 🟢 résolu / comportement attendu.**

### Reste à vérifier

Confirmer **par quel moyen** le changement de mot de passe a abouti :

- si via l'écran de connexion SDDM/Breeze → bon signe, le greeter gère le
  flux de changement obligatoire pour les futurs comptes de TP (répond
  aussi au point ouvert du [§6 de diagnostic-ad.md](diagnostic-ad.md#6-cas-annexe--affichage-dans-lécran-de-connexion-sddm)) ;
  si via un autre moyen (SSH, `kinit`, réinitialisation côté AD) → SDDM ne
  gère probablement pas ce flux nativement, et il faudra soit lever le flag
  côté AD avant de distribuer les comptes de TP, soit documenter une
  procédure de contournement pour les étudiants.

> **⚠️ Conclusion révisée par l'entrée suivante (10:00) : le statut 🟢 et
> l'hypothèse « comportement normal qui se résorbe tout seul » ne tiennent
> plus.** Un deuxième compte reproduit le même blocage sans se corriger via
> le même chemin de connexion. Voir ci-dessous.

---

## 2026-09-04 10:00 — Deuxième rapport, compte `rlebonlegay` : le blocage ne se résorbe PAS tout seul

Fichier analysé : `rapport-ad-N212-32-20260904-100050.txt` (même poste,
compte de test différent : `rlebonlegay`).

### Constat

Même symptomatique exacte que `ylassaoui` : synthèse automatique tout
vert, `id`/`getent` résolvent, mais `sssctl user-checks rlebonlegay` →
`pam_acct_mgmt: Permission denied`, avec dans le journal :

```
09:55:19  krb5_child: Password has expired
09:55:22  krb5_child: Password has expired
09:58:16  krb5_child: Password has expired
09:59:58  krb5_child: Password has expired
```

4 tentatives échouées sur ~4,5 minutes, puis toujours bloqué au moment du
rapport (10:00:50). **Confirmé par l'utilisateur : ça ne fonctionne ni
avant ni après ce diagnostic.**

Ceci contredit l'hypothèse de l'entrée précédente (09:41) : le blocage
« mot de passe à changer à la première connexion » **ne se résout pas tout
seul** en retapant son mot de passe à l'écran de connexion — c'est une
boucle, pas une étape qui se termine normalement.

### Conclusion révisée

**Hypothèse retenue :** le flag AD *« doit changer le mot de passe à la
prochaine connexion »* déclenche bien un rejet Kerberos (`Password has
expired`, `KRB5KDC_ERR_KEY_EXP`) côté KDC — c'est confirmé et normal pour
un compte neuf. Le problème est que **l'écran de connexion SDDM/Breeze ne
semble pas proposer le dialogue de changement de mot de passe** à ce
moment (flux PAM `PAM_NEW_AUTHTOK_REQD` → `pam_chauthtok`, non géré par le
greeter). L'utilisateur voit juste un échec de connexion, retape le même
mot de passe, boucle indéfiniment sans jamais pouvoir le changer par ce
chemin.

Pour `ylassaoui` (entrée précédente), impossible désormais d'affirmer que
SDDM a géré le changement correctement — le plus probable, vu le
comportement identique et non auto-résolutif de `rlebonlegay`, est qu'une
intervention manuelle (réinitialisation du mot de passe côté AD, ou
changement effectué par un autre canal que SDDM) a débloqué le compte
entre-temps. **Le statut 🟢 précédemment mis pour `ylassaoui` est donc
retiré, mécanisme non confirmé.**

**Statut global : 🔴 problème ouvert.** Pas un défaut de jonction ni de
NSS/PAM/SSSD (config strictement identique et correcte sur les deux
rapports) — le blocage est dans le parcours de connexion interactif
(probablement SDDM) qui ne sait pas gérer un mot de passe AD expiré /
à changer à la première connexion.

### Actions à mener

1. **Tester un chemin de connexion hors SDDM** pour `rlebonlegay` :
   console texte (`Ctrl+Alt+F3` → `login`) ou `ssh rlebonlegay@N212-32`.
   Si le changement de mot de passe est proposé par ce chemin, ça confirme
   que SDDM est bien le point de blocage spécifique.
2. **Contournement immédiat pour le TP** : lever le flag « doit changer le
   mot de passe » côté AD (ou fixer un mot de passe déjà valide) pour les
   comptes de test/étudiants avant la séance, plutôt que de compter sur
   l'écran de connexion pour gérer ce flux.
3. `diag-ad.sh` / `fix-ad-nss.sh` ne sont **pas** l'outil ici : la chaîne
   NSS/PAM/SSSD est correcte sur les deux rapports, le sujet est côté
   politique de mot de passe AD + comportement du greeter.

> **⚠️ Hypothèse SDDM invalidée par l'entrée suivante : tous les tests ont
> été faits en console texte uniquement, jamais via SDDM.** Voir
> ci-dessous.

---

## 2026-09-04, plus tard — Tests en console uniquement : `rlebonlegay` se connecte, tout semble fonctionner

L'utilisateur confirme avoir fait **tous ses tests en console texte**
(`login` sur TTY), jamais via SDDM. Donc l'hypothèse « SDDM ne gère pas le
changement de mot de passe » n'a en réalité jamais été testée et ne peut
plus être retenue comme explication — elle est abandonnée.

Constat actuel : `rlebonlegay` arrive maintenant à se connecter en
console, et « tous les logins semblent passer sans problème ». Aucune
action corrective explicite n'a été identifiée entre le blocage et la
résolution.

### Réinterprétation

`sssctl user-checks` ne teste **que** la phase `account` de PAM
(`pam_acct_mgmt`) de façon statique, sans jamais dérouler une vraie
authentification. Un compte AD avec le flag *« changement de mot de passe
obligatoire à la prochaine connexion »* peut répondre `Permission denied`
à ce test isolé, alors qu'un vrai login (séquence complète auth → account
→ password, avec la conversation interactive de changement de mot de
passe) aboutit normalement via `login` en console — qui gère correctement
ce flux PAM. Une fois le mot de passe effectivement changé, le flag AD est
levé définitivement et tout redevient normal, ce qui correspond à ce qui
est observé.

**Ce qui reste flou** : pourquoi les toutes premières tentatives (5 pour
`ylassaoui`, 4 pour `rlebonlegay`, en quelques minutes) échouaient toutes
avant que ça passe. Sans avoir observé l'écran en direct au moment des
faits (mauvais mot de passe initial retapé plusieurs fois ? prompt de
changement pas repéré par l'utilisateur ? autre chose ?), impossible de
trancher avec certitude à partir des seuls logs `journalctl`.

**Statut : 🟡 fonctionnel mais mécanisme pas totalement élucidé.** Pas de
piste SDDM ni de piste NSS/PAM/SSSD à poursuivre — la chaîne technique est
correcte. Reste à confirmer que c'est un comportement AD généralisé et
reproductible (donc à anticiper pour tous les étudiants du TP) plutôt
qu'un hasard propre à ces deux comptes.

### Protocole de debug pour les autres postes

À appliquer avec un compte AD **neuf** (jamais connecté) pour observer la
séquence en direct au lieu de la reconstituer après coup :

1. Avant de commencer : noter l'état initial du compte côté AD si possible
   (`samba-tool user show <user>` ou ADUC — `pwdLastSet` / case « doit
   changer le mot de passe »).
2. Pendant le premier login, ouvrir un **second terminal/TTY** et lancer
   `sudo journalctl -u sssd -f` pour suivre la séquence en direct.
3. **Observer précisément ce qui s'affiche à l'écran** pendant la
   tentative : un prompt `Password expired. Change your password now.` /
   `New password:` apparaît-il vraiment, et à quel moment ? C'est
   l'information qui a manqué pour trancher sur `N212-32`.
4. Juste après un login réussi, relancer immédiatement
   `sssctl user-checks <user>` (ou `diag-ad.sh`) pour vérifier si
   `Permission denied` a disparu — confirme que c'était bien le gate
   « changement obligatoire » et rien d'autre.
5. Reproduire sur un ou deux autres postes pour voir si le même schéma se
   répète à l'identique.

---

<!--
Prochaine entrée : ajouter une section datée ci-dessous à chaque nouvelle
exécution de diag-ad.sh / fix-ad-nss.sh ou nouvelle observation sur ce poste.
-->
