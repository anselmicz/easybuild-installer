#!/bin/bash
if [ ! -f "Lmod-${lmod_version}.tar.gz" ]; then
	wget -O "Lmod-${lmod_version}.tar.gz" "https://github.com/TACC/Lmod/archive/refs/tags/${lmod_version}.tar.gz"
fi

tar xzvf "Lmod-${lmod_version}.tar.gz"
cd "Lmod-${lmod_version}"

./configure --prefix=${lmod_prefix} --with-spiderCacheDir=${lmod_spidercachedir} --with-updateSystemFn=${lmod_updatesystemfn} && make install
cd ..

# Create Lmod spider cache directory
mkdir ${lmod_cache}
