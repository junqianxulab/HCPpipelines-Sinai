#!/bin/bash 

# Version date 27 March 2019 by Qi Liu
# Run HCP Pipelines v3.27.0-Sinai to reapply manual classified ICA components labels to clean fMRI data
# data were analysis using multirun ICAfix with HCPpipelines-3.27.0-Sinai/ICAFIX/hcp_fix_multi_run
# then manually reclassified, generated HandNoise.txt & HandSignal.txt with HCPpipelines-3.27.0-Sinai/ICAFIX/ApplyHandReClassifications.sh

# source setup before running this script, setup files: SetUpMinervaModules.sh; SetUpHCPPipeline.sh; fix1.067/settings_minerva.sh
# multirun function name defined in each subject cycle

# if you want to re-concatenant surface data for ICA folder (eg. Reg changed from FS to MSMSulc), before this script
#	delete all surface files in ICA fix folder (use PrepareData_applyManualReclassification.sh, set ReconcatenateSurface=1)
#	and  delete mean surface file in each functional data folder: {funcnamae}_Atlas_mean.dscalar.nii.


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
        echo -e "  Standard usage: vg_Anatomical_Preprocessing_postFS_MSMSulc_3.27.0-Sinai.sh --Subjlist=<Subject ID> [ --StudyFolder=<study folder> ] \n"
	echo -e "  you can also run a list of subjects with space delimited \n"
fi






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

StudyFolder="/sc/orga/projects/adolpvs/Subjects" #Location of Subject folders (named by subjectID)
Subjlist="P001 P001:" #Space delimited list of subject IDs

if [ -n "${command_line_specified_study_folder}" ]; then
    StudyFolder="${command_line_specified_study_folder}"
fi

if [ -n "${command_line_specified_subj}" ]; then
    Subjlist="${command_line_specified_subj}"
fi

echo "$@"


########################################## INPUTS ########################################## 

#Scripts called by this script do assume they run on the results of the HCP minimal preprocesing pipelines from Q2

######################################### DO WORK ##########################################

MRFixConcatName="fMRI_merged"
HighPass="2000"
MatlabMode="0" #Mode=0 compiled Matlab, Mode=1 interpreted Matlab, 2 = Use interpreted Octave
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


	${HCPPIPEDIR}/ICAFIX/ReApplyFixMultiRunPipeline.sh\
	--path=${StudyFolder} \
	--subject=${Subject} \
	--fmri-names=${MRFixNames} \
	--concat-fmri-name=${MRFixConcatName} \
	--high-pass=${HighPass} \
	--matlab-run-mode=${MatlabMode} \
	--motion-regression=${MotionRegression}

done


