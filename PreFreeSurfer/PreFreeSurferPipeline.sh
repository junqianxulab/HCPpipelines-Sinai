#!/bin/bash
#~ND~FORMAT~MARKDOWN~
#~ND~START~
#
# # PreFreeSurferPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2013-2014 The Human Connectome Project
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Mark Jenkinson, FMRIB Centre, Oxford University
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
# * Modifications to support General Electric Gradient Echo field maps for readout distortion correction
#   are based on example code provided by Gaurav Patel, Columbia University
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-University/Pipelines/blob/master/LICENSE.md) file
#
# ## Description
#
# This script, PreFreeSurferPipeline.sh, is the first of 3 sub-parts of the
# Structural Preprocessing phase of the [HCP][HCP] Minimal Preprocessing Pipelines.
#
# See [Glasser et al. 2013][GlasserEtAl].
#
# This script implements the PreFreeSurfer Pipeline referred to in that publication.
#
# The primary purposes of the PreFreeSurfer Pipeline are:
#
# 1. To average any image repeats (i.e. multiple T1w or T2w images available)
# 2. To create a native, undistorted structural volume space for the subject
#    * Subject images in this native space will be distortion corrected
#      for gradient and b0 distortions and rigidly aligned to the axes
#      of the MNI space. "Native, undistorted structural volume space"
#      is sometimes shortened to the "subject's native space" or simply
#      "native space".
# 3. To provide an initial robust brain extraction
# 4. To align the T1w and T2w structural images (register them to the native space)
# 5. To perform bias field correction
# 6. To register the subject's native space to the MNI space
#
# ## Prerequisites:
#
# ### Installed Software
#
# * [FSL][FSL] - FMRIB's Software Library (version 5.0.6)
#
# ### Environment Variables
#
# * HCPPIPEDIR
#
#   The "home" directory for the version of the HCP Pipeline Tools product
#   being used. E.g. /nrgpackages/tools.release/hcp-pipeline-tools-V3.0
#
# * HCPPIPEDIR_PreFS
#
#   Location of PreFreeSurfer sub-scripts that are used to carry out some of
#   steps of the PreFreeSurfer pipeline
#
# * HCPPIPEDIR_Global
#
#   Location of shared sub-scripts that are used to carry out some of the
#   steps of the PreFreeSurfer pipeline and are also used to carry out
#   some steps of other pipelines.
#
# * FSLDIR
#
#   Home directory for [FSL][FSL] the FMRIB Software Library from Oxford
#   University
#
# ### Image Files
#
# At least one T1 weighted image and one T2 weighted image are required
# for this script to work.
#
# ### Output Directories
#
# Command line arguments are used to specify the StudyFolder (--path) and
# the Subject (--subject).  All outputs are generated within the tree rooted
# at ${StudyFolder}/${Subject}.  The main output directories are:
#
# * The T1wFolder: ${StudyFolder}/${Subject}/T1w
# * The T2wFolder: ${StudyFolder}/${Subject}/T2w
# * The AtlasSpaceFolder: ${StudyFolder}/${Subject}/MNINonLinear
#
# All outputs are generated in directories at or below these three main
# output directories.  The full list of output directories is:
#
# * ${T1wFolder}/T1w${i}_GradientDistortionUnwarp
# * ${T1wFolder}/AverageT1wImages
# * ${T1wFolder}/ACPCAlignment
# * ${T1wFolder}/BrainExtraction_FNIRTbased
# * ${T1wFolder}/xfms - transformation matrices and warp fields
#
# * ${T2wFolder}/T2w${i}_GradientDistortionUnwarp
# * ${T2wFolder}/AverageT1wImages
# * ${T2wFolder}/ACPCAlignment
# * ${T2wFolder}/BrainExtraction_FNIRTbased
# * ${T2wFolder}/xfms - transformation matrices and warp fields
#
# * ${T2wFolder}/T2wToT1wDistortionCorrectAndReg
# * ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w
#
# * ${AtlasSpaceFolder}
# * ${AtlasSpaceFolder}/xfms
#
# Note that no assumptions are made about the input paths with respect to the
# output directories. All specification of input files is done via command
# line arguments specified when this script is invoked.
#
# Also note that the following output directories are created:
#
# * T1wFolder, which is created by concatenating the following three option
#   values: --path / --subject / --t1
# * T2wFolder, which is created by concatenating the following three option
#   values: --path / --subject / --t2
#
# These two output directories must be different. Otherwise, various output
# files with standard names contained in such subdirectories, e.g.
# full2std.mat, would overwrite each other).  If this script is modified,
# then those two output directories must be kept distinct.
#
# ### Output Files
#
# * T1wFolder Contents: TODO
# * T2wFolder Contents: TODO
# * AtlasSpaceFolder Contents: TODO
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
# [GlasserEtAl]: http://www.ncbi.nlm.nih.gov/pubmed/23668970
# [FSL]: http://fsl.fmrib.ox.ac.uk
#
#~ND~END~

