#

# Setup R (done first to avoid module dependency issue, FSL requires more recent version of gcc)
module load R/3.4.3
# unload openssl that loads with R (causes ssh issues)
module remove openssl
export R_LIBS_SITE='/sc/orga/projects/adolpvs/PreProcPipeline/Scripts/r_library'
export R_LIBS_USER='/sc/orga/projects/adolpvs/PreProcPipeline/Scripts/r_library'
#echo 'If R failes to load libraries, add the following line in ~/.Rprofile'
#echo '.libPaths(c("/sc/orga/projects/adolpvs/PreProcPipeline/Scripts/r_library", .libPaths()))'

# Setup FSL v5.0.11
## Minerva
module load fsl/5.0.11
. ${FSLDIR}/etc/fslconf/fsl.sh

# Setup FreeSurfer v5.3.0-HCP
module load freesurfer/5.3.0
. ${SETUP_FREESURFER_SH} > /dev/null 2>&1

