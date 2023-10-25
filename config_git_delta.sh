#!/usr/bin/env bash

git config --file ${HOME}/.gitconfig.local core.pager "delta"
git config --file ${HOME}/.gitconfig.local interactive.diffFilter "delta --color-only"

git config --file ${HOME}/.gitconfig.local delta.navigate "true"
git config --file ${HOME}/.gitconfig.local delta.light "false"

git config --file ${HOME}/.gitconfig.local merge.conflictstyle "diff3"

git config --file ${HOME}/.gitconfig.local diff.colorMoved "default"