# ------------------------------------------------------------------------------
#  Code Start
# ------------------------------------------------------------------------------

# Setup this script such that if any command exits with a non-zero value, the
# script itself exits and does not attempt any further processing.
set -e

# -----------------------------------------------------------------------------------
#  Constants for specification of Averaging and Readout Distortion Correction Method
# -----------------------------------------------------------------------------------

NONE_METHOD_OPT="NONE"
FIELDMAP_METHOD_OPT="FIELDMAP"
SIEMENS_METHOD_OPT="SiemensFieldMap"
SPIN_ECHO_METHOD_OPT="TOPUP"
GENERAL_ELECTRIC_METHOD_OPT="GeneralElectricFieldMap"

# ------------------------------------------------------------------------------
#  Verify required environment variables are set
# ------------------------------------------------------------------------------

script_name=$(basename "${0}")

if [ -z "${HCPPIPEDIR}" ]; then
	echo "${script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
else
	echo "${script_name}: HCPPIPEDIR: ${HCPPIPEDIR}"
fi

if [ -z "${FSLDIR}" ]; then
	echo "${script_name}: ABORTING: FSLDIR environment variable must be set"
	exit 1
else
	echo "${script_name}: FSLDIR: ${FSLDIR}"
fi

if [ -z "${HCPPIPEDIR_Global}" ]; then
	echo "${script_name}: ABORTING: HCPPIPEDIR_Global environment variable must be set"
	exit 1
else
	echo "${script_name}: HCPPIPEDIR_Global: ${HCPPIPEDIR_Global}"
fi

if [ -z "${HCPPIPEDIR_PreFS}" ]; then
	echo "${script_name}: ABORTING: HCPPIPEDIR_PreFS environment variable must be set"
	exit 1
else
	echo "${script_name}: HCPPIPEDIR_PreFS: ${HCPPIPEDIR_PreFS}"
fi

# ------------------------------------------------------------------------------
#  Load Function Libraries
# ------------------------------------------------------------------------------

source ${HCPPIPEDIR}/global/scripts/log.shlib  # Logging related functions
source ${HCPPIPEDIR}/global/scripts/opts.shlib # Command line option functions

# ------------------------------------------------------------------------------
#  Usage Description Function
# ------------------------------------------------------------------------------

