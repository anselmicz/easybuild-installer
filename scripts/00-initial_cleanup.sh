#!/bin/sh
if [ -d "${main_prefix}" ]; then
	yes | rm -r ${main_prefix}/*
fi

if [ -d "${easybuild_config}" ]; then
	yes | rm -r ${easybuild_config}
fi

if [ -d "${easybuild_tmpdir}" ]; then
	yes | rm -r ${easybuild_tmpdir}
fi
