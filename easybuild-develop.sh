#!/bin/bash
# GPL v3
########################################################
### CONFIG
## main
main_prefix=/apps
#
## lua
lua_version="5.4.4"
luaposix_version="35.1"
lua_prefix=$main_prefix/dependencies/lua
lua_modules="$lua_prefix/share/lua/${lua_version:0:3}/?.lua;$lua_prefix/share/lua/${lua_version:0:3}/?/init.lua;;"
lua_libs="$lua_prefix/lib/lua/${lua_version:0:3}/?.so;;"
#
## Lmod
lmod_version="8.7.14"
lmod_prefix=$main_prefix/dependencies
lmod_spidercachedir=$lmod_prefix/moduleData/cacheDir
lmod_updatesystemfn=$lmod_prefix/moduleData/system.txt
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
## CUDA
cuda_cc="8.6"
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

## Root check
if [ $EUID == 0 ]
then
	echo "Running as root; exiting..."
	exit 255
fi

## Cleaning up
pending "Cleaning up directories..."
export $eb_tmpdir
rm -rf $main_prefix $easybuild_config $EB_TMPDIR && okay

## Install system dependencies
pending "Installing dependencies..."
sudo apt install -y wget gcc make rsync tclsh tcl-dev libreadline-dev libibverbs-dev python3-pip xdot && okay

## Install pip dependencies
pending "Installing non-essential python dependencies..."
python3 -m pip install --upgrade python-graph-core python-graph-dot archspec autopep8 GitPython pep8 pycodestyle Rich setuptools && okay || exit 1


## Install lua
# Download
if [ ! -f "lua-${lua_version}.tar.gz" ]; then
	pending "Downloading lua..."
	wget "https://www.lua.org/ftp/lua-${lua_version}.tar.gz" && okay || exit 2
fi
# Extract
pending "Extracting lua..."
tar xzvf "lua-${lua_version}.tar.gz" && okay || exit 3
# Compile & install
pending "Installing lua..."
cd "lua-${lua_version}"
make linux && make INSTALL_TOP=$lua_prefix install && export PATH=$lua_prefix/bin:$PATH && okay || exit 4
cd ../

## Install luaposix
# Download
if [ ! -f "luaposix-${luaposix_version}.tar.gz" ]; then
	pending "Downloading luaposix..."
	wget -O "luaposix-${luaposix_version}.tar.gz" "https://github.com/luaposix/luaposix/archive/refs/tags/v${luaposix_version}.tar.gz" && okay || exit 4