show_usage() {
	cat <<EOF

PreFreeSurferPipeline.sh

Usage: PreeFreeSurferPipeline.sh [options]

  --path=<path>        Path to study data folder (required)
					   Used with --subject input to create full path to root
					   directory for all outputs generated as path/subject
  --subject=<subject>  Subject ID (required)
					   Used with --path input to create full path to root
					   directory for all outputs generated as path/subject
  --t1=<T1w images>    An @ symbol separated list of full paths to T1-weighted
					   (T1w) structural images for the subject (required)
  --t2=<T2w images>    An @ symbol separated list of full paths to T2-weighted
					   (T2w) structural images for the subject (required)
  --t1template=<file path>          MNI T1w template
  --t1templatebrain=<file path>     Brain extracted MNI T1wTemplate
  --t1template2mm=<file path>       MNI 2mm T1wTemplate
  --t2template=<file path>          MNI T2w template
  --t2templatebrain=<file path>     Brain extracted MNI T2wTemplate
  --t2template2mm=<file path>       MNI 2mm T2wTemplate
  --templatemask=<file path>        Brain mask MNI Template
  --template2mmmask=<file path>     Brain mask MNI 2mm Template
  --brainsize=<size value>          Brain size estimate in mm, 150 for humans
  --fnirtconfig=<file path>         FNIRT 2mm T1w Configuration file
  --fmapmag=<file path>             Siemens Gradient Echo Fieldmap magnitude file
  --fmapphase=<file path>           Siemens Gradient Echo Fieldmap phase file
  --fmapgeneralelectric=<file path> General Electric Gradient Echo Field Map file
									Two volumes in one file
									1. field map in deg
									2. magnitude
  --echodiff=<delta TE>             Delta TE in ms for field map or "NONE" if
									not used
  --SEPhaseNeg={<file path>, NONE}  For spin echo field map, path to volume with
									a negative phase encoding direction (LR in
									HCP data), set to "NONE" if not using Spin
									Echo Field Maps
  --SEPhasePos={<file path>, NONE}  For spin echo field map, path to volume with
									a positive phase encoding direction (RL in
									HCP data), set to "NONE" if not using Spin
									Echo Field Maps
  --seechospacing=<seconds>         Effective Echo Spacing of Spin Echo Field Map,
									(in seconds) or "NONE" if not used
  --seunwarpdir={x,y,NONE}          Phase encoding direction (according to the *voxel* axes)
             or={i,j,NONE}          of the spin echo field map. 
                                    (Only applies when using a spin echo field map.)
  --t1samplespacing=<seconds>       T1 image sample spacing, "NONE" if not used
  --t2samplespacing=<seconds>       T2 image sample spacing, "NONE" if not used
  --unwarpdir={x,y,z,x-,y-,z-}      Readout direction of the T1w and T2w images (according to the *voxel axes)
           or={i,j,k,i-,j-,k-}      (Used with either a gradient echo field map 
									or a spin echo field map)
  --gdcoeffs=<file path>            File containing gradient distortion
									coefficients, Set to "NONE" to turn off
  --avgrdcmethod=<avgrdcmethod>     Averaging and readout distortion correction
									method. See below for supported values.

	  "${NONE_METHOD_OPT}"
		 average any repeats with no readout distortion correction

	  "${FIELDMAP_METHOD_OPT}"
		 equivalent to "${SIEMENS_METHOD_OPT}" (see below)
		 SiemensFieldMap is preferred. This option value is maintained for
		 backward compatibility.

	  "${SPIN_ECHO_METHOD_OPT}"
		 average any repeats and use Spin Echo Field Maps for readout
		 distortion correction

	  "${GENERAL_ELECTRIC_METHOD_OPT}"
		 average any repeats and use General Electric specific Gradient
		 Echo Field Maps for readout distortion correction

	  "${SIEMENS_METHOD_OPT}"
		 average any repeats and use Siemens specific Gradient Echo
		 Field Maps for readout distortion correction

  --topupconfig=<file path>      Configuration file for topup or "NONE" if not
								 used
  --bfsigma=<value>              Bias Field Smoothing Sigma (optional)
EOF
	exit 1
}

# ------------------------------------------------------------------------------
#  Establish tool name for logging
# ------------------------------------------------------------------------------
log_SetToolName "PreFreeSurferPipeline.sh"

# ------------------------------------------------------------------------------
#  Parse Command Line Options
# ------------------------------------------------------------------------------

opts_ShowVersionIfRequested $@

if opts_CheckForHelpRequest $@; then
	show_usage
fi

log_Msg "Platform Information Follows: "
uname -a

log_Msg "Parsing Command Line Options"

StudyFolder=`opts_GetOpt1 "--path" $@`
Subject=`opts_GetOpt1 "--subject" $@`
T1wInputImages=`opts_GetOpt1 "--t1" $@`
T2wInputImages=`opts_GetOpt1 "--t2" $@`
T1wTemplate=`opts_GetOpt1 "--t1template" $@`
T1wTemplateBrain=`opts_GetOpt1 "--t1templatebrain" $@`
T1wTemplate2mm=`opts_GetOpt1 "--t1template2mm" $@`
T2wTemplate=`opts_GetOpt1 "--t2template" $@`
T2wTemplateBrain=`opts_GetOpt1 "--t2templatebrain" $@`  # This file/argument not used anywhere
T2wTemplate2mm=`opts_GetOpt1 "--t2template2mm" $@`
TemplateMask=`opts_GetOpt1 "--templatemask" $@`
Template2mmMask=`opts_GetOpt1 "--template2mmmask" $@`
BrainSize=`opts_GetOpt1 "--brainsize" $@`
FNIRTConfig=`opts_GetOpt1 "--fnirtconfig" $@`
MagnitudeInputName=`opts_GetOpt1 "--fmapmag" $@`
PhaseInputName=`opts_GetOpt1 "--fmapphase" $@`
GEB0InputName=`opts_GetOpt1 "--fmapgeneralelectric" $@`
TE=`opts_GetOpt1 "--echodiff" $@`
SpinEchoPhaseEncodeNegative=`opts_GetOpt1 "--SEPhaseNeg" $@`
SpinEchoPhaseEncodePositive=`opts_GetOpt1 "--SEPhasePos" $@`
SEEchoSpacing=`opts_GetOpt1 "--seechospacing" $@`
SEUnwarpDir=`opts_GetOpt1 "--seunwarpdir" $@`
T1wSampleSpacing=`opts_GetOpt1 "--t1samplespacing" $@`
T2wSampleSpacing=`opts_GetOpt1 "--t2samplespacing" $@`
UnwarpDir=`opts_GetOpt1 "--unwarpdir" $@`
GradientDistortionCoeffs=`opts_GetOpt1 "--gdcoeffs" $@`
AvgrdcSTRING=`opts_GetOpt1 "--avgrdcmethod" $@`
TopupConfig=`opts_GetOpt1 "--topupconfig" $@`
BiasFieldSmoothingSigma=`opts_GetOpt1 "--bfsigma" $@`

