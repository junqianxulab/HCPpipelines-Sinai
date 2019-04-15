#!/bin/bash
# resets Minerva global PATH and LD_LIBRARY_PATH variables to defaults and unsets other HCP Pipeline variables
# run before submitting LSF scripts to avoid version conflicts (e.g. FSL/5.0.6 vs. FSL/5.0.11)

export PATH="/usr/lib64/qt-3.3/bin:/opt/moab/bin:/hpc/lsf/9.1/linux2.6-glibc2.3-x86_64/etc:/hpc/lsf/9.1/linux2.6-glibc2.3-x86_64/bin:/opt/gold/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/lpp/mmfs/bin:/opt/ibutils/bin"
export LD_LIBRARY_PATH="/hpc/lsf/9.1/linux2.6-glibc2.3-x86_64/lib"
unset FSLDIR
unset FSL_DIR
unset FREESURFER_HOME
unset HCPPIPEDIR
unset CARET7DIR
unset MSMBin
unset MSMBINDIR
unset MSMCONFIGDIR
unset MATLAB_COMPILER_RUNTIME
unset MCRROOT
unset XAPPLRESDIR
unset FSL_FIXDIR
unset FSL_FIX_WBC
unset HCPPIPEDIR_Templates
unset HCPPIPEDIR_Bin
unset HCPPIPEDIR_Config
unset HCPPIPEDIR_PreFS
unset HCPPIPEDIR_FS
unset HCPPIPEDIR_PostFS
unset HCPPIPEDIR_fMRISurf
unset HCPPIPEDIR_fMRIVol
unset HCPPIPEDIR_tfMRI
unset HCPPIPEDIR_dMRI
unset HCPPIPEDIR_dMRITract
unset HCPPIPEDIR_Global
unset HCPPIPEDIR_tfMRIAnalysis
