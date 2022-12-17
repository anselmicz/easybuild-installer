#!/bin/bash
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