#NOTE: currently is only used in gradient distortion correction of spin echo fieldmaps to topup
#not currently in usage, either, because of this very limited use
UseJacobian=`opts_GetOpt1 "--usejacobian" $@`

# Use --printcom=echo for just printing everything and not actually
# running the commands (the default is to actually run the commands)
RUN=`opts_GetOpt1 "--printcom" $@`

# Convert UseJacobian value to all lowercase (to allow the user the flexibility to use True, true, TRUE, False, False, false, etc.)
UseJacobian="$(echo ${UseJacobian} | tr '[:upper:]' '[:lower:]')"
UseJacobian=`opts_DefaultOpt $UseJacobian "true"`

# ------------------------------------------------------------------------------
#  Show Command Line Options
# ------------------------------------------------------------------------------

log_Msg "Finished Parsing Command Line Options"
log_Msg "StudyFolder: ${StudyFolder}"
log_Msg "Subject: ${Subject}"
log_Msg "T1wInputImages: ${T1wInputImages}"
log_Msg "T2wInputImages: ${T2wInputImages}"
log_Msg "T1wTemplate: ${T1wTemplate}"
log_Msg "T1wTemplateBrain: ${T1wTemplateBrain}"
log_Msg "T1wTemplate2mm: ${T1wTemplate2mm}"
log_Msg "T2wTemplate: ${T2wTemplate}"
log_Msg "T2wTemplateBrain: ${T2wTemplateBrain}"  # This variable not used anywhere
log_Msg "T2wTemplate2mm: ${T2wTemplate2mm}"
log_Msg "TemplateMask: ${TemplateMask}"
log_Msg "Template2mmMask: ${Template2mmMask}"
log_Msg "BrainSize: ${BrainSize}"
log_Msg "FNIRTConfig: ${FNIRTConfig}"
log_Msg "MagnitudeInputName: ${MagnitudeInputName}"
log_Msg "PhaseInputName: ${PhaseInputName}"
log_Msg "GEB0InputName: ${GEB0InputName}"
log_Msg "TE: ${TE}"
log_Msg "SpinEchoPhaseEncodeNegative: ${SpinEchoPhaseEncodeNegative}"
log_Msg "SpinEchoPhaseEncodePositive: ${SpinEchoPhaseEncodePositive}"
log_Msg "SEEchoSpacing: ${SEEchoSpacing}"
log_Msg "SEUnwarpDir: ${SEUnwarpDir}"
log_Msg "T1wSampleSpacing: ${T1wSampleSpacing}"
log_Msg "T2wSampleSpacing: ${T2wSampleSpacing}"
log_Msg "UnwarpDir: ${UnwarpDir}"
log_Msg "GradientDistortionCoeffs: ${GradientDistortionCoeffs}"
log_Msg "AvgrdcSTRING: ${AvgrdcSTRING}"
log_Msg "TopupConfig: ${TopupConfig}"
log_Msg "BiasFieldSmoothingSigma: ${BiasFieldSmoothingSigma}"
log_Msg "UseJacobian: ${UseJacobian}"

# ------------------------------------------------------------------------------
#  Show Environment Variables
# ------------------------------------------------------------------------------

log_Msg "FSLDIR: ${FSLDIR}"
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"
${HCPPIPEDIR}/show_version
log_Msg "HCPPIPEDIR_Global: ${HCPPIPEDIR_Global}"
log_Msg "HCPPIPEDIR_PreFS: ${HCPPIPEDIR_PreFS}"

# Naming Conventions
T1wImage="T1w"
T1wFolder="T1w" #Location of T1w images
T2wImage="T2w"
T2wFolder="T2w" #Location of T2w images
AtlasSpaceFolder="MNINonLinear"

