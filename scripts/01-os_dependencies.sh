#!/bin/sh
sudo apt install -y wget gcc make rsync tclsh tcl-dev libreadline-dev libibverbs-dev python3-pip xdot
python3 -m pip install --upgrade python-graph-core python-graph-dot archspec autopep8 GitPython pep8 pycodestyle Rich setuptools
