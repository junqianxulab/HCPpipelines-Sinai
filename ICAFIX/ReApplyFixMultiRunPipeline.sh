#!/bin/bash

#
# # ReApplyFixMultiRunPipeline.sh
#
# ## Copyright Notice
#
# Copyright (C) 2017-2019 The Human Connectome Project/Connectome Coordination Facility
#
# * Washington University in St. Louis
# * University of Minnesota
# * Oxford University
#
# ## Author(s)
#
# * Matthew F. Glasser, Department of Anatomy and Neurobiology, Washington University in St. Louis
# * Timothy B. Brown, Neuroinformatics Research Group, Washington University in St. Louis
#
# ## Product
#
# [Human Connectome Project][HCP] (HCP) Pipelines
#
# ## License
#
# See the [LICENSE](https://github.com/Washington-Univesity/Pipelines/blob/master/LICENSE.md) file
#
# <!-- References -->
# [HCP]: http://www.humanconnectome.org
#

# ------------------------------------------------------------------------------
#  Show usage information for this script
# ------------------------------------------------------------------------------

usage()
{
	cat <<EOF

${g_script_name}: ReApplyFix Pipeline for MultiRun ICA+FIX

This script has two purposes (both in the context of MultiRun FIX):
1) Reapply FIX cleanup to the volume and default CIFTI (i.e., MSMSulc registered surfaces)
following manual reclassification of the FIX signal/noise components (see ApplyHandReClassifications.sh).
2) Apply FIX cleanup to the CIFTI from an alternative surface registration (e.g., MSMAll)
(either for the first time, or following manual reclassification of the components).
Only one of these two purposes can be accomplished per invocation.

Usage: ${g_script_name} PARAMETER...

PARAMETERs are [ ] = optional; < > = user supplied value

  Note: The PARAMETERs can be specified positionally (i.e. without using the --param=value
        form) by simply specifying all values on the command line in the order they are
		listed below.

		e.g. ${g_script_name} <path to study folder> <subject ID> <fMRINames> ...

  [--help] : show this usage information and exit
   --path=<path to study folder> OR --study-folder=<path to study folder>
   --subject=<subject ID> (e.g. 100610)
   --fmri-names=<fMRI names> an '@' symbol separated list of fMRI scan names (no whitespace)
     (e.g. rfMRI_REST1_LR@rfMRI_REST1_RL) (Do not include path, nifti extension, or the 'hp' string)
     All runs are assumed to have the same repetition time (TR).
   --concat-fmri-name=<root name of the concatenated fMRI scan file> (Do not include path, nifti extension, or the 'hp' string)
   --high-pass=<high-pass filter used in multi-run ICA+FIX>
   [--reg-name=<surface registration name> defaults to ${G_DEFAULT_REG_NAME}. (Use NONE for MSMSulc registration)
   [--low-res-mesh=<low res mesh number>] defaults to ${G_DEFAULT_LOW_RES_MESH}
   [--matlab-run-mode={0, 1, 2}] defaults to ${G_DEFAULT_MATLAB_RUN_MODE}
     0 = Use compiled MATLAB
     1 = Use interpreted MATLAB
     2 = Use interpreted Octave
   [--motion-regression={TRUE, FALSE}] defaults to ${G_DEFAULT_MOTION_REGRESSION}

EOF
}

# ------------------------------------------------------------------------------
#  Get the command line options for this script.
# ------------------------------------------------------------------------------

get_options()
{
	local arguments=("$@")

	# initialize global output variables
	unset p_StudyFolder      # ${1}
	unset p_Subject          # ${2}
	unset p_fMRINames        # ${3}
	unset p_ConcatName       # ${4}
	unset p_HighPass         # ${5}
	unset p_RegName          # ${6}
	unset p_LowResMesh       # ${7}
	unset p_MatlabRunMode    # ${8}
	unset p_MotionRegression # ${9}

	# set default values
	p_RegName=${G_DEFAULT_REG_NAME}
	p_LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	p_MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	p_MotionRegression=${G_DEFAULT_MOTION_REGRESSION}
	
	# parse arguments
	local num_args=${#arguments[@]}
	local argument
	local index=0

	while [ "${index}" -lt "${num_args}" ]; do
		argument=${arguments[index]}

		case ${argument} in
			--help)
				usage
				exit 1
				;;
			--path=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--study-folder=*)
				p_StudyFolder=${argument#*=}
				index=$(( index + 1 ))
				;;
			--subject=*)
				p_Subject=${argument#*=}
				index=$(( index + 1 ))
				;;
			--fmri-names=*)
				p_fMRINames=${argument#*=}
				index=$(( index + 1 ))
				;;
			--concat-fmri-name=*)
				p_ConcatName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--high-pass=*)
				p_HighPass=${argument#*=}
				index=$(( index + 1 ))
				;;
			--reg-name=*)
				p_RegName=${argument#*=}
				index=$(( index + 1 ))
				;;
			--low-res-mesh=*)
				p_LowResMesh=${argument#*=}
				index=$(( index + 1 ))
				;;
			--matlab-run-mode=*)
				p_MatlabRunMode=${argument#*=}
				index=$(( index + 1 ))
				;;
			--motion-regression=*)
				p_MotionRegression=${argument#*=}
				index=$(( index + 1 ))
				;;
			*)
				usage
				log_Err_Abort "unrecognized option: ${argument}"
				;;
		esac
	done

	local error_count=0

	# check required parameters
	if [ -z "${p_StudyFolder}" ]; then
		log_Err "Study Folder (--path= or --study-folder=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Study Folder: ${p_StudyFolder}"
	fi
	
	if [ -z "${p_Subject}" ]; then
		log_Err "Subject ID (--subject=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Subject ID: ${p_Subject}"
	fi	

	if [ -z "${p_fMRINames}" ]; then
		log_Err "fMRI Names (--fmri-names=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "fMRI Names: ${p_fMRINames}"
	fi

	if [ -z "${p_ConcatName}" ]; then
		log_Err "Concatenated fMRI scan name (--concat-fmri-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Concatenated fMRI scan name: ${p_ConcatName}"
	fi
	
	if [ -z "${p_HighPass}" ]; then
		log_Err "High Pass (--high-pass=) required"
		error_count=$(( error_count + 1 ))
	else
		# Checks on the validity of the --high-pass argument
		if [[ "${p_HighPass}" == "0" ]]; then
			log_Msg "--high-pass=0 corresponds to a linear detrend"
		fi
		if [[ "${p_HighPass}" == pd* ]]; then
			local hpNum=${p_HighPass:2}
		else
			local hpNum=${p_HighPass}
		fi
		if ! [[ "${hpNum}" =~ ^[-]?[0-9]+$ ]]; then
			log_Err "--high-pass value of ${p_HighPass} is not valid"
			error_count=$(( error_count + 1 ))
		fi
		if [[ $(echo "${hpNum} < 0" | bc) == "1" ]]; then  #Logic of this script does not support negative hp values
			log_Err "--high-pass value must not be negative"
			error_count=$(( error_count + 1 ))
		fi
		log_Msg "High Pass: ${p_HighPass}"
	fi

	if [ -z "${p_RegName}" ]; then
		log_Err "Reg Name (--reg-name=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Reg Name: ${p_RegName}"
	fi
		
	if [ -z "${p_LowResMesh}" ]; then
		log_Err "Low Res Mesh (--low-res-mesh=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Low Res Mesh: ${p_LowResMesh}"
	fi
	
	if [ -z "${p_MatlabRunMode}" ]; then
		log_Err "MATLAB run mode value (--matlab-run-mode=) required"
		error_count=$(( error_count + 1 ))
	else
		case ${p_MatlabRunMode} in
			0)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use compiled MATLAB"
				if [ -z "${MATLAB_COMPILER_RUNTIME}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${p_MatlabRunMode}, the MATLAB_COMPILER_RUNTIME environment variable must be set"
				else
					log_Msg "MATLAB_COMPILER_RUNTIME: ${MATLAB_COMPILER_RUNTIME}"
				fi
				;;
			1)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted MATLAB"
				;;
			2)
				log_Msg "MATLAB Run Mode: ${p_MatlabRunMode} - Use interpreted Octave"
				;;
			*)
				log_Err "MATLAB Run Mode value must be 0, 1, or 2"
				error_count=$(( error_count + 1 ))
				;;
		esac
	fi

	if [ -z "${p_MotionRegression}" ]; then
		log_Err "motion regression setting (--motion-regression=) required"
		error_count=$(( error_count + 1 ))
	else
		log_Msg "Motion Regression: ${p_MotionRegression}"
	fi

	if [ ${error_count} -gt 0 ]; then
		log_Err_Abort "For usage information, use --help"
	fi	
}