# Build Paths
T1wFolder=${StudyFolder}/${Subject}/${T1wFolder}
T2wFolder=${StudyFolder}/${Subject}/${T2wFolder}
AtlasSpaceFolder=${StudyFolder}/${Subject}/${AtlasSpaceFolder}

log_Msg "T1wFolder: $T1wFolder"
log_Msg "T2wFolder: $T2wFolder"
log_Msg "AtlasSpaceFolder: $AtlasSpaceFolder"

# Unpack List of Images
T1wInputImages=`echo ${T1wInputImages} | sed 's/@/ /g'`
T2wInputImages=`echo ${T2wInputImages} | sed 's/@/ /g'`

if [ ! -e ${T1wFolder}/xfms ] ; then
	log_Msg "mkdir -p ${T1wFolder}/xfms/"
	mkdir -p ${T1wFolder}/xfms/
fi

if [ ! -e ${T2wFolder}/xfms ] ; then
	log_Msg "mkdir -p ${T2wFolder}/xfms/"
	mkdir -p ${T2wFolder}/xfms/
fi

if [ ! -e ${AtlasSpaceFolder}/xfms ] ; then
	log_Msg "mkdir -p ${AtlasSpaceFolder}/xfms/"
	mkdir -p ${AtlasSpaceFolder}/xfms/
fi

log_Msg "POSIXLY_CORRECT="${POSIXLY_CORRECT}

# ------------------------------------------------------------------------------
#  Do primary work
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
#  Loop over the processing for T1w and T2w (just with different names).
#  For each modality, perform
#  - Gradient Nonlinearity Correction (Unless no gradient distortion
#    coefficients are available)
#  - Average same modality images (if more than one is available)
#  - Rigidly align images to specified MNI Template to create native volume space
#  - Perform Brain Extraction(FNIRT-based Masking)
# ------------------------------------------------------------------------------

Modalities="T1w T2w"

