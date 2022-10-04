#!/bin/bash
# GPL v3
########################################################
### CONFIG
## main
main_prefix=/apps
#
## lua
lua_version="5.1.4.9"
lua_prefix=$main_prefix/dependencies/lua
#
## Lmod
lmod_version="8.5"
lmod_prefix=$main_prefix/dependencies
lmod_libexec=$lmod_prefix/lmod/$lmod_version/libexec
lmod_init_bash=$lmod_prefix/lmod/$lmod_version/init/bash
lmod_cmd=$lmod_prefix/lmod/$lmod_version/libexec/lmod
#
## EasyBuild
# latest version
eb_tmpdir="EB_TMPDIR=/tmp/$USER/eb_tmp"
easybuild_prefix=$main_prefix
easybuild_config=$HOME/.config/easybuild
easybuildrc=$main_prefix/dependencies/easybuildrc
## colors
#
color_ok='\033[0;32m'
color_pending='\033[1;33m'
color_eb='\033[0;34m'
color_end='\033[0m'
#
## functions
pending ()
{
	echo -e "${color_pending}$@${color_end}"
}
#
okay ()
{
	echo -e "${color_ok}[OK]${color_end}"
}
#
easybuild ()
{
	echo -e "${color_eb}$@${color_end}"
}
#
########################################################
# for Debian clean install

if [ $EUID == 0 ]
then 
	echo "Running as root; exiting..."
	exit 255
fi

pending "Cleaning up directories..."
rm -rf $main_prefix $easybuild_config $EB_TMPDIR /tmp/eb-* && okay

pending "Installing dependencies..."
sudo apt install -y wget gcc make rsync tclsh tcl-dev libreadline-dev libibverbs-dev python3-pip xdot 1>/dev/null 2>&1 && okay

pending "Installing non-essential python dependencies..."
python3 -m pip install python-graph-core python-graph-dot archspec autopep8 GitPython pep8 pycodestyle Rich setuptools 1>/dev/null 2>&1 && okay || exit 1

if [ ! -f "lua-${lua_version}.tar.bz2" ]; then
	pending "Downloading lua..."
	wget -q -O "lua-${lua_version}.tar.bz2" "https://sourceforge.net/projects/lmod/files/lua-${lua_version}.tar.bz2/download" && okay || exit 2
fi

pending "Extracting lua..."
tar xjf "lua-${lua_version}.tar.bz2" && okay || exit 3

pending "Compiling lua..."
cd "lua-${lua_version}"
./configure --quiet --with-static=yes --prefix=$lua_prefix 1>/dev/null 2>&1 && make --quiet 1>/dev/null 2>&1 && make --quiet install 1>/dev/null 2>&1 && export PATH=$lua_prefix/bin:$PATH && okay || exit 4
cd ../

if [ ! -f "Lmod-${lmod_version}.tar.bz2" ]; then
	pending "Downloading Lmod..."
	wget -q -O "Lmod-${lmod_version}.tar.bz2" "https://sourceforge.net/projects/lmod/files/Lmod-${lmod_version}.tar.bz2/download" && okay || exit 5
fi

pending "Extracting Lmod..."
tar xjf "Lmod-${lmod_version}.tar.bz2" && okay || exit 6

pending "Compiling Lmod..."
cd "Lmod-${lmod_version}"
./configure --quiet --prefix=$lmod_prefix 1>/dev/null 2>&1 && make --quiet install 1>/dev/null 2>&1 && okay || exit 7
cd ../

pending "Setting up PATH..."
echo "# $easybuildrc: EasyBuild environment file" > $easybuildrc
{ echo "export EB_PYTHON=python3"; echo ""; echo "# Lmod environment"; } >> $easybuildrc
{ echo "export PATH=$lmod_prefix:\$PATH"; echo "source $lmod_init_bash"; echo "export LMOD_CMD=$lmod_cmd"; } >> $easybuildrc
grep -qxF "if [ -f $easybuildrc ]; then source $easybuildrc; fi" /etc/profile || \
	sudo -i bash -c "{ echo \"\"; echo \"# EasyBuild Environment\"; echo \"if [ -f $easybuildrc ]; then source $easybuildrc; fi\"; } >> /etc/profile"
