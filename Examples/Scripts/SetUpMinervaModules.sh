#

# Load FSL. Either minerva module or local installation
#FSLDIR=/sc/orga/work/kimj77/usr/fsl5.0.11
#PATH=${FSLDIR}/bin:${PATH}
module load fsl/5.0.11
. ${FSLDIR}/etc/fslconf/fsl.sh

module load freesurfer/5.3.0 > /dev/null 2>&1
. ${SETUP_FREESURFER_SH} > /dev/null 2>&1

# Setup R
module load R/3.4.3
module remove openssl

export R_LIBS_SITE='/sc/orga/projects/adolpvs/PreProcPipeline/Scripts/r_library'
export R_LIBS_USER='/sc/orga/projects/adolpvs/PreProcPipeline/Scripts/r_library'

echo 'If R failes to load libraries, add the following line in ~/.Rprofile'
echo '.libPaths(c("/sc/orga/projects/adolpvs/PreProcPipeline/Scripts/r_library", .libPaths()))'
