#!/bin/bash
if [ ! -f "lua-${lua_version}.tar.gz" ]; then
	wget "https://www.lua.org/ftp/lua-${lua_version}.tar.gz"
fi

tar xzvf "lua-${lua_version}.tar.gz"
cd "lua-${lua_version}"

make -j$(nproc) linux
make INSTALL_TOP=$lua_prefix install
cd ..

if [ ! -f "luaposix-${luaposix_version}.tar.gz" ]; then
	wget -O "luaposix-${luaposix_version}.tar.gz" "https://github.com/luaposix/luaposix/archive/refs/tags/v${luaposix_version}.tar.gz"
fi

tar xzvf "luaposix-${luaposix_version}.tar.gz"
cd "luaposix-${luaposix_version}" && \
	sed -i "s|\(LUA_DIR=\)'/usr'|\1'$lua_prefix'|" build-aux/luke && \
	sed -i "s|\(LUA_INCDIR='\$LUA_DIR/include\)/lua\$LUAVERSION'|\1'|" build-aux/luke && \
	./build-aux/luke && \
	mkdir -p $lua_prefix/share/lua/${lua_version:0:3}/posix && \
	cp lib/posix/*.lua $lua_prefix/share/lua/${lua_version:0:3}/posix && \
	cp -r linux/posix $lua_prefix/lib/lua/${lua_version:0:3} && \
	cd ..
