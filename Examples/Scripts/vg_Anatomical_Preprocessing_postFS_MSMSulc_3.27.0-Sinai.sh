#!/bin/bash

# Version date 18 March 2019 by Benjamin Ely
# Run HCP Pipelines v3.27.0-Sinai PostFreeSurfer anatomical preprocessing with MSMSulc alignment for Vilma's subjects
# Previous preprocessing steps (i.e. PreFreeSurfer, FreeSurfer) should use HCP Pipelines v3.22.0-beta.2-Sinai
# (versions chosen to maintain compatibility with already-processed data)

# software version check:
HCPver=$(cat $HCPPIPEDIR/version.txt)
echo "HCP Pipeline Version: $HCPver"
if [[ "$HCPver" != "v3.27.0-Sinai" ]] ; then
        echo "ERROR: HCP Pipeline version must = v3.27.0-Sinai"
        echo "HCP Pipeline directory: $(echo $HCPPIPEDIR)"      
        exit 37
fi
WBver=$(wb_command -help | grep Version)
echo "Connectome Workbench $WBver"
if [[ "$WBver" != "Version: 1.3.2" ]] ; then
        echo "ERROR: Connectome Workbench version must = 1.3.2"
        echo "Connectome Workbench directory: $(echo $CARET7DIR)"      
        exit 38
fi
FSLver=$(cat $FSLDIR/etc/fslversion)
echo "FSL Version: $FSLver"
if [ "$FSLver" != "5.0.11" ] ; then
        echo "ERROR: FSL version must = 5.0.11"
        exit 39
fi

if [ $# -eq 0 ] ; then 
	echo -e "\nUSAGE: This script will run the HCP PostFreeSurfer anatomical preprocessing pipeline.\n"
	echo -e "   Protips:" 
	echo -e "   1) Having both .nii and .nii.gz versions of input files present in same folder will crash this script. Move or rename .nii versions before running."
	echo -e "   2) Standard usage: vg_Anatomical_Preprocessing_postFS_MSMSulc_3.27.0-Sinai.sh --ID=<Subject ID> \n"
fi

# function for parsing options
getopt1() {
    sopt="$1"
    shift 1
    for fn in $@ ; do
	if [ `echo -e $fn | grep -- "^${sopt}=" | wc -w` -gt 0 ] ; then
	    echo -e $fn | sed "s/^${sopt}=//"
	    return 0
	fi
    done
}

# Prompt for inputs if not specified
if [ $# -eq 0 ] ; then 
	echo -e 'Enter subject number (e.g. P001)' ; read ID
else
	ID=`getopt1 "--ID" $@`
fi

#home="/sc/orga/projects/adolpvs/Subjects"
home="/sc/orga/projects/xuj09a/gabbay_storage/Subjects/test"
echo -e "\n\nWARNING: subject directory currently set to /sc/orga/projects/xuj09a/gabbay_storage/Subjects/test\n\n"
cd ${home}/${ID}

echo -e "\n\nRunning PostFreeSurfer pipeline.\n\n"
cd ${home}/${ID}
${HCPPIPEDIR}/PostFreeSurfer/PostFreeSurferPipeline.sh \
	--path=${home} \
	--subject=${ID} \
	--surfatlasdir=${HCPPIPEDIR_Templates}/standard_mesh_atlases \
	--grayordinatesdir=${HCPPIPEDIR_Templates}/91282_Greyordinates \
	--grayordinatesres=2 \
	--hiresmesh=164 \
	--lowresmesh=32 \
	--subcortgraylabels=${HCPPIPEDIR_Config}/FreeSurferSubcorticalLabelTableLut.txt \
	--freesurferlabels=${HCPPIPEDIR_Config}/FreeSurferAllLut.txt \
	--regname=MSMSulc \
	--refmyelinmaps=${HCPPIPEDIR_Templates}/standard_mesh_atlases/Conte69.MyelinMap_BC.164k_fs_LR.dscalar.nii

if [ "$?" = "0" ] ; then
	echo -e "\n\nAll done! Check the main output files in the subject directory, yo:"
	echo -e "     wb_view $home/$ID/MNINonLinear/fsaverage_LR32k/${ID}.*Distortion_*.32k_fs_LR.dscalar.nii $home/$ID/MNINonLinear/fsaverage_LR32k/${ID}.32k_fs_LR.wb.spec"
else
	echo -e "\n\nERROR: PostFreeSurfer pipeline did not complete normally; check files and re-run."
	exit 44
fi