for TXw in ${Modalities} ; do
	log_Msg "Processing Modality: " $TXw

	# set up appropriate input variables
	if [ $TXw = T1w ] ; then
		TXwInputImages="${T1wInputImages}"
		TXwFolder=${T1wFolder}
		TXwImage=${T1wImage}
		TXwTemplate=${T1wTemplate}
		TXwTemplate2mm=${T1wTemplate2mm}
	else
		TXwInputImages="${T2wInputImages}"
		TXwFolder=${T2wFolder}
		TXwImage=${T2wImage}
		TXwTemplate=${T2wTemplate}
		TXwTemplate2mm=${T2wTemplate2mm}
	fi
	OutputTXwImageSTRING=""

	# Perform Gradient Nonlinearity Correction

	if [ ! $GradientDistortionCoeffs = "NONE" ] ; then
		log_Msg "Performing Gradient Nonlinearity Correction"

		i=1
		for Image in $TXwInputImages ; do
			wdir=${TXwFolder}/${TXwImage}${i}_GradientDistortionUnwarp
			log_Msg "mkdir -p $wdir"
			mkdir -p $wdir
			# Make sure input axes are oriented the same as the templates
			${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${wdir}/${TXwImage}${i}

			${RUN} ${HCPPIPEDIR_Global}/GradientDistortionUnwarp.sh \
				--workingdir=${wdir} \
				--coeffs=$GradientDistortionCoeffs \
				--in=${wdir}/${TXwImage}${i} \
				--out=${TXwFolder}/${TXwImage}${i}_gdc \
				--owarp=${TXwFolder}/xfms/${TXwImage}${i}_gdc_warp
			OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc "
			i=$(($i+1))
		done

	else
		log_Msg "NOT PERFORMING GRADIENT DISTORTION CORRECTION"

		i=1
		for Image in $TXwInputImages ; do
			${RUN} ${FSLDIR}/bin/fslreorient2std $Image ${TXwFolder}/${TXwImage}${i}_gdc
			OutputTXwImageSTRING="${OutputTXwImageSTRING}${TXwFolder}/${TXwImage}${i}_gdc "
			i=$(($i+1))
		done

	fi

	# Average Like (Same Modality) Scans

	if [ `echo $TXwInputImages | wc -w` -gt 1 ] ; then
		log_Msg "Averaging ${TXw} Images"
		log_Msg "mkdir -p ${TXwFolder}/Average${TXw}Images"
		mkdir -p ${TXwFolder}/Average${TXw}Images
		log_Msg "PERFORMING SIMPLE AVERAGING"
		${RUN} ${HCPPIPEDIR_PreFS}/AnatomicalAverage.sh -o ${TXwFolder}/${TXwImage} -s ${TXwTemplate} -m ${TemplateMask} -n -w ${TXwFolder}/Average${TXw}Images --noclean -v -b $BrainSize $OutputTXwImageSTRING
	else
		log_Msg "Not Averaging ${TXw} Images"
		log_Msg "ONLY ONE AVERAGE FOUND: COPYING"
		${RUN} ${FSLDIR}/bin/imcp ${TXwFolder}/${TXwImage}1_gdc ${TXwFolder}/${TXwImage}
	fi

	# ACPC align T1w or T2w image to specified MNI Template to create native volume space
	log_Msg "Aligning ${TXw} image to ${TXwTemplate} to create native volume space"
	log_Msg "mkdir -p ${TXwFolder}/ACPCAlignment"
	mkdir -p ${TXwFolder}/ACPCAlignment
	${RUN} ${HCPPIPEDIR_PreFS}/ACPCAlignment.sh \
		--workingdir=${TXwFolder}/ACPCAlignment \
		--in=${TXwFolder}/${TXwImage} \
		--ref=${TXwTemplate} \
		--out=${TXwFolder}/${TXwImage}_acpc \
		--omat=${TXwFolder}/xfms/acpc.mat \
		--brainsize=${BrainSize}

	# Brain Extraction(FNIRT-based Masking)
	log_Msg "Performing Brain Extraction using FNIRT-based Masking"
	log_Msg "mkdir -p ${TXwFolder}/BrainExtraction_FNIRTbased"
	mkdir -p ${TXwFolder}/BrainExtraction_FNIRTbased
	${RUN} ${HCPPIPEDIR_PreFS}/BrainExtraction_FNIRTbased.sh \
		--workingdir=${TXwFolder}/BrainExtraction_FNIRTbased \
		--in=${TXwFolder}/${TXwImage}_acpc \
		--ref=${TXwTemplate} \
		--refmask=${TemplateMask} \
		--ref2mm=${TXwTemplate2mm} \
		--ref2mmmask=${Template2mmMask} \
		--outbrain=${TXwFolder}/${TXwImage}_acpc_brain \
		--outbrainmask=${TXwFolder}/${TXwImage}_acpc_brain_mask \
		--fnirtconfig=${FNIRTConfig}

done

# End of looping over modalities (T1w and T2w)

# ------------------------------------------------------------------------------
#  T2w to T1w Registration and Optional Readout Distortion Correction
# ------------------------------------------------------------------------------

case $AvgrdcSTRING in

	${FIELDMAP_METHOD_OPT} | ${SPIN_ECHO_METHOD_OPT} | ${GENERAL_ELECTRIC_METHOD_OPT} | ${SIEMENS_METHOD_OPT})

		log_Msg "Performing ${AvgrdcSTRING} Readout Distortion Correction"
		wdir=${T2wFolder}/T2wToT1wDistortionCorrectAndReg
		if [ -d ${wdir} ] ; then
			# DO NOT change the following line to "rm -r ${wdir}" because the
			# chances of something going wrong with that are much higher, and
			# rm -r always needs to be treated with the utmost caution
			rm -r ${T2wFolder}/T2wToT1wDistortionCorrectAndReg
		fi

		log_Msg "mkdir -p ${wdir}"
		mkdir -p ${wdir}

		${RUN} ${HCPPIPEDIR_PreFS}/T2wToT1wDistortionCorrectAndReg.sh \
			--workingdir=${wdir} \
			--t1=${T1wFolder}/${T1wImage}_acpc \
			--t1brain=${T1wFolder}/${T1wImage}_acpc_brain \
			--t2=${T2wFolder}/${T2wImage}_acpc \
			--t2brain=${T2wFolder}/${T2wImage}_acpc_brain \
			--fmapmag=${MagnitudeInputName} \
			--fmapphase=${PhaseInputName} \
			--fmapgeneralelectric=${GEB0InputName} \
			--echodiff=${TE} \
			--SEPhaseNeg=${SpinEchoPhaseEncodeNegative} \
			--SEPhasePos=${SpinEchoPhaseEncodePositive} \
			--seechospacing=${SEEchoSpacing} \
			--seunwarpdir=${SEUnwarpDir} \
			--t1sampspacing=${T1wSampleSpacing} \
			--t2sampspacing=${T2wSampleSpacing} \
			--unwarpdir=${UnwarpDir} \
			--ot1=${T1wFolder}/${T1wImage}_acpc_dc \
			--ot1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
			--ot1warp=${T1wFolder}/xfms/${T1wImage}_dc \
			--ot2=${T1wFolder}/${T2wImage}_acpc_dc \
			--ot2warp=${T1wFolder}/xfms/${T2wImage}_reg_dc \
			--method=${AvgrdcSTRING} \
			--topupconfig=${TopupConfig} \
			--gdcoeffs=${GradientDistortionCoeffs} \
			--usejacobian=${UseJacobian}

		;;

	*)

		log_Msg "NOT PERFORMING READOUT DISTORTION CORRECTION"
		wdir=${T2wFolder}/T2wToT1wReg
		if [ -e ${wdir} ] ; then
			# DO NOT change the following line to "rm -r ${wdir}" because the
			# chances of something going wrong with that are much higher, and
			# rm -r always needs to be treated with the utmost caution
			rm -r ${T2wFolder}/T2wToT1wReg
		fi

		log_Msg "mkdir -p ${wdir}"
		mkdir -p ${wdir}

		${RUN} ${HCPPIPEDIR_PreFS}/T2wToT1wReg.sh \
			${wdir} \
			${T1wFolder}/${T1wImage}_acpc \
			${T1wFolder}/${T1wImage}_acpc_brain \
			${T2wFolder}/${T2wImage}_acpc \
			${T2wFolder}/${T2wImage}_acpc_brain \
			${T1wFolder}/${T1wImage}_acpc_dc \
			${T1wFolder}/${T1wImage}_acpc_dc_brain \
			${T1wFolder}/xfms/${T1wImage}_dc \
			${T1wFolder}/${T2wImage}_acpc_dc \
			${T1wFolder}/xfms/${T2wImage}_reg_dc

