#!/bin/bash

# Version date 21 March 2019 by Benjamin Ely
# Run HCP Pipelines v3.27.0-Sinai fMRISurface functional preprocessing scripts with MSMSulc surface registration for Vilma's subjects
# Previous preprocessing steps (e.g. fMRIVolume) should use HCP Pipelines v3.22.0-beta.2-Sinai
# (versions chosen to maintain compatibility with already-processed data)

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
	echo -e "\nThis script will run the HCP fMRISurface functional preprocessing pipeline.\n"
	echo -e "   Protips:"
	echo -e "   1) This script relies on outputs from the HCP anatomical and fMRIVolume functional preprocessing pipelines, so run those first."
	echo -e "   2) If processing several BOLD runs locally, better to do so in serial than in parallel (slows things down substantially)."
	echo -e "   3) Having both .nii and .nii.gz versions of input files present in same folder will crash this script. Move or rename .nii versions before running."
	echo -e "   4) Standard input usage is:    vg_BOLD_Preprocessing_fMRISurface_MSMSulc_3.27.0-Sinai.sh --ID=[SubjectNumber] --Name=[NameOfBOLDRun]\n"
fi

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

# Prompt for inputs if not specified
if [ $# -eq 0 ] ; then 
	echo "Enter subject number (e.g. P005)" ; read ID
	echo "Enter base name for output files without spaces (e.g. REST)" ; read Name
else
	ID=`getopt1 "--ID" $@`
	Name=`getopt1 "--Name" $@`
fi	

home="/sc/orga/projects/adolpvs/Subjects"
#home="/sc/orga/projects/xuj09a/gabbay_storage/Subjects/test"
echo -e "`date` - home directory: $home"
cd ${home}/${ID}
if [ "$?" != "0" ] ; then
        echo -e "\n\n`date` - ERROR: subject directory not found at ${home}/${ID}"
        exit 45
fi

echo -e "\n\n`date` - Running fMRISurface pipeline scripts.\n\n"
${HCPPIPEDIR}/fMRISurface/GenericfMRISurfaceProcessingPipeline.sh \
	--path=${home} \
	--subject=${ID} \
	--fmriname=${Name} \
        --lowresmesh="32" \
        --fmrires="2.3" \
        --smoothingFWHM="2" \
        --grayordinatesres="2" \
	--regname="MSMSulc"
if [ "$?" = "0" ] ; then
	echo -e "\n\n`date` - fMRISurface pipeline complete! Check results in ${ID}/MNINonLinear/Results/${Name}, then run ICA-FIX.\n\n"
else
	echo -e "\n\n`date` - ERROR: fMRISurface pipeline for subject $ID run $Name did not complete normally; check files and re-run."
	exit 46
fi

