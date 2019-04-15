#!/bin/bash 

##########################
# Version date 29 March 2019 by Qi Liu
# Wrapper file to run HCP Pipelines v3.27.0-Sinai to do DeDriftAndResample after MSMAll

# source setup before running this script, setup files: SetUpMinervaModules.sh; SetUpHCPPipeline.sh
##########################

get_batch_options() {
    local arguments=("$@")

    unset command_line_specified_study_folder
    unset command_line_specified_subj
    unset command_line_specified_run_local

    local index=0
    local numArgs=${#arguments[@]}
    local argument

    while [ ${index} -lt ${numArgs} ]; do
        argument=${arguments[index]}

        case ${argument} in
            --StudyFolder=*)
                command_line_specified_study_folder=${argument#*=}
                index=$(( index + 1 ))
                ;;
            --Subjlist=*)
                command_line_specified_subj=${argument#*=}
                index=$(( index + 1 ))
                ;;
	    *)
		echo ""
		echo "ERROR: Unrecognized Option: ${argument}"
		echo ""
		exit 1
		;;
        esac
    done
}

get_batch_options "$@"

StudyFolder="/sc/orga/projects/adolpvs/Subjects/" #Location of Subject folders (named by subjectID)
Subjlist="P001 P001:" #Space delimited list of subject IDs
#EnvironmentScript="SetUpHCPPipeline_for_fix.sh" #sourced outside the script

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
    QUEUE="-q long.q"
#fi

PRINTCOM=""

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

HighResMesh="164"
LowResMesh="32"
RegName="MSMAll_InitialReg_2_d40_WRN"
DeDriftRegFiles="${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.L.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii@${HCPPIPEDIR}/global/templates/MSMAll/DeDriftingGroup.R.sphere.DeDriftMSMAll.164k_fs_LR.surf.gii"
ConcatRegName="MSMAll_Dedrift"
Maps="sulc curvature corrThickness thickness"
MyelinMaps="MyelinMap SmoothedMyelinMap" #No _BC, this will be reapplied

MRFixConcatName="fMRI_merged"
#MRFixNames="NONE" ############## defined in each subject####################
fixNames="NONE" #Space delimited list or NONE
fixNames="NONE"  #Space delimited list or NONE
dontFixNames="NONE" #Space delimited list or NONE

SmoothingFWHM="2" #Should equal previous grayordiantes smoothing (because we are resampling from unsmoothed native mesh timeseries
HighPass="2000"
MatlabMode="0" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab

Maps=`echo "$Maps" | sed s/" "/"@"/g`
MyelinMaps=`echo "$MyelinMaps" | sed s/" "/"@"/g`
#MRFixNames=`echo "$MRFixNames" | sed s/" "/"@"/g`    ############## defined in each subject loop ####################
fixNames=`echo "$fixNames" | sed s/" "/"@"/g`
dontFixNames=`echo "$dontFixNames" | sed s/" "/"@"/g`

MotionRegression="FALSE"

for Subject in $Subjlist ; do
	echo "    ${Subject}"
	

	##get rfMRI list for multi-run ICAFIX
	rfMRINames=""
	while read -d / fMRI_lst;
	do
	   lst_name=`echo $fMRI_lst|cut -d @ -f 2`;
	   rfMRINames="${rfMRINames}@${lst_name}"
        done <${StudyFolder}/${Subject}/MNINonLinear/Results/lst_icafix_multirun
	MRFixNames=${rfMRINames#@}        

        ${queuing_command} ${HCPPIPEDIR}/DeDriftAndResample/DeDriftAndResamplePipeline.sh \
        --path=${StudyFolder} \
        --subject=${Subject} \
        --high-res-mesh=${HighResMesh} \
        --low-res-meshes=${LowResMesh} \
        --registration-name=${RegName} \
        --dedrift-reg-files=${DeDriftRegFiles} \
        --concat-reg-name=${ConcatRegName} \
        --maps=${Maps} \
        --myelin-maps=${MyelinMaps} \
        --multirun-fix-concat-name=${MRFixConcatName} \
        --multirun-fix-names=${MRFixNames} \
        --fix-names=${fixNames} \
        --dont-fix-names=${dontFixNames} \
        --smoothing-fwhm=${SmoothingFWHM} \
        --highpass=${HighPass} \
        --matlab-run-mode=${MatlabMode} \
        --motion-regression=${MotionRegression}
done