fi
# Extract
pending "Extracting luaposix..."
tar xzvf "luaposix-${luaposix_version}.tar.gz" && okay || exit 4
pending "Installing luaposix..."
cd "luaposix-${luaposix_version}" && \
# fix build script paths
sed -i "s|\(LUA_DIR=\)'/usr'|\1'$lua_prefix'|" build-aux/luke && \
sed -i "s|\(LUA_INCDIR='\$LUA_DIR/include\)/lua\$LUAVERSION'|\1'|" build-aux/luke && \
# Compile
./build-aux/luke && \
# Copy files to proper directories
mkdir -p $lua_prefix/share/lua/${lua_version:0:3}/posix && \
cp lib/posix/*.lua $lua_prefix/share/lua/${lua_version:0:3}/posix && \
cp -r linux/posix $lua_prefix/lib/lua/${lua_version:0:3} && \
cd ../ && okay || exit 4

# Set EB_PYTHON and lua paths
pending "Setting up PATH..."
echo "# $easybuildrc: EasyBuild environment file" > $easybuildrc
{ echo "export EB_PYTHON=python3"; echo ""; echo "# Lua environment"; } >> $easybuildrc
{ echo "export LUA_PATH=\"$lua_modules\""; echo "export LUA_CPATH=\"$lua_libs\""; } >> $easybuildrc
. $easybuildrc && okay || exit 4

## Install Lmod
# Download
if [ ! -f "Lmod-${lmod_version}.tar.gz" ]; then
	pending "Downloading Lmod..."
	wget -O "Lmod-${lmod_version}.tar.gz" "https://github.com/TACC/Lmod/archive/refs/tags/${lmod_version}.tar.gz" && okay || exit 5
fi
# Extract
pending "Extracting Lmod..."
tar xzvf "Lmod-${lmod_version}.tar.gz" && okay || exit 6
# Compile & install
pending "Installing Lmod..."
cd "Lmod-${lmod_version}"
./configure --prefix=$lmod_prefix --with-spiderCacheDir=$lmod_spidercachedir --with-updateSystemFn=$lmod_updatesystemfn && make install && okay || exit 7
cd ../

## Create script for manual spider cache creation & update
cat > $lmod_prefix/moduleData/createSystemCache.sh <<EOF
$lmod_libexec/update_lmod_system_cache_files -t $lmod_updatesystemfn -d $lmod_spidercachedir \$MODULEPATH
EOF
chmod +x createSystemCache.sh

## Update paths for standard installation & system sourcing
pending "Setting up PATH..."
{ echo ""; echo "# Lmod environment"; } >> $easybuildrc
{ echo "export PATH=$lmod_prefix:\$PATH"; echo "source $lmod_init_bash"; echo "export LMOD_CMD=$lmod_cmd"; } >> $easybuildrc
grep -qxF "if [ -f $easybuildrc ]; then source $easybuildrc; fi" /etc/profile || \
	sudo -i bash -c "{ echo \"\"; echo \"# EasyBuild Environment\"; echo \"if [ -f $easybuildrc ]; then source $easybuildrc; fi\"; } >> /etc/profile"
. $easybuildrc && okay

### Install EasyBuild
echo ""
easybuild "###################################"
easybuild "Installing EasyBuild with EasyBuild"
easybuild "###################################"
echo ""
## Create temporary installation
pending "Making a temporary EasyBuild installation in /tmp..."
# Install
python3 -m pip install --ignore-installed --prefix $EB_TMPDIR easybuild && okay || exit 8
# Make system find it
pending "Updating the environment..."
export PATH=$(find $EB_TMPDIR -type d -name bin):$PATH
export PYTHONPATH=$(find $EB_TMPDIR -type d -name *-packages | tail -1)
okay
## Generate standard configuration
# TODO: Rewrite to utilize 'eb --confighelp' and use sed / awk to uncomment the following
pending "Generating EasyBuild configuration..."
mkdir -p $easybuild_config
cat > $easybuild_config/config.cfg <<EOF
[MAIN]

[basic]
locks-dir=$main_prefix/.locks/
#robot=$main_prefix/easybuild-easyconfigs/easybuild/easyconfigs
robot-paths=$main_prefix/easybuild-easyconfigs/easybuild/easyconfigs

[config]
buildpath=/dev/shm
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
#cuda-compute-capabilities=$cuda_cc
wait-on-lock-interval=600
EOF
okay
## Install EasyBuild module
pending "Installing EasyBuild module with EasyBuild..."
eb --install-latest-eb-release --prefix $easybuild_prefix && okay || exit 9

## Donwload develop easyconfigs
pending "Downloading current easyconfigs..."
cd $main_prefix && git clone https://github.com/easybuilders/easybuild-easyconfigs.git && cd - && okay || exit 10

## Set proper MODULEPATH
pending "Setting up environment..."
echo "" >> $easybuildrc
echo "# tell Lmod where to search for modules" >> $easybuildrc
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

## Add 'sticky' property to the EasyBuild module
{ echo "setenv(\"EASYBUILD_ROBOT_PATHS\", \"$main_prefix/easybuild-easyconfigs/easybuild/easyconfigs\")"; echo "add_property(\"lmod\", \"sticky\")"; } >> $(find $easybuild_prefix/modules/all/EasyBuild/ -name *.lua)

## make EasyBuild autoresolve dependencies
# uncommenting line that had to be commented out during the original EB installation
sed -i 's/#//g' $easybuild_config/config.cfg
okay

## Final cleanup
pending "Cleaning up..."
yes | rm -r "lua-${lua_version}.tar.gz" "lua-${lua_version}/" "luaposix-${luaposix_version}.tar.gz" "luaposix-${luaposix_version}/" "Lmod-${lmod_version}.tar.gz" "Lmod-${lmod_version}/" "$EB_TMPDIR"
okay

## Print final message
echo ""
pending "Installation complete."
echo ""
easybuild "To load the EasyBuild module, use"
easybuild "  module load EasyBuild"
echo ""
easybuild "Do not forget to reload your environment."
echo ""
