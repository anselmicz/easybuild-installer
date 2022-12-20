#!/bin/bash
# System configuration
echo "# $easybuildrc: EasyBuild environment file" > $easybuildrc
{ echo "export EB_PYTHON=\"python3\""; echo ""; } >> $easybuildrc

echo "# Lua environment" >> $easybuildrc
{ echo "export LUA_PATH=\"$lua_modules\""; echo "export LUA_CPATH=\"$lua_libs\""; echo ""; } >> $easybuildrc

echo "# Lmod environment" >> $easybuildrc
{ echo "export PATH=\"$lmod_prefix:\$PATH\""; echo "source \"$lmod_init_bash\""; echo "export LMOD_CMD=\"$lmod_cmd\""; echo ""; } >> $easybuildrc

echo "# Tell Lmod where to search for modules" >> $easybuildrc
cat >> $easybuildrc <<EOF
if [ "\$(id -u)" -ne 0 ]; then
    MODULEPATH=""

    for dir in $easybuild_prefix/modules/*
    do
        # Exclude following directories
        if [[ (\${dir##*/} == "all") ]]; then
            continue
        fi
        # In case it's a directory
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

# Create alias for updating system spider cache
echo "alias update_cache=\"$lmod_libexec/update_lmod_system_cache_files -t $lmod_updatesystemfn -d $lmod_spidercachedir \$MODULEPATH\"" >> $easybuildrc

# Update system profile
grep -qxF "if [ -f $easybuildrc ]; then source $easybuildrc; fi" /etc/profile || \
	sudo -i bash -c "{ echo \"\"; echo \"# EasyBuild Environment\"; echo \"if [ -f $easybuildrc ]; then source $easybuildrc; fi\"; } >> /etc/profile"

# EasyBuild configuration
mkdir -p $easybuild_config
cat > $easybuild_config/config.cfg <<EOF
[MAIN]

[basic]
locks-dir=$main_prefix/.locks/
robot=$main_prefix/easybuild-easyconfigs/easybuild/easyconfigs
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
cuda-compute-capabilities=$cuda_cc
wait-on-lock-interval=600
EOF

# Add 'sticky' property to the EasyBuild module
{ echo "setenv(\"EASYBUILD_ROBOT_PATHS\", \"$main_prefix/easybuild-easyconfigs/easybuild/easyconfigs\")"; echo "add_property(\"lmod\", \"sticky\")"; } >> $(find $easybuild_prefix/modules/all/EasyBuild/ -name *.lua)
