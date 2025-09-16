It's been some time since I last used this project... the time has come to let go.

# easybuild-installer
Installation script for [EasyBuild](https://github.com/easybuilders/easybuild) - software build and installation framework.

Parts taken from [EasyBuild](https://docs.easybuild.io/), and [Lmod](https://lmod.readthedocs.io/) documentations.

## What it does

* creates system-wide installation of EasyBuild, by default under `/apps`, and compiles the Lmod and Lua dependencies
* patches system Python prefix scheme if necessary to avoid errors on newer versions (and then reverts it back to its original state once finished)
* downloads newest easyconfigs, and adds their path to the EasyBuild module file
* separates the module list into communities

## Usage

```
sudo apt update && sudo apt upgrade -y
git clone https://github.com/anselmicz/easybuild-installer.git
cd easybuild-installer/
./wrapper.sh | tee build.log
cd - && rm -rf easybuild-installer/
```
