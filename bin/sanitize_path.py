#!/usr/bin/python
# -*- coding: utf-8 -*-

import os
import sys

path=os.getenv('PATH')

items=path.split(':')

final_list = []
for item in items:
    add=True
    if item in final_list:
        sys.stderr.write('\x1b[0;31;40m' + item + " dupliqué\n" + '\x1b[0m')
        add=False
    if not os.path.isdir(item):
        sys.stderr.write('\x1b[0;31;40m' + item + " n'existe pas\n" + '\x1b[0m')
        add=False
    elif not os.access(item, os.R_OK):
        sys.stderr.write('\x1b[0;31;40m' + item + " non accessible\n" + '\x1b[0m')
        add=False
    if add:
        final_list.append(item)
print(":".join(final_list))

