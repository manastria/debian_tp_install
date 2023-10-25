# Installation d'une VM Debian 11


### Initialisation


```console
apt install -y git zsh vim yadm aptitude pip pipenv python3-yaml
```

### Cloner le dépôt

```console
git clone git@bitbucket.org:manastria/debian_tp_install.git
```

Pour affichier les branches :
```
git branch -a
```

Pour suivre une branche :
```console
git checkout -b debian-11 origin/debian-11
git checkout -b debian-12 origin/debian-12
```



## Installation

```
# ./tp_cli.sh
```
/!\ Installer Network Manager tout de suite avant de rebooter, sinon, il faudra configurer le réseau manuellement !
```
./install_network-manager.sh
```




### yadm

Ne pas s'occuper d'yadm : c'est le script baseV10.zsh

```
# yadm clone https://github.com/manastria/dotfile.git
# yadm clone git@github.com:manastria/dotfile.git


# yadm remote set-url origin git@github.com:manastria/dotfile.git
```

```
yadm reset --hard origin/master
```


### baseV12



## Gestion des dépôts Git

### Modifier les dépôts pour pousser

Modification du dépôt `debian_tp_install` :

```
git remote set-url --push origin git@bitbucket.org:manastria/debian_tp_install.git
```

Modification du dépôt **yadm** :

```
yadm remote set-url --push origin git@bitbucket.org:manastria/dotfile.git
```

## Network Manager

Vérifier qu'il y a du réseau. Sinon remplacer `ens33` par `eth0` dans le fichier `/etc/network/interfaces`. Puis relancer le réseau avec `/etc/init.d/networking restart`
