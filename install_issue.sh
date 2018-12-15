#/bin/sh

. /etc/os-release

text="${NAME} ${VERSION} \\\\n \\l\n"
text="${text}\n"
text="${text}SSH : \\4{enp0s8}\n"


echo -e ${text} > /etc/issue