. $easybuildrc && okay

echo ""
easybuild "###################################"
easybuild "Installing EasyBuild with EasyBuild"
easybuild "###################################"
echo ""
pending "Making a temporary EasyBuild installation in /tmp..."
export $eb_tmpdir
python3 -m pip install --ignore-installed --prefix $EB_TMPDIR easybuild 1>/dev/null 2>&1 && okay || exit 8

pending "Updating the environment..."
export PATH=$EB_TMPDIR/bin:$PATH
export PYTHONPATH=$(/bin/ls -rtd -1 $EB_TMPDIR/lib*/python*/site-packages | tail -1):$PYTHONPATH
export EB_PYTHON=python3
okay

pending "Generating EasyBuild configuration..."
mkdir -p $easybuild_config
cat > $easybuild_config/config.cfg <<EOF
[MAIN]

[basic]
locks-dir=$main_prefix/.locks/
#robot=$main_prefix/easybuild-easyconfigs/easybuild/easyconfigs
robot-paths=$main_prefix/easybuild-easyconfigs/easybuild/easyconfigs

[config]
buildpath=$main_prefix/build
installpath=$main_prefix
installpath-modules=$main_prefix/modules
installpath-software=$main_prefix/all
moduleclasses=python
repository=FileRepository
repositorypath=$main_prefix/file-repository
sourcepath=$main_prefix/sources

[easyconfig]
local-var-naming-check=error

[override]
detect-loaded-modules=purge
dump-autopep8=True
enforce-checksums=True
silence-deprecation-warnings=True
trace=True
wait-on-lock-interval=600
EOF
okay

pending "Installing EasyBuild module with EasyBuild..."
eb --install-latest-eb-release --prefix $easybuild_prefix && okay || exit 9

pending "Downloading current easyconfigs..."
cd $main_prefix && git clone https://github.com/easybuilders/easybuild-easyconfigs.git && cd - && okay || exit 10

pending "Setting up environment..."
echo "" >> $easybuildrc
echo "# tell Lmod where to search for modules" >> $easybuildrc
#
cat >> $easybuildrc <<EOF
if [ "\$(id -u)" -ne 0 ]; then
    MODULEPATH=""

    for dir in $easybuild_prefix/modules/*
    do
        # Exclude following directories
        if [[ (\${dir##*/} == "all") ]]; then
            continue
        fi
        # In case that it's a directory
        if [ -d "\$dir" ]; then
            if [ -z "\$MODULEPATH" ]; then
                MODULEPATH="\$dir"
            else
                MODULEPATH="\$MODULEPATH:\$dir"
            fi
        fi
    done

    export MODULEPATH
fi
EOF

{ echo "setenv(\"EASYBUILD_ROBOT_PATHS\", \"$main_prefix/easybuild-easyconfigs/easybuild/easyconfigs\")"; echo "add_property(\"lmod\", \"sticky\")"; } >> $(find $easybuild_prefix/modules/all/EasyBuild/ -name *.lua)

# make easybuild autoresolve dependencies
sed -i 's/#//' $easybuild_config/config.cfg
okay

pending "Cleaning up..."
yes | rm -r "lua-${lua_version}.tar.bz2" "lua-${lua_version}/" "Lmod-${lmod_version}.tar.bz2" "Lmod-${lmod_version}/" "$EB_TMPDIR"
okay

echo ""
pending "Installation complete."
echo ""
easybuild "To load the EasyBuild module, use"
easybuild "  module load EasyBuild"
echo ""
easybuild "Do not forget to reload your environment."
echo ""
