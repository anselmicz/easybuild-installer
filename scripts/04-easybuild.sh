#!/bin/bash

python_sysconfig_path="/lib/python$(python3 --version | grep -o '[[:digit:]]\.[[:digit:]]*')/sysconfig.py"
grep -q "prefix_scheme = 'posix_local'" "$python_sysconfig_path" && \
	export DEB_PYTHON_INSTALL_LAYOUT="eb" && \
	sudo patch "$python_sysconfig_path" < "../patches/fix_system_python_prefix.patch"

python3 -m pip install --ignore-installed --prefix $easybuild_tmpdir easybuild

export PATH=$(find $easybuild_tmpdir -type d -name bin):$PATH
export PYTHONPATH=$(find $easybuild_tmpdir -type d -name *-packages | tail -1)

eb --install-latest-eb-release \
	--prefix $easybuild_prefix \
	--installpath=$main_prefix \
	--installpath-modules=$main_prefix/modules \
	--installpath-software=$main_prefix/all \
	--moduleclasses=python \
	--repositorypath=$main_prefix/file-repository \
	--sourcepath=$main_prefix/sources \
	--trace

sudo patch "$python_sysconfig_path" < "../patches/revert_system_python_eb_fix.patch"
unset DEB_PYTHON_INSTALL_LAYOUT