esac

# ------------------------------------------------------------------------------
#  Bias Field Correction: Calculate bias field using square root of the product
#  of T1w and T2w iamges.
# ------------------------------------------------------------------------------

log_Msg "Performing Bias Field Correction"
if [ ! -z ${BiasFieldSmoothingSigma} ] ; then
	BiasFieldSmoothingSigma="--bfsigma=${BiasFieldSmoothingSigma}"
fi

log_Msg "mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w"
mkdir -p ${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w

${RUN} ${HCPPIPEDIR_PreFS}/BiasFieldCorrection_sqrtT1wXT1w.sh \
	--workingdir=${T1wFolder}/BiasFieldCorrection_sqrtT1wXT1w \
	--T1im=${T1wFolder}/${T1wImage}_acpc_dc \
	--T1brain=${T1wFolder}/${T1wImage}_acpc_dc_brain \
	--T2im=${T1wFolder}/${T2wImage}_acpc_dc \
	--obias=${T1wFolder}/BiasField_acpc_dc \
	--oT1im=${T1wFolder}/${T1wImage}_acpc_dc_restore \
	--oT1brain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
	--oT2im=${T1wFolder}/${T2wImage}_acpc_dc_restore \
	--oT2brain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
	${BiasFieldSmoothingSigma}

# ------------------------------------------------------------------------------
# Create a one-step resampled version of the {T1w,T2w}_acpc_dc outputs
# (applied after GDC, which we don't bundle in, because of the possible need
# to average multiple T1/T2 inputs).

# This overwrites the {T1w,T2w}_acpc_dc outputs created above, and mimics what
# occurs at the beginning of PostFreeSurfer/CreateMyelinMaps.sh.
# Note that the CreateMyelinMaps equivalent is still needed though because
# (1) T1w_acpc_dc_restore_brain is (re)generated with a better estimate of
#     the brain mask, provided by FreeSurfer
# (2) the entire set of T2w_acpc_dc outputs needs to be regenerated, using the
#     refinement to the "T2wtoT1w" registration that FreeSurfer provides.

# Just implement inline, rather than writing a separate script
# Added 2/19/2019
# ------------------------------------------------------------------------------

log_Msg "Creating one-step resampled version of {T1w,T2w}_acpc_dc outputs"

# T1w
OutputOrigT1wToT1w=OrigT1w2T1w_PreFS  # Name for one-step resample warpfield
convertwarp --relout --rel --ref=${T1wTemplate} --premat=${T1wFolder}/xfms/acpc.mat --warp1=${T1wFolder}/xfms/${T1wImage}_dc --out=${T1wFolder}/xfms/${OutputOrigT1wToT1w}

OutputT1wImage=${T1wFolder}/${T1wImage}_acpc_dc
applywarp --rel --interp=spline -i ${T1wFolder}/${T1wImage} -r ${T1wTemplate} -w ${T1wFolder}/xfms/${OutputOrigT1wToT1w} -o ${OutputT1wImage}
fslmaths ${OutputT1wImage} -abs ${OutputT1wImage} -odt float  # Use -abs (rather than '-thr 0') to avoid introducing zeros
fslmaths ${OutputT1wImage} -div ${T1wFolder}/BiasField_acpc_dc ${OutputT1wImage}_restore
fslmaths ${OutputT1wImage}_restore -mas ${T1wFolder}/${T1wImage}_acpc_dc_brain ${OutputT1wImage}_restore_brain

#T2w
OutputOrigT2wToT1w=OrigT2w2T1w_PreFS  # Name for one-step resample warpfield
convertwarp --relout --rel --ref=${T1wTemplate} --premat=${T2wFolder}/xfms/acpc.mat --warp1=${T1wFolder}/xfms/${T2wImage}_reg_dc --out=${T1wFolder}/xfms/${OutputOrigT2wToT1w}

OutputT2wImage=${T1wFolder}/${T2wImage}_acpc_dc
applywarp --rel --interp=spline -i ${T2wFolder}/${T2wImage} -r ${T1wTemplate} -w ${T1wFolder}/xfms/${OutputOrigT2wToT1w} -o ${OutputT2wImage}
fslmaths ${OutputT2wImage} -abs ${OutputT2wImage} -odt float  # Use -abs (rather than '-thr 0') to avoid introducing zeros
fslmaths ${OutputT2wImage} -div ${T1wFolder}/BiasField_acpc_dc ${OutputT2wImage}_restore
fslmaths ${OutputT2wImage}_restore -mas ${T1wFolder}/${T1wImage}_acpc_dc_brain ${OutputT2wImage}_restore_brain

# Remove the file (warpfield) that serves as a proxy in FreeSurferPipeline for whether PostFreeSurfer has been run
# i.e., whether the T1w/T2w_acpc_dc* volumes reflect the PreFreeSurferPipeline versions (above)
# or the PostFreeSurferPipeline versions
OutputOrigT2wToT1wPostFS=OrigT2w2T1w  #Needs to match name used in both FreeSurferPipeline and PostFreeSurferPipeline
imrm ${OutputOrigT2wToT1wPostFS}

# ------------------------------------------------------------------------------
#  Atlas Registration to MNI152: FLIRT + FNIRT
#  Also applies the MNI registration to T1w and T2w images
#  (although, these will be overwritten, and the final versions generated via
#  a one-step resampling equivalent in PostFreeSurfer/CreateMyelinMaps.sh;
#  so, the primary purpose of the following is to generate the Atlas Registration itself).
# ------------------------------------------------------------------------------

log_Msg "Performing Atlas Registration to MNI152 (FLIRT and FNIRT)"

${RUN} ${HCPPIPEDIR_PreFS}/AtlasRegistrationToMNI152_FLIRTandFNIRT.sh \
	--workingdir=${AtlasSpaceFolder} \
	--t1=${T1wFolder}/${T1wImage}_acpc_dc \
	--t1rest=${T1wFolder}/${T1wImage}_acpc_dc_restore \
	--t1restbrain=${T1wFolder}/${T1wImage}_acpc_dc_restore_brain \
	--t2=${T1wFolder}/${T2wImage}_acpc_dc \
	--t2rest=${T1wFolder}/${T2wImage}_acpc_dc_restore \
	--t2restbrain=${T1wFolder}/${T2wImage}_acpc_dc_restore_brain \
	--ref=${T1wTemplate} \
	--refbrain=${T1wTemplateBrain} \
	--refmask=${TemplateMask} \
	--ref2mm=${T1wTemplate2mm} \
	--ref2mmmask=${Template2mmMask} \
	--owarp=${AtlasSpaceFolder}/xfms/acpc_dc2standard.nii.gz \
	--oinvwarp=${AtlasSpaceFolder}/xfms/standard2acpc_dc.nii.gz \
	--ot1=${AtlasSpaceFolder}/${T1wImage} \
	--ot1rest=${AtlasSpaceFolder}/${T1wImage}_restore \
	--ot1restbrain=${AtlasSpaceFolder}/${T1wImage}_restore_brain \
	--ot2=${AtlasSpaceFolder}/${T2wImage} \
	--ot2rest=${AtlasSpaceFolder}/${T2wImage}_restore \
	--ot2restbrain=${AtlasSpaceFolder}/${T2wImage}_restore_brain \
	--fnirtconfig=${FNIRTConfig}

log_Msg "Completed"