#
# NOTE:
#   Don't echo anything in this function other than the last echo
#   that outputs the return value
#
determine_old_or_new_fsl()
{
	local fsl_version=${1}
	local old_or_new
	local fsl_version_array
	local fsl_primary_version
	local fsl_secondary_version
	local fsl_tertiary_version

	# parse the FSL version information into primary, secondary, and tertiary parts
	fsl_version_array=(${fsl_version//./ })

	fsl_primary_version="${fsl_version_array[0]}"
	fsl_primary_version=${fsl_primary_version//[!0-9]/}
	
	fsl_secondary_version="${fsl_version_array[1]}"
	fsl_secondary_version=${fsl_secondary_version//[!0-9]/}
	
	fsl_tertiary_version="${fsl_version_array[2]}"
	fsl_tertiary_version=${fsl_tertiary_version//[!0-9]/}

	# determine whether we are using "OLD" or "NEW" FSL 
	# 6.0.0 and below is "OLD"
	# 6.0.1 and above is "NEW"
	
	if [[ $(( ${fsl_primary_version} )) -lt 6 ]] ; then
		# e.g. 4.x.x, 5.x.x
		old_or_new="OLD"
	elif [[ $(( ${fsl_primary_version} )) -gt 6 ]] ; then
		# e.g. 7.x.x
		old_or_new="NEW"
	else
		# e.g. 6.x.x
		if [[ $(( ${fsl_secondary_version} )) -gt 0 ]] ; then
			# e.g. 6.1.x
			old_or_new="NEW"
		else
			# e.g. 6.0.x
			if [[ $(( ${fsl_tertiary_version} )) -lt 1 ]] ; then
				# e.g. 6.0.0
				old_or_new="OLD"
			else
				# e.g. 6.0.1, 6.0.2, 6.0.3 ...
				old_or_new="NEW"
			fi
		fi
	fi

	echo ${old_or_new}
}

# ------------------------------------------------------------------------------
#  Show Tool Versions
# ------------------------------------------------------------------------------

show_tool_versions()
{
	# Show HCP pipelines version
	log_Msg "Showing HCP Pipelines version"
	cat ${HCPPIPEDIR}/version.txt

	# Show wb_command version
	log_Msg "Showing Connectome Workbench (wb_command) version"
	${CARET7DIR}/wb_command -version

	# Show fsl version
	log_Msg "Showing FSL version"
	fsl_version_get fsl_ver
	log_Msg "FSL version: ${fsl_ver}"

	old_or_new_version=$(determine_old_or_new_fsl ${fsl_ver})
	if [ "${old_or_new_version}" == "OLD" ] ; then
		log_Err_Abort "FSL version 6.0.1 or greater is required."
	fi
}

# ------------------------------------------------------------------------------
#  Check for whether or not we have hand reclassification files
# ------------------------------------------------------------------------------

have_hand_reclassification()
{
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRIName="${3}"
	local HighPass="${4}"

	[ -e "${StudyFolder}/${Subject}/MNINonLinear/Results/${fMRIName}/${fMRIName}_hp${HighPass}.ica/HandNoise.txt" ]
}

# ------------------------------------------------------------------------------
#  Main processing of script.
# ------------------------------------------------------------------------------

main()
{
	local this_script_dir=$(readlink -f "$(dirname "$0")")

	# Show tool versions
	show_tool_versions

	log_Msg "Starting main functionality"

	# Retrieve positional parameters
	local StudyFolder="${1}"
	local Subject="${2}"
	local fMRINames="${3}"
	local ConcatName="${4}"
	local HighPass="${5}"

	local RegName
	if [ -z "${6}" ]; then
		RegName=${G_DEFAULT_REG_NAME}
	else
		RegName="${6}"
	fi
	
	local LowResMesh
	if [ -z "${7}" ]; then
		LowResMesh=${G_DEFAULT_LOW_RES_MESH}
	else
		LowResMesh="${7}"
	fi
	
	local MatlabRunMode
	if [ -z "${8}" ]; then
		MatlabRunMode=${G_DEFAULT_MATLAB_RUN_MODE}
	else
		MatlabRunMode="${8}"
	fi

	local MotionRegression
	if [ -z "${9}" ]; then
		MotionRegression="${G_DEFAULT_MOTION_REGRESSION}"
	else
		MotionRegression="${9}"
	fi

	# Turn MotionRegression into an appropriate numeric value for fix_3_clean
	case $(echo ${MotionRegression} | tr '[:upper:]' '[:lower:]') in
        ( true | yes | 1)
            MotionRegression=1
            ;;
        ( false | no | none | 0)
            MotionRegression=0
            ;;
		*)
			log_Err_Abort "motion regression setting must be TRUE or FALSE"
			;;
	esac
		
	# Log values retrieved from positional parameters
	log_Msg "StudyFolder: ${StudyFolder}"
	log_Msg "Subject: ${Subject}"
	log_Msg "fMRINames: ${fMRINames}"
	log_Msg "ConcatName: ${ConcatName}"
	log_Msg "HighPass: ${HighPass}"
	log_Msg "RegName: ${RegName}"
	log_Msg "LowResMesh: ${LowResMesh}"
	log_Msg "MatlabRunMode: ${MatlabRunMode}"
	log_Msg "MotionRegression: ${MotionRegression}"

	# Naming Conventions and other variables
	local Caret7_Command="${CARET7DIR}/wb_command"
	log_Msg "Caret7_Command: ${Caret7_Command}"
	
	local RegString
	if [ "${RegName}" != "NONE" ] ; then
		RegString="_${RegName}"
	else
		RegString=""
	fi

	if [ ! -z ${LowResMesh} ] && [ ${LowResMesh} != ${G_DEFAULT_LOW_RES_MESH} ]; then
		RegString+=".${LowResMesh}k"
	fi

	log_Msg "RegString: ${RegString}"

	# For interpreted modes, make sure that matlab/octave has access to the functions it needs.
	# normalise.m (needed by functionhighpassandvariancenormalize.m) is in '${HCPPIPEDIR}/global/matlab'
	# Since we are NOT using the ${FSL_FIXDIR}/call_matlab.sh script to invoke matlab (unlike 'hcp_fix_multi_run')
	# we need to explicitly add ${FSL_FIXDIR} (all the fix-related functions)
	# and ${FSL_MATLAB_PATH} (e.g., read_avw.m, save_avw.m) to the matlab path as well.
	# Several additional necessary environment variables (e.g., ${FSL_FIX_CIFTIRW} and ${FSL_FIX_WBC})
	# are set in FSL_FIXDIR/settings.sh, which is sourced below for interpreted modes.
	# Note that the ciftiopen.m, ciftisave.m functions are added to the path through the ${FSL_FIX_WBC} 
	# environment variable within fix_3_clean.m itself.
	export FSL_MATLAB_PATH="${FSLDIR}/etc/matlab"
	local ML_PATHS="addpath('${FSL_FIXDIR}'); addpath('${FSL_MATLAB_PATH}'); addpath('${HCPPIPEDIR}/global/matlab'); addpath('${this_script_dir}/scripts');"

	# Some defaults
	local aggressive=0
	local newclassification=0
	local hp=${HighPass}
	local DoVol=0
	local fixlist=".fix"

	# ConcatName (${4}) is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
	ConcatNameOnly=$(basename $($FSLDIR/bin/remove_ext $ConcatName))
	# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
	ConcatName="${StudyFolder}/${Subject}/MNINonLinear/Results/${ConcatNameOnly}/${ConcatNameOnly}"

    # If we have a hand classification and no regname, reapply fix to the volume as well
	if have_hand_reclassification ${StudyFolder} ${Subject} ${ConcatNameOnly} ${hp}
	then
		fixlist="HandNoise.txt"
		#TSC: if regname (which applies to the surface) isn't NONE, assume the hand classification was previously already applied to the volume data
		if [[ "${RegName}" == "NONE" ]]
		then
			DoVol=1
		fi
	fi
	# WARNING: fix_3_clean doesn't actually do anything different based on the value of DoVol (its 5th argument).
	# Rather, if a 5th argument is present, fix_3_clean does NOT apply cleanup to the volume, *regardless* of whether
	# that 5th argument is 0 or 1 (or even a non-sensical string such as 'foo').
	# It is for that reason that the code below needs to use separate calls to fix_3_clean, with and without DoVol
	# as an argument, rather than simply passing in the value of DoVol as set within this script.
	# Not sure if/when this non-intuitive behavior of fix_3_clean will change, but this is accurate as of fix1.067

	log_Msg "Use fixlist=$fixlist"
	
	local fmris=${fMRINames//@/ } # replaces the @ that combines the filenames with a space
	log_Msg "fmris: ${fmris}"

	DIR=`pwd`
	log_Msg "PWD : $DIR"

	## MPH: High level "master" conditional that checks whether the files necessary for fix_3_clean
	## already exist (i.e., reapplying FIX cleanup following manual classification).
	## If so, we can skip all the following looping through individual runs and concatenation, 
	## and resume at the "Housekeeping related to files expected for fix_3_clean" section

	local ConcatNameNoExt=$($FSLDIR/bin/remove_ext $ConcatName)  # No extension, but still includes the directory path

	if [[ -f ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii ]]; then
		log_Warn "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii already exists."
		if (( DoVol && $(${FSLDIR}/bin/imtest "${ConcatNameNoExt}_hp${hp}") )); then
			log_Warn "$($FSLDIR/bin/imglob -extension ${ConcatNameNoExt}_hp${hp}) already exists."
		fi
		log_Warn "Using preceding existing concatenated file(s) for recleaning."
	else  # bash GOTO construct would be helpful here, to skip a bunch of code
		# NOT RE-INDENTING ALL THE FOLLOWING CODE
		# This 'else' clause terminates at the start of the
		# "Housekeeping related to files expected for fix_3_clean" section

	###LOOP HERE --> Since the files are being passed as a group

	#echo $fmris | tr ' ' '\n' #separates paths separated by ' '

	## ---------------------------------------------------------------------------
	## Preparation (highpass) on the individual runs
	## ---------------------------------------------------------------------------

	#Loops over the runs and do highpass on each of them
	log_Msg "Looping over files and doing highpass to each of them"
	
    NIFTIvolMergeSTRING=""
    NIFTIvolhpVNMergeSTRING=""
    SBRefVolSTRING=""
    MeanVolSTRING=""
    VNVolSTRING=""
    CIFTIMergeSTRING=""
    CIFTIhpVNMergeSTRING=""
    MeanCIFTISTRING=""
    VNCIFTISTRING=""

	for fmriname in $fmris ; do
		# fmriname is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
		fmriname=$(basename $($FSLDIR/bin/remove_ext $fmriname))
		# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
	    fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fmriname}/${fmriname}"

		log_Msg "Top of loop through fmris: fmri: ${fmri}"

		fmriNoExt=$($FSLDIR/bin/remove_ext $fmri)  # $fmriNoExt still includes leading directory components

		# Create necessary strings for merging across runs
		# N.B. Some of these files don't exist yet, and are about to get created
		NIFTIvolMergeSTRING+="${fmriNoExt}_demean "
		NIFTIvolhpVNMergeSTRING+="${fmriNoExt}_hp${hp}_vnts "  #These are the individual run, VN'ed *time series*
		SBRefVolSTRING+="${fmriNoExt}_SBRef "
		MeanVolSTRING+="${fmriNoExt}_mean "
		VNVolSTRING+="${fmriNoExt}_hp${hp}_vn "  #These are the individual run, VN'ed NIFTI *maps* (created by functionhighpassandvariancenormalize)
		CIFTIMergeSTRING+="-cifti ${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii "
		CIFTIhpVNMergeSTRING+="-cifti ${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii "
		MeanCIFTISTRING+="-cifti ${fmriNoExt}_Atlas${RegString}_mean.dscalar.nii "
		VNCIFTISTRING+="-cifti ${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dscalar.nii "  #These are the individual run, VN'ed CIFTI *maps* (created by functionhighpassandvariancenormalize)

		cd `dirname $fmri`
		fmri=`basename $fmri`  # After this, $fmri no longer includes the leading directory components
		fmri=`$FSLDIR/bin/imglob $fmri`  # After this, $fmri will no longer have an extension (if there was one initially)
		log_Msg "fmri: $fmri"
		if [ `$FSLDIR/bin/imtest $fmri` != 1 ]; then
			log_Err_Abort "Invalid 4D_FMRI input file specified: ${fmri}"
		fi

		#Demean volumes
		if (( DoVol )); then
			if [ `$FSLDIR/bin/imtest ${fmri}_demean` != 1 ]; then
				${FSLDIR}/bin/fslmaths $fmri -Tmean ${fmri}_mean
				${FSLDIR}/bin/fslmaths $fmri -sub ${fmri}_mean ${fmri}_demean
			else
				log_Warn "$($FSLDIR/bin/imglob -extension ${fmri}_demean) already exists. Using existing version"
			fi
		fi

	    #Demean CIFTI
		if [[ ! -f ${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii ]]; then
	        ${Caret7_Command} -cifti-reduce ${fmriNoExt}_Atlas${RegString}.dtseries.nii MEAN ${fmriNoExt}_Atlas${RegString}_mean.dscalar.nii
	        ${Caret7_Command} -cifti-math "TCS - MEAN" ${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii -var TCS ${fmriNoExt}_Atlas${RegString}.dtseries.nii -var MEAN ${fmriNoExt}_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
		else
			log_Warn "${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii already exists. Using existing version"
        fi

		# ReApplyFixMultiRunPipeline has only a single pass through functionhighpassandvariancenormalize.
		# whereas hcp_fix_multi_run has two (because it runs melodic, which is not re-run here).
		# So, the "1st pass" VN is the only-pass, and there is no "2nd pass" VN.
		# Note that functionhighpassandvariancenormalize internally determines whether to process
		# the volume based on whether ${RegString} is empty. (Thus no explicit DoVol conditional
		# in the following).
		# If ${RegString} is empty, the movement regressors will also automatically get re-filtered.
		
		tr=`$FSLDIR/bin/fslval $fmri pixdim4`  #No checking currently that TR is same across runs
		log_Msg "tr: $tr"

		## Check if "1st pass" VN on the individual runs is needed; high-pass gets done here as well
        if [[ ! -f "${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii" || \
              ! -f "${fmriNoExt}_Atlas${RegString}_vn.dscalar.nii" || \
              ( $DoVol == "1" && \
			    ( `$FSLDIR/bin/imtest "${fmriNoExt}_hp${hp}_vnts"` != 1 || \
                  `$FSLDIR/bin/imtest "${fmriNoExt}_hp${hp}_vn"` != 1 )) ]]
        then

			log_Msg "processing FMRI file $fmri with highpass $hp"
	    	case ${MatlabRunMode} in
		    0)
			    # Use Compiled Matlab
				local matlab_exe="${HCPPIPEDIR}"
				matlab_exe+="/ICAFIX/scripts/Compiled_functionhighpassandvariancenormalize/run_functionhighpassandvariancenormalize.sh"

				# Do NOT enclose string variables inside an additional single quote because all
				# variables are already passed into the compiled binary as strings
				local matlab_function_arguments=("${tr}" "${hp}" "${fmri}" "${Caret7_Command}" "${RegString}")

				# ${MATLAB_COMPILER_RUNTIME} contains the location of the MCR used to compile functionhighpassandvariancenormalize.m
				local matlab_cmd=("${matlab_exe}" "${MATLAB_COMPILER_RUNTIME}" "${matlab_function_arguments[@]}")

				# redirect tokens must be parsed by bash before doing variable expansion, and thus can't be inside a variable
				# MPH: Going to let Compiled MATLAB use the existing stdout and stderr, rather than creating a separate log file
				#local matlab_logfile=".reapplyfixmultirun.${concatfmri}${RegString}.functionhighpassandvariancenormalize.log"
				#"${matlab_cmd[@]}" >> "${matlab_logfile}" 2>&1
				log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
				"${matlab_cmd[@]}"
                ;;

            1 | 2)
                # Use interpreted MATLAB or Octave
				if [[ ${MatlabRunMode} == "1" ]]; then
					local interpreter=(matlab -nojvm -nodisplay -nosplash)
				else
					local interpreter=(octave-cli -q --no-window-system)
				fi
				
				# ${hp} needs to be passed in as a string, to handle the hp=pd* case
				local matlab_cmd="${ML_PATHS} functionhighpassandvariancenormalize(${tr}, '${hp}', '${fmri}', '${Caret7_Command}', '${RegString}');"
				
				log_Msg "Run interpreted MATLAB/Octave (${interpreter[@]}) with command..."
				log_Msg "${matlab_cmd}"

				# Use bash redirection ("here-document") to pass multiple commands into matlab
				# (Necessary to protect the semicolons that separate matlab commands, which would otherwise
				# get interpreted as separating different bash shell commands)
				# See note below about why we export FSL_FIX_WBC after sourcing FSL_FIXDIR/settings.sh
				(source "${FSL_FIXDIR}/settings.sh"; export FSL_FIX_WBC="${Caret7_Command}"; "${interpreter[@]}" <<M_PROG
# Do NOT wrap the following in quotes (o.w. the entire set of commands gets interpreted as a single string)
${matlab_cmd}
M_PROG
)
                ;;

			*)
				# Unsupported MATLAB run mode
				log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
				;;
			
			esac

			# Demean the movement regressors (in the 'fake-NIFTI' format returned by functionhighpassandvariancenormalize)
			# MPH: This is irrelevant, since we aren't doing anything with these files.
			# (i.e,. not regenerating ${concatfmrihp}.ica/mc/prefiltered_func_data_mcf_conf)
			# But do it anyway, just to ensure that the files left behind are demeaned in the DoVol case
			if (( DoVol )); then
				fslmaths ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf -Tmean ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_mean
				fslmaths ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf -sub ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_mean ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf
				$FSLDIR/bin/imrm ${fmri}_hp${hp}.ica/mc/prefiltered_func_data_mcf_conf_mean
			fi
			
			log_Msg "Dims: $(cat ${fmri}_dims.txt)"

		else
			log_Warn "Skipping functionhighpassandvariancenormalize because expected files for ${fmri} already exist"

	    fi

		cd ${DIR}  # Return to directory where script was launched
		
	    log_Msg "Bottom of loop through fmris: fmri: ${fmri}"

	done  ###END LOOP (for fmriname in $fmris; do)

	## ---------------------------------------------------------------------------
	## Concatenate the individual runs and create necessary files
	## ---------------------------------------------------------------------------

	if (( DoVol )); then
		if [ `$FSLDIR/bin/imtest ${ConcatNameNoExt}` != 1 ]; then
		    # Merge volumes from the individual runs
			fslmerge -tr ${ConcatNameNoExt}_demean ${NIFTIvolMergeSTRING} $tr
			fslmerge -tr ${ConcatNameNoExt}_hp${hp}_vnts ${NIFTIvolhpVNMergeSTRING} $tr
			fslmerge -t  ${ConcatNameNoExt}_SBRef ${SBRefVolSTRING}
			fslmerge -t  ${ConcatNameNoExt}_mean ${MeanVolSTRING}
			fslmerge -t  ${ConcatNameNoExt}_hp${hp}_vn ${VNVolSTRING}
		    # Average across runs
			fslmaths ${ConcatNameNoExt}_SBRef -Tmean ${ConcatNameNoExt}_SBRef
			fslmaths ${ConcatNameNoExt}_mean -Tmean ${ConcatNameNoExt}_mean  # "Grand" mean across runs
			fslmaths ${ConcatNameNoExt}_demean -add ${ConcatNameNoExt}_mean ${ConcatNameNoExt}
		      # Preceding line adds back in the "grand" mean
			  # Resulting file not used below, but want this concatenated version (without HP or VN) to exist
			fslmaths ${ConcatNameNoExt}_hp${hp}_vn -Tmean ${ConcatNameNoExt}_hp${hp}_vn  # Mean VN map across the individual runs
			fslmaths ${ConcatNameNoExt}_hp${hp}_vnts -mul ${ConcatNameNoExt}_hp${hp}_vn ${ConcatNameNoExt}_hp${hp} 
              # Preceding line restores the mean VN map
			fslmaths ${ConcatNameNoExt}_SBRef -bin ${ConcatNameNoExt}_brain_mask
              # Preceding line creates mask to be used in melodic for suppressing memory error - Takuya Hayashi
		else
			log_Warn "$($FSLDIR/bin/imglob -extension ${ConcatNameNoExt}) already exists. Using existing version"
		fi
	fi

	# Same thing for the CIFTI
    if [[ ! -f ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii ]]; then
        ${Caret7_Command} -cifti-merge ${ConcatNameNoExt}_Atlas${RegString}_demean.dtseries.nii ${CIFTIMergeSTRING}
        ${Caret7_Command} -cifti-average ${ConcatNameNoExt}_Atlas${RegString}_mean.dscalar.nii ${MeanCIFTISTRING}
        ${Caret7_Command} -cifti-math "TCS + MEAN" ${ConcatNameNoExt}_Atlas${RegString}.dtseries.nii -var TCS ${ConcatNameNoExt}_Atlas${RegString}_demean.dtseries.nii -var MEAN ${ConcatNameNoExt}_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat
        ${Caret7_Command} -cifti-merge ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii ${CIFTIhpVNMergeSTRING}
        ${Caret7_Command} -cifti-average ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dscalar.nii ${VNCIFTISTRING}
        ${Caret7_Command} -cifti-math "TCS * VN" ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii -var TCS ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii -var VN ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dscalar.nii -select 1 1 -repeat
    else
		log_Warn "${ConcatNameNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii already exists. Using existing version"
	fi
	
	# At this point the concatenated VN'ed time series (both volume and CIFTI, following the "1st pass" VN) can be deleted
	# MPH: Conditional on DoVol not needed in the following, since at worst, we'll try removing a file that doesn't exist
	log_Msg "Removing the concatenated VN'ed time series"
	$FSLDIR/bin/imrm ${ConcatNameNoExt}_hp${hp}_vnts
	/bin/rm -f ${ConcatNameNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii

	# Nor do we need the concatenated demeaned time series (either volume or CIFTI)
	log_Msg "Removing the concatenated demeaned time series"
	$FSLDIR/bin/imrm ${ConcatNameNoExt}_demean
	/bin/rm -f ${ConcatNameNoExt}_Atlas${RegString}_demean.dtseries.nii

	# Also, we no longer need the individual run VN'ed or demeaned time series (either volume or CIFTI); delete to save space
	for fmriname in $fmris ; do
		# fmriname is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
		fmriname=$(basename $($FSLDIR/bin/remove_ext $fmriname))
		# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
	    fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fmriname}/${fmriname}"

		log_Msg "Removing the individual run VN'ed and demeaned time series for ${fmri}"

		fmriNoExt=$($FSLDIR/bin/remove_ext $fmri)  # $fmriNoExt still includes leading directory components
		$FSLDIR/bin/imrm ${fmriNoExt}_hp${hp}_vnts
		$FSLDIR/bin/imrm ${fmriNoExt}_demean
		/bin/rm -f ${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dtseries.nii
		/bin/rm -f ${fmriNoExt}_Atlas${RegString}_demean.dtseries.nii

		# Following removes the individual run hp'ed time series
		# MPH, 12/21/2018: Leaving them for now
		#	log_Msg "Removing the individual run HP'ed time series for ${fmri}"
		#	$FSLDIR/bin/imrm ${fmriNoExt}_hp${hp}
		#	/bin/rm -f ${fmriNoExt}_Atlas${RegString}_hp${hp}.dtseries.nii
	done

	## Terminate the 'else' clause of the "master" conditional that checked whether
	## the preceding code needed to be run.
	fi

	## ---------------------------------------------------------------------------
	## Housekeeping related to files expected for fix_3_clean
	## ---------------------------------------------------------------------------

	local ConcatFolder=`dirname ${ConcatName}`
	cd ${ConcatFolder}

	local concatfmri=`basename ${ConcatNameNoExt}`  # Directory path is now removed
	local concatfmrihp=${concatfmri}_hp${hp}

    #this directory should exist and not be empty (i.e., melodic has already been run)
	cd ${concatfmrihp}.ica

	#This is the concated volume time series from the 1st pass VN, with the mean VN map multiplied back in
	${FSLDIR}/bin/imrm filtered_func_data
	${FSLDIR}/bin/imln ../${concatfmrihp} filtered_func_data

	#This is the concated CIFTI time series from the 1st pass VN, with the mean VN map multiplied back in
	if [[ -f ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii ]] ; then
		log_Msg "FOUND FILE: ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii"
		log_Msg "Performing imln"

		/bin/rm -f Atlas.dtseries.nii
		$FSLDIR/bin/imln ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii Atlas.dtseries.nii
		
		log_Msg "START: Showing linked files"
		ls -l ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii
		ls -l Atlas.dtseries.nii
		log_Msg "END: Showing linked files"
	else
		log_Err_Abort "FILE NOT FOUND: ../${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii"
	fi

	## ---------------------------------------------------------------------------
	## Run fix_3_clean
	## ---------------------------------------------------------------------------

	# MPH: We need to invoke fix_3_clean directly, rather than through 'fix -a <options>' because
	# the latter does not provide access to the "DoVol" option within the former.
	# (Also, 'fix -a' is hard-coded to use '.fix' as the list of noise components, although that 
	# could be worked around).

	export FSL_FIX_WBC="${Caret7_Command}"
	# WARNING: fix_3_clean uses the environment variable FSL_FIX_WBC, but most previous
	# versions of FSL_FIXDIR/settings.sh (v1.067 and earlier) have a hard-coded value for
	# FSL_FIX_WBC, and don't check whether it is already defined in the environment.
	# Thus, when settings.sh file gets sourced, there is a possibility that the version of
	# wb_command is no longer the same as that specified by ${Caret7_Command}.  So, after
	# sourcing settings.sh below, we explicitly set FSL_FIX_WBC back to value of ${Caret7_Command}.
	# (This may only be relevant for interpreted matlab/octave modes).

	log_Msg "Running fix_3_clean"

	AlreadyHP="-1"

	case ${MatlabRunMode} in

		# See important WARNING above regarding why ${DoVol} is NOT included as an argument when DoVol=1 !!
		
		0)
			# Use Compiled Matlab

			local matlab_exe="${FSL_FIXDIR}/compiled/$(uname -s)/$(uname -m)/run_fix_3_clean.sh"

			# Do NOT enclose string variables inside an additional single quote because all
			# variables are already passed into the compiled binary as strings
			local matlab_function_arguments=("${fixlist}" "${aggressive}" "${MotionRegression}" "${AlreadyHP}")
			if (( ! DoVol )); then
				matlab_function_arguments+=("${DoVol}")
			fi
			
			# fix_3_clean is part of the FIX distribution, which was compiled under its own (separate) MCR.
			# If ${FSL_FIX_MCR} is already defined in the environment, use that for the MCR location.
			# If not, the appropriate MCR version for use with fix_3_clean should be set in $FSL_FIXDIR/settings.sh.
			if [ -z "${FSL_FIX_MCR}" ]; then
				source ${FSL_FIXDIR}/settings.sh
				export FSL_FIX_WBC="${Caret7_Command}"
				# If FSL_FIX_MCR is still not defined after sourcing settings.sh, we have a problem
				if [ -z "${FSL_FIX_MCR}" ]; then
					log_Err_Abort "To use MATLAB run mode: ${MatlabRunMode}, the FSL_FIX_MCR environment variable must be set"
				fi
			fi
			log_Msg "FSL_FIX_MCR: ${FSL_FIX_MCR}"
							
			local matlab_cmd=("${matlab_exe}" "${FSL_FIX_MCR}" "${matlab_function_arguments[@]}")

			# redirect tokens must be parsed by bash before doing variable expansion, and thus can't be inside a variable
			# MPH: Going to let Compiled MATLAB use the existing stdout and stderr, rather than creating a separate log file
			#local matlab_logfile=".reapplyfixmultirun.${concatfmri}${RegString}.fix_3_clean.matlab.log"
			#log_Msg "Run MATLAB command: ${matlab_cmd[*]} >> ${matlab_logfile} 2>&1"
			#"${matlab_cmd[@]}" >> "${matlab_logfile}" 2>&1
			log_Msg "Run compiled MATLAB: ${matlab_cmd[*]}"
			"${matlab_cmd[@]}"
			;;
		
		1 | 2)
			# Use interpreted MATLAB or Octave
			if [[ ${MatlabRunMode} == "1" ]]; then
				local interpreter=(matlab -nojvm -nodisplay -nosplash)
			else
				local interpreter=(octave-cli -q --no-window-system)
			fi

			if (( DoVol )); then
				local matlab_cmd="${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${MotionRegression},${AlreadyHP});"
			else
				local matlab_cmd="${ML_PATHS} fix_3_clean('${fixlist}',${aggressive},${MotionRegression},${AlreadyHP},${DoVol});"
			fi
			
			log_Msg "Run interpreted MATLAB/Octave (${interpreter[@]}) with command..."
			log_Msg "${matlab_cmd}"
			
            # Use bash redirection ("here-document") to pass multiple commands into matlab
			# (Necessary to protect the semicolons that separate matlab commands, which would otherwise
			# get interpreted as separating different bash shell commands)
			(source "${FSL_FIXDIR}/settings.sh"; export FSL_FIX_WBC="${Caret7_Command}"; "${interpreter[@]}" <<M_PROG
# Do NOT wrap the following in quotes (o.w. the entire set of commands gets interpreted as a single string)
${matlab_cmd}
M_PROG
)
			;;

		*)
			# Unsupported MATLAB run mode
			log_Err_Abort "Unsupported MATLAB run mode value: ${MatlabRunMode}"
			;;
	esac

	log_Msg "Done running fix_3_clean"

	# Return to ${ConcatFolder}
	# Do not use 'cd ${ConcatFolder}', because ${ConcatFolder} may not be an absolute path
	cd ..

	## ---------------------------------------------------------------------------
	## Rename some files (relative to the default names coded in fix_3_clean)
	## ---------------------------------------------------------------------------

	# Remove any existing old versions of the cleaned data (normally they should be overwritten
	# in the renaming that follows, but this ensures that any old versions don't linger)
	/bin/rm -f ${concatfmri}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	/bin/rm -f ${concatfmri}_Atlas${RegString}_hp${hp}_clean_vn.dscalar.nii

	if (( DoVol )); then
	    $FSLDIR/bin/imrm  ${concatfmrihp}_clean
	    $FSLDIR/bin/imrm  ${concatfmrihp}_clean_vn
	fi

	# Rename some of the outputs from fix_3_clean.
	# Note that the variance normalization ("_vn") outputs require use of fix1.067 or later
	# So check whether those files exist before moving/renaming them
	if [ -f ${concatfmrihp}.ica/Atlas_clean.dtseries.nii ]; then
	    /bin/mv ${concatfmrihp}.ica/Atlas_clean.dtseries.nii ${concatfmri}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	else
	    log_Err_Abort "Something went wrong; ${concatfmrihp}.ica/Atlas_clean.dtseries.nii wasn't created"
	fi
	if [ -f ${concatfmrihp}.ica/Atlas_clean_vn.dscalar.nii ]; then
	    /bin/mv ${concatfmrihp}.ica/Atlas_clean_vn.dscalar.nii ${concatfmri}_Atlas${RegString}_hp${hp}_clean_vn.dscalar.nii
	fi

	if (( DoVol )); then
	    $FSLDIR/bin/immv ${concatfmrihp}.ica/filtered_func_data_clean ${concatfmrihp}_clean
	    if [ "$?" -ne "0" ]; then
		log_Err_Abort "Something went wrong; ${concatfmrihp}.ica/filtered_func_data_clean wasn't created"
	    fi
	    if [ `$FSLDIR/bin/imtest ${concatfmrihp}.ica/filtered_func_data_clean_vn` = 1 ]; then
		$FSLDIR/bin/immv ${concatfmrihp}.ica/filtered_func_data_clean_vn ${concatfmrihp}_clean_vn
	    fi
	fi
	log_Msg "Done renaming files"

    # Remove the 'fake-NIFTI' file created in fix_3_clean for high-pass filtering of the CIFTI (if it exists)
	$FSLDIR/bin/imrm ${concatfmrihp}.ica/Atlas
 
	## ---------------------------------------------------------------------------
	## Split the cleaned volume and CIFTI back into individual runs.
	## ---------------------------------------------------------------------------

	## The cleaned volume and CIFTI have no mean.
	## The time series of the individual runs were variance normalized via the 1st pass through functionhighpassandvariancenormalize.
	## The mean VN map (across runs) was then multiplied into the concatenated time series, and that became the input to FIX.
	## We now reverse that process.
	## i.e., the mean VN (across runs) is divided back out, and the VN map for the individual run multiplied back in.
	## Then the mean is added back in to return the timeseries to its original state minus the noise (as estimated by FIX).

	cd ${DIR}  # Return to directory where script was launched
	
	log_Msg "Splitting cifti back into individual runs"
	if (( DoVol )); then
	   log_Msg "Also splitting nifti back into individual runs"
	fi
	Start="1"
	for fmriname in $fmris ; do
		# fmriname is expected to NOT include path info, or a nifti extension; make sure that is indeed the case
		fmriname=$(basename $($FSLDIR/bin/remove_ext $fmriname))
		# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
	    fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${fmriname}/${fmriname}"

		fmriNoExt=$($FSLDIR/bin/remove_ext $fmri)  # $fmriNoExt still includes leading directory components
		NumTPS=`${Caret7_Command} -file-information ${fmriNoExt}_Atlas${RegString}.dtseries.nii -no-map-info -only-number-of-maps`
	    Stop=`echo "${NumTPS} + ${Start} -1" | bc -l`
	    log_Msg "${fmriNoExt}: Start=${Start} Stop=${Stop}"
	
	    cifti_out=${fmriNoExt}_Atlas${RegString}_hp${hp}_clean.dtseries.nii
	    ${Caret7_Command} -cifti-merge ${cifti_out} -cifti ${ConcatFolder}/${concatfmri}_Atlas${RegString}_hp${hp}_clean.dtseries.nii -column ${Start} -up-to ${Stop}
	    ${Caret7_Command} -cifti-math "((TCS / VNA) * VN) + Mean" ${cifti_out} -var TCS ${cifti_out} -var VNA ${ConcatFolder}/${concatfmri}_Atlas${RegString}_hp${hp}_vn.dscalar.nii -select 1 1 -repeat -var VN ${fmriNoExt}_Atlas${RegString}_hp${hp}_vn.dscalar.nii -select 1 1 -repeat -var Mean ${fmriNoExt}_Atlas${RegString}_mean.dscalar.nii -select 1 1 -repeat

	    readme_for_cifti_out=${cifti_out%.dtseries.nii}.README.txt
	    touch ${readme_for_cifti_out}
	    short_cifti_out=${cifti_out##*/}
		# MPH: Overwrite file, if it already exists
	    echo "${short_cifti_out} was generated by applying \"multi-run FIX\" (using '${g_script_name}')" >| ${readme_for_cifti_out}
	    echo "across the following individual runs:" >> ${readme_for_cifti_out}
	    for readme_fmri_name in ${fmris} ; do
    	    # Make sure that readme_fmri_name is indeed without path or extension
			readme_fmri_name=$(basename $($FSLDIR/bin/remove_ext $readme_fmri_name))
			# But, then generate the absolute path so we can reuse the code from hcp_fix_multi_run
    	    readme_fmri="${StudyFolder}/${Subject}/MNINonLinear/Results/${readme_fmri_name}/${readme_fmri_name}"
		    echo "  ${readme_fmri}" >> ${readme_for_cifti_out}
	    done
		
		if (( DoVol )); then
			volume_out=${fmriNoExt}_hp${hp}_clean.nii.gz
	        ${Caret7_Command} -volume-merge ${volume_out} -volume ${ConcatFolder}/${concatfmrihp}_clean.nii.gz -subvolume ${Start} -up-to ${Stop}
	        fslmaths ${volume_out} -div ${ConcatFolder}/${concatfmrihp}_vn -mul ${fmriNoExt}_hp${hp}_vn -add ${fmriNoExt}_mean ${volume_out}
        fi
	    Start=`echo "${Start} + ${NumTPS}" | bc -l`
	done

	## ---------------------------------------------------------------------------
	## Remove all the large time series files in ${ConcatFolder}
	## ---------------------------------------------------------------------------

	## Deleting these files would save a lot of space.
	## But downstream scripts (e.g., RestingStateStats) assume they exist, and
	## if deleted they would therefore need to be re-created "on the fly" later

	# cd ${ConcatFolder}
        # log_Msg "Removing large (concatenated) time series files from ${ConcatFolder}"
	# $FSLDIR/bin/imrm ${concatfmri}
	# $FSLDIR/bin/imrm ${concatfmri}_hp${hp}
	# $FSLDIR/bin/imrm ${concatfmri}_hp${hp}_clean
	# /bin/rm -f ${concatfmri}_Atlas${RegString}.dtseries.nii
	# /bin/rm -f ${concatfmri}_Atlas${RegString}_hp${hp}.dtseries.nii
	# /bin/rm -f ${concatfmri}_Atlas${RegString}_hp${hp}_clean.dtseries.nii

	cd ${DIR}

	log_Msg "Completed!"
}

# ------------------------------------------------------------------------------
#  "Global" processing - everything above here should be in a function
# ------------------------------------------------------------------------------

set -e # If any command exits with non-zero value, this script exits

# Establish defaults
G_DEFAULT_REG_NAME="NONE"
G_DEFAULT_LOW_RES_MESH=32
G_DEFAULT_MATLAB_RUN_MODE=1		# Use interpreted MATLAB
G_DEFAULT_MOTION_REGRESSION="FALSE"

# Set global variables
g_script_name=$(basename "${0}")

# Allow script to return a Usage statement, before any other output
if [ "$#" = "0" ]; then
    usage
    exit 1
fi

# Verify that HCPPIPEDIR environment variable is set
if [ -z "${HCPPIPEDIR}" ]; then
	echo "${g_script_name}: ABORTING: HCPPIPEDIR environment variable must be set"
	exit 1
fi

# Load function libraries
source "${HCPPIPEDIR}/global/scripts/log.shlib" # Logging related functions
source "${HCPPIPEDIR}/global/scripts/fsl_version.shlib" # Functions for getting FSL version
log_Msg "HCPPIPEDIR: ${HCPPIPEDIR}"

# Verify any other needed environment variables are set
log_Check_Env_Var CARET7DIR
log_Check_Env_Var FSLDIR
log_Check_Env_Var FSL_FIXDIR

# Determine whether named or positional parameters are used
if [[ ${1} == --* ]]; then
	# Named parameters (e.g. --parameter-name=parameter-value) are used
	log_Msg "Using named parameters"

	# Get command line options
	get_options "$@"

	# Invoke main functionality
	#     ${1}               ${2}           ${3}             ${4}                  ${5}            ${6}           ${7}              ${8}                ${9}
	main "${p_StudyFolder}" "${p_Subject}" "${p_fMRINames}" "${p_ConcatName}" "${p_HighPass}" "${p_RegName}" "${p_LowResMesh}" "${p_MatlabRunMode}" "${p_MotionRegression}"

else
	# Positional parameters are used
	log_Msg "Using positional parameters"
	main "$@"

fi







