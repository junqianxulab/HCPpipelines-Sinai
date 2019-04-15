#!/bin/bash 

#################
# Version date 29 March 2019 by Qi Liu
# Wrapper file to Run HCP Pipelines v3.27.0-Sinai to do MSMAll surface registration
# run after ReApplyFixMultiRun and before DeDriftAndResample
# source setup before running this script, setup files: SetUpMinervaModules.sh; SetUpHCPPipeline.sh
# suggest to runlocal to get logs into named log file; if queue with fsl_sub will have named log file and MSMAllPipeline.sh.o/e***


################


# software version check:
HCPver=$(cat $HCPPIPEDIR/version.txt)
echo "`date` - HCP Pipeline Version: $HCPver"
if [[ "$HCPver" != "v3.27.0-Sinai" ]] ; then
        echo "`date` - ERROR: HCP Pipeline version must = v3.27.0-Sinai"
        echo "HCP Pipeline directory: $(echo $HCPPIPEDIR)"      
        exit 42
fi
WBver=$(wb_command -help | grep Version)
echo "`date` - Connectome Workbench $WBver"
if [[ "$WBver" != "Version: 1.3.2" ]] ; then
        echo "`date` - ERROR: Connectome Workbench version must = 1.3.2"
        echo "Connectome Workbench directory: $(echo $CARET7DIR)"      
        exit 43
fi
FSLver=$(cat $FSLDIR/etc/fslversion)
echo "`date` - FSL Version: $FSLver"
if [ "$FSLver" != "5.0.11" ] ; then
        echo "`date` - ERROR: FSL version must = 5.0.11"
        exit 44
fi

if [ $# -eq 0 ] ; then
        echo -e "\nUSAGE: This script will run reapply the manual classified multirun-ICA fix noises.\n"
        echo -e "  Protips:" 
        echo -e "  Standard usage: vg_Anatomical_Preprocessing_postFS_MSMSulc_3.27.0-Sinai.sh --Subjlist=<Subject ID> \n"
        echo -e "  you can also run a list of subjects with space delimited \n"
fi



#################
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
            --runlocal)
                command_line_specified_run_local="TRUE"
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

StudyFolder="/sc/orga/projects/adolpvs/Subjects" #Location of Subject folders (named by subjectID)
Subjlist="P001 P001:"  #Space delimited list of subject IDs

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi


# Log the originating call
echo "$@"

#if [ X$SGE_ROOT != X ] ; then
#    QUEUE="-q long.q"
    QUEUE="-q long.q"
#fi

PRINTCOM=""
#PRINTCOM="echo"

########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

fMRINames="fMRI_merged"
OutfMRIName="MSMAll_fMRI"
HighPass="2000"
fMRIProcSTRING="_Atlas_hp2000_clean"
MSMAllTemplates="${HCPPIPEDIR}/global/templates/MSMAll"
RegName="MSMAll_InitialReg"
HighResMesh="164"
LowResMesh="32"
InRegName="MSMSulc"
MatlabMode="0" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab

fMRINames=`echo ${fMRINames} | sed 's/ /@/g'`

for Subject in $Subjlist ; do
	echo "    ${Subject}"
	
	if [ -n "${command_line_specified_run_local}" ] ; then
	    echo "About to run ${HCPPIPEDIR}/MSMAll/MSMAllPipeline.sh"
	    queuing_command=""
	else
	    echo "About to use fsl_sub to queue or run ${HCPPIPEDIR}/MSMAll/MSMAllPipeline.sh"
	    queuing_command="${FSLDIR}/bin/fsl_sub ${QUEUE}"
	fi

	${queuing_command} ${HCPPIPEDIR}/MSMAll/MSMAllPipeline.sh \
  --path=${StudyFolder} \
  --subject=${Subject} \
  --fmri-names-list=${fMRINames} \
  --output-fmri-name=${OutfMRIName} \
  --high-pass=${HighPass} \
  --fmri-proc-string=${fMRIProcSTRING} \
  --msm-all-templates=${MSMAllTemplates} \
  --output-registration-name=${RegName} \
  --high-res-mesh=${HighResMesh} \
  --low-res-mesh=${LowResMesh} \
  --input-registration-name=${InRegName} \
  --matlab-run-mode=${MatlabMode}
done


