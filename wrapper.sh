#!/bin/bash
clear
if [ $EUID == 0 ]; then
	echo "Running as root; exiting..."
	exit 255
fi

if [ -f "config" ]; then
	set -a
	source config
	set +a
fi

if [ ! -d "build" ]; then
	mkdir build
fi

if [ -f "scripts/00-initial_cleanup.sh" ]; then
	./scripts/00-initial_cleanup.sh
fi

if [ -f "scripts/01-os_dependencies.sh" ]; then
	./scripts/01-os_dependencies.sh
fi

if [ -f "scripts/02-lua.sh" ]; then
	cp scripts/02-lua.sh build && \
		cd build && \
		export PATH=$lua_prefix/bin:$PATH && \
		./02-lua.sh && \
		export LUA_PATH="$lua_modules" && \
		export LUA_CPATH="$lua_libs" && \
		rm 02-lua.sh && \
		cd .. || exit 2
fi

if [ -f "scripts/03-lmod.sh" ]; then
	cp scripts/03-lmod.sh build && \
		cd build && \
		./03-lmod.sh && \
		export PATH=$lmod_prefix:$PATH && \
		source $lmod_init_bash && \
		export LMOD_CMD=$lmod_cmd && \
		rm 03-lmod.sh && \
		cd .. || exit 3
fi

if [ -f "scripts/04-easybuild.sh" ]; then
	cp scripts/04-easybuild.sh build && \
		cd build && \
		export EB_PYTHON=python3 && \
		./04-easybuild.sh && \
		rm 04-easybuild.sh && \
		cd .. || exit 4
fi

if [ -f "scripts/05-easyconfigs.sh" ]; then
	cp scripts/05-easyconfigs.sh build && \
		cd build && \
		./05-easyconfigs.sh && \
		rm 05-easyconfigs.sh && \
		cd .. || exit 5
fi

if [ -f "scripts/06-configuration.sh" ]; then
	cp scripts/06-configuration.sh build && \
		cd build && \
		./06-configuration.sh && \
		rm 06-configuration.sh && \
		cd .. || exit 6
fi

if [ -f "scripts/07-final_cleanup.sh" ]; then
	./scripts/07-final_cleanup.sh
fi
