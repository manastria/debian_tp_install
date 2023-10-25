# yadm_helper.sh

yadm_url="https://github.com/manastria/dotfile.git"

yadm_manage() {
    if [ -d "$HOME/.config/yadm" ]; then
        echo "yadm already installed"
        yadm pull
    else
        yadm clone $yadm_url
    fi

    yadm reset --hard origin/master
}
