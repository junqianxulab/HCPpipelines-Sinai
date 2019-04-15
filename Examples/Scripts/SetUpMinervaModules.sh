#!/bin/bash

module load fsl/5.0.6
. ${FSLDIR}/etc/fslconf/fsl.sh

module load connectome/1.2.3

module load gradunwarp
export PATH="/hpc/packages/minerva-common/gradunwarp/1.0.2/bin:$PATH"

module load freesurfer/5.3.0 > /dev/null 2>&1
. ${SETUP_FREESURFER_SH} > /dev/null 2>&1
# needs libnetcdf.so.6 in the library path or FreeSurfer pipeline will crash 
export LD_LIBRARY_PATH="/usr/lib64:$LD_LIBRARY_PATH"

