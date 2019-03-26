#!/bin/bash
# resets Minerva global PATH and LD_LIBRARY_PATH variables to defaults
# run before submitting LSF scripts to avoid version conflicts (e.g. FSL/5.0.6 vs. FSL/5.0.11)

export PATH="/usr/lib64/qt-3.3/bin:/opt/moab/bin:/hpc/lsf/9.1/linux2.6-glibc2.3-x86_64/etc:/hpc/lsf/9.1/linux2.6-glibc2.3-x86_64/bin:/opt/gold/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/lpp/mmfs/bin:/opt/ibutils/bin"
export LD_LIBRARY_PATH="/hpc/lsf/9.1/linux2.6-glibc2.3-x86_64/lib"
