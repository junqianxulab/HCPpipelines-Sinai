#!/bin/bash
# outputs information about environmental settings relevant to HCP Pipelines
# useful for debugging; good practice to include in any HCP Pipeline LSF submission
echo "**********************************************************************************************************"
echo "Loaded modules, HCP global variables, PATH, and LD_LIBRARY_PATH:"
echo ""
echo $(module list)
echo FSLDIR = $FSLDIR
echo FSL_DIR = $FSL_DIR
echo FREESURFER_HOME = $FREESURFER_HOME
echo HCPPIPEDIR = $HCPPIPEDIR
echo CARET7DIR = $CARET7DIR
echo MSMBin = $MSMBin
echo MSMBINDIR = $MSMBINDIR
echo MSMCONFIGDIR = $MSMCONFIGDIR
echo MATLAB_COMPILER_RUNTIME = $MATLAB_COMPILER_RUNTIME
echo MCRROOT = $MCRROOT
echo XAPPLRESDIR = $XAPPLRESDIR
echo FSL_FIXDIR = $FSL_FIXDIR
echo FSL_FIX_WBC = $FSL_FIX_WBC
echo FSL_FIX_MCR = $FSL_FIX_MCR
echo FSL_FIX_MCC = $FSL_FIX_MCC
echo FSL_FIX_MLCDIR = $FSL_FIX_MLCDIR
echo FSL_FIX_MATLAB_MODE = $FSL_FIX_MATLAB_MODE
echo HCPPIPEDIR_Templates = $HCPPIPEDIR_Templates
echo HCPPIPEDIR_Bin = $HCPPIPEDIR_Bin
echo HCPPIPEDIR_Config = $HCPPIPEDIR_Config
echo HCPPIPEDIR_PreFS = $HCPPIPEDIR_PreFS
echo HCPPIPEDIR_FS = $HCPPIPEDIR_FS
echo HCPPIPEDIR_PostFS = $HCPPIPEDIR_PostFS
echo HCPPIPEDIR_fMRISurf = $HCPPIPEDIR_fMRISurf
echo HCPPIPEDIR_fMRIVol = $HCPPIPEDIR_fMRIVol
echo HCPPIPEDIR_tfMRI = $HCPPIPEDIR_tfMRI
echo HCPPIPEDIR_dMRI = $HCPPIPEDIR_dMRI
echo HCPPIPEDIR_dMRITract = $HCPPIPEDIR_dMRITract
echo HCPPIPEDIR_Global = $HCPPIPEDIR_Global
echo HCPPIPEDIR_tfMRIAnalysis = $HCPPIPEDIR_tfMRIAnalysis
echo ""
echo PATH =
echo "${PATH//:/$'\n'}"
echo ""
echo LD_LIBRARY_PATH = 
echo "${LD_LIBRARY_PATH//:/$'\n'}"
echo "**********************************************************************************************************"
