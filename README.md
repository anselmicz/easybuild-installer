# easybuild-installer
Installation script for [EasyBuild](https://github.com/easybuilders/easybuild) - software build and installation framework.

Parts taken from [EasyBuild](https://docs.easybuild.io/), and [Lmod](https://lmod.readthedocs.io/) documentations.

## What it does

* creates local installation of EasyBuild, by default under `$HOME/.local/EasyBuild`, and compiles the Lmod and Lua dependencies
* downloads newest easyconfigs, and adds their path to the EasyBuild module file
* separates the module list into communities

## Usage

```
sudo apt update && sudo apt upgrade -y
git clone https://github.com/anselmicz/easybuild-installer.git
cd easybuild-installer/
chmod +x easybuild.sh && ./$_
cd - && rm -rf easybuild-installer/
```
