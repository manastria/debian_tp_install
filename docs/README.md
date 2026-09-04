# Documentation

Index du répertoire `docs/`. **Toute page ajoutée ici doit être référencée
ci-dessous** ; une page absente de cet index est considérée comme oubliée.
Une page dont le script est supprimé disparaît de `docs/` et de cet index.

Convention : une page Markdown par script, nommée d'après le script **sans
son extension** (`install_tp.sh` → `install_tp.md`). Les liens vers les
scripts s'écrivent en relatif depuis `docs/` : `../install_tp.sh`.
La structure imposée pour chaque page est décrite dans
[CLAUDE.md](../CLAUDE.md), section *Documentation des scripts*.

## Pages de scripts

- [`configure-sudo.sh`](configure-sudo.md) — groupes sudo de labo (`adminpwd` avec mot de passe, `admins` sans).
- [`install_eth0.sh`](install_eth0.md) — noms d'interfaces classiques (`eth0`) via `net.ifnames=0` dans GRUB, sur Debian.
- [`install_network-manager.sh`](install_network-manager.md) — bascule du réseau Debian d'ifupdown vers NetworkManager.
- [`install_virt.sh`](install_virt.md) — outils invité selon l'hyperviseur détecté (VirtualBox, VMware).
- [`make_rclocal.sh`](make_rclocal.md) — relais `rc.local` de réinitialisation au premier démarrage d'un clone.
- [`prepare-ova-export.sh`](prepare-ova-export.md) — nettoyage complet, zerofill et armement du relais avant export en `.ova`.

---

Les pages consacrées au domaine Active Directory (`diagnostic-ad.md`,
`journal-ad-N212-32.md`, `cache-sssd.md`) ont été transférées vers le dépôt
`reseau-labo-provisioning`, dédié aux machines physiques du labo. Il n'y a
pas d'AD sur les VM de TP.
