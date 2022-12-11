#!/bin/bash
# GPL v3
########################################################
### CONFIG
## main
main_prefix=/apps
#
## lua
lua_version="5.4.4"
luarocks_version="3.9.1"
lua_prefix=$main_prefix/dependencies/lua
lua_modules="$lua_prefix/share/lua/${lua_version:0:3}/?.lua;$lua_prefix/share/lua/${lua_version:0:3}/?/init.lua;;"
lua_libs="$lua_prefix/lib/lua/${lua_version:0:3}/?.so;;"
#
## Lmod
#lmod_version="8.5"
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

if [ $EUID == 0 ]
then
	echo "Running as root; exiting..."
	exit 255
fi

pending "Cleaning up directories..."
rm -rf $main_prefix $easybuild_config $EB_TMPDIR /tmp/eb-* && okay

pending "Installing dependencies..."
sudo apt install -y wget gcc make rsync tclsh tcl-dev libreadline-dev libibverbs-dev python3-pip xdot && okay

pending "Installing non-essential python dependencies..."
python3 -m pip install --upgrade python-graph-core python-graph-dot archspec autopep8 GitPython pep8 pycodestyle Rich setuptools && okay || exit 1

if [ ! -f "lua-${lua_version}.tar.gz" ]; then
	pending "Downloading lua..."
	wget "https://www.lua.org/ftp/lua-${lua_version}.tar.gz" && okay || exit 2
fi

pending "Extracting lua..."
tar xzvf "lua-${lua_version}.tar.gz" && okay || exit 3

pending "Compiling lua..."
cd "lua-${lua_version}"
make linux && make INSTALL_TOP=$lua_prefix install && export PATH=$lua_prefix/bin:$PATH && okay || exit 4
cd ../

if [ ! -f "luarocks-3.9.1.tar.gz" ]; then
	pending "Downloading luarocks..."
	wget "https://luarocks.org/releases/luarocks-${luarocks_version}.tar.gz" && okay || exit 4
fi

pending "Extracting luarocks..."
tar xzvf "luarocks-${luarocks_version}.tar.gz" && okay || exit 4

pending "Installing luarocks..."
cd "luarocks-${luarocks_version}"
./configure --prefix=$lua_prefix && make && make install && okay || exit 4
cd ../

pending "Installing lua modules..."
luarocks install --tree $lua_prefix luaposix && okay || exit 4

pending "Setting up PATH..."
echo "# $easybuildrc: EasyBuild environment file" > $easybuildrc
{ echo "export EB_PYTHON=python3"; echo ""; echo "# Lua environment"; } >> $easybuildrc
{ echo "export LUA_PATH=\"$lua_modules\""; echo "export LUA_CPATH=\"$lua_libs\""; } >> $easybuildrc
. $easybuildrc && okay || exit 4


if [ ! -f "Lmod-${lmod_version}.tar.gz" ]; then
	pending "Downloading Lmod..."
	wget -O "Lmod-${lmod_version}.tar.gz" "https://github.com/TACC/Lmod/archive/refs/tags/${lmod_version}.tar.gz" && okay || exit 5
fi

pending "Extracting Lmod..."
tar xzvf "Lmod-${lmod_version}.tar.gz" && okay || exit 6

pending "Compiling Lmod..."
cd "Lmod-${lmod_version}"
#./configure --prefix=$lmod_prefix && make install && okay || exit 7
./configure --prefix=$lmod_prefix --with-spiderCacheDir=$lmod_spidercachedir --with-updateSystemFn=$lmod_updatesystemfn && make install && okay || exit 7
cd ../

cat > createSystemCache.sh <<EOF
$lmod_libexec/update_lmod_system_cache_files -t $lmod_updatesystemfn -d $lmod_spidercachedir \$MODULEPATH
EOF
chmod +x createSystemCache.sh

pending "Setting up PATH..."
{ echo ""; echo "# Lmod environment"; } >> $easybuildrc
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
python3 -m pip install --ignore-installed --prefix $EB_TMPDIR easybuild && okay || exit 8

pending "Updating the environment..."
export PATH=$(find $EB_TMPDIR -type d -name bin):$PATH
export PYTHONPATH=$(find $EB_TMPDIR -type d -name *-packages | tail -1)
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
sed -i 's/#//g' $easybuild_config/config.cfg
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
