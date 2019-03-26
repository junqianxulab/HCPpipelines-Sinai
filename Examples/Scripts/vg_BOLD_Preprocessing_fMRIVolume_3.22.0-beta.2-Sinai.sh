#!/bin/bash

# Version date 21 March 2019 by Benjamin Ely
# Run HCP Pipelines v3.22.0-beta.2-Sinai fMRIVolume functional preprocessing scripts for Vilma's subjects
# Subsequent preprocessing steps (e.g. fMRISurface) should use HCP Pipelines v3.27.0-Sinai
# (versions chosen to maintain compatibility with already-processed data)

# software version check:
HCPver=$(cat $HCPPIPEDIR/version.txt)
echo "`date` - HCP Pipeline version: $HCPver"
if [[ "$HCPver" != "v3.22.0-beta.2-Sinai" ]] ; then
        echo "`date` - ERROR: HCP Pipeline version must = v3.22.0-beta.2-Sinai"
        echo "HCP Pipeline directory: $(echo $HCPPIPEDIR)"      
        exit 42
fi
WBver=$(wb_command -help | grep Version)
echo "`date` - Connectome Workbench $WBver"
if [[ "$WBver" != "Version: 1.2.3" ]] ; then
        echo "`date` - ERROR: Connectome Workbench version must = 1.2.3"
        echo "Connectome Workbench directory: $(echo $CARET7DIR)"      
        exit 43
fi
FSLver=$(cat $FSLDIR/etc/fslversion)
echo "`date` - FSL version $FSLver"
if [ "$FSLver" != "5.0.6" ] ; then
        echo "`date` - ERROR: FSL version must = 5.0.6"
        exit 44
fi
if [ $# -eq 0 ] ; then
	echo -e "\nThis script will run the HCP fMRIVolume functional preprocessing pipeline.\n"
	echo -e "   Protips:"
	echo -e "   1) This script relies on outputs from the HCP anatomical preprocessing pipelines (especially PreFreeSurfer), so run those first."
	echo -e "   2) If processing several BOLD runs locally, better to do so in serial than in parallel (slows things down substantially)."
	echo -e "   3) Having both .nii and .nii.gz versions of input files present in same folder will crash this script. Move or rename .nii versions before running."
	echo -e "   4) Standard input usage is:    vg_BOLD_Preprocessing_fMRIVolume_3.22.0-beta.2-Sinai.sh --ID=[SubjectNumber] --BOLD=[BOLDFolderNumber] --SB=[SBRefFolderNumber] < --AP=[APFieldmapNumber] --PA=[PAFieldmapNumber] > < --LR=[LRFieldmapNumber] --RL=[RLFieldmapNumber] > --Direction=[PhaseEncodingDirection] --Name=[NameOfBOLDRun] < --TagMM=yes > < --TarWD=yes >\n"
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
	echo "Enter BOLD run folder number (e.g. 14)" ; read BOLD
	echo "Enter SBRef folder number corresponding to BOLD run (e.g. 13)" ; read SB
	echo "Enter AP Fieldmap folder number closest to BOLD run (e.g. 11). Leave blank if using LR/RL." ; read AP
	echo "Enter PA Fieldmap folder number closest to BOLD run (e.g. 12). Leave blank if using LR/RL."; read PA
	echo "Enter LR Fieldmap folder number closest to BOLD run (e.g. 11). Leave blank if using AP/PA" ; read LR
	echo "Enter RL Fieldmap folder number closest to BOLD run (e.g. 12). Leave blank if using AP/PA" ; read RL
	echo "Enter BOLD run phase encoding direction (AP, PA, LR, or RL)" ; read Direction
	echo "Enter base name for output files without spaces (e.g. REST)" ; read Name
	echo "Tag large intermediate motion matrix files for deletion once finished? (yes/no, default=no)" ; read TagMM
	echo "Compress working directory once finished? (yes/no, default=no)" ; read TarWD
else
	ID=`getopt1 "--ID" $@`
	BOLD=`getopt1 "--BOLD" $@`
	SB=`getopt1 "--SB" $@`
	AP=`getopt1 "--AP" $@`
	PA=`getopt1 "--PA" $@`
        LR=`getopt1 "--LR" $@`
        RL=`getopt1 "--RL" $@`
	Direction=`getopt1 "--Direction" $@`
	Name=`getopt1 "--Name" $@`
	TagMM=`getopt1 "--TagMM" $@`
	TarWD=`getopt1 "--TarWD" $@`
fi	

home="/sc/orga/projects/adolpvs/Subjects"
#home="/sc/orga/projects/xuj09a/gabbay_storage/Subjects/test"
echo -e "`date` - home directory: $home"
cd ${home}/${ID}
if [ "$?" != "0" ] ; then
        echo -e "\n\n`date` - ERROR: subject directory not found at ${home}/${ID}"
        exit 45
fi

# parse encoding direction and assign corresponding echo spacing etc
if [ "$Direction" = "AP" ] ; then
	encoding="-y"
	EchoSpacing="0.0006499829054495867"
	Neg=$AP
	Pos=$PA
elif [ "$Direction" = "PA" ] ; then
        encoding="y"
	EchoSpacing="0.0006499829054495867"
	Neg=$AP
	Pos=$PA
elif [ "$Direction" = "LR" ] ; then
        encoding="-x"
	EchoSpacing="0.000649995580030055"
	Neg=$LR
	Pos=$RL
elif [ "$Direction" = "RL" ] ; then
        encoding="x"
	EchoSpacing="0.000649995580030055"
	Neg=$LR
	Pos=$RL
else
        echo -e "\n\n`date` - ERROR: Wrong format for phase encoding direction. Options are AP, PA, LR, or RL for this script. Try again!"
        exit 46
fi

# parse filenames and set paths
BOLDpath=$(dirname ${BOLD}_*/*.nii.gz)
BOLDfile=$(basename ${BOLD}_*/*.nii.gz)
BOLDrun=${BOLDpath}/${BOLDfile}
SBpath=$(dirname ${SB}_*/*.nii.gz)
SBfile=$(basename ${SB}_*/*.nii.gz)
SBRef=${SBpath}/${SBfile}
Negpath=$(dirname ${Neg}_*/*.nii.gz)
Negfile=$(basename ${Neg}_*/*.nii.gz)
FieldmapNeg=${Negpath}/${Negfile}
Pospath=$(dirname ${Pos}_*/*.nii.gz)
Posfile=$(basename ${Pos}_*/*.nii.gz)
FieldmapPos=${Pospath}/${Posfile}

echo -e "\n\n`date` - Running fMRI Volume Pipeline Scripts\n\n"
${HCPPIPEDIR}/fMRIVolume/GenericfMRIVolumeProcessingPipeline.sh \
	--path=${home} \
	--subject=${ID} \
	--fmriname=${Name} \
	--fmritcs=${BOLDrun} \
	--fmriscout=${SBRef} \
	--SEPhaseNeg=${FieldmapNeg} \
	--SEPhasePos=${FieldmapPos} \
        --echospacing="${EchoSpacing}" \
        --fmapmag="NONE" \
        --fmapphase="NONE" \
	--echodiff="NONE" \
        --unwarpdir=$encoding \
        --fmrires=2.3 \
        --dcmethod="TOPUP" \
	--gdcoeffs=${HCPPIPEDIR_Config}/Skyra_coeff.grad \
        --biascorrection="SEBASED" \
	--topupconfig=${HCPPIPEDIR_Config}/b02b0.cnf \
	--printcom="" \
	--mctype="MCFLIRT" #\
#        --usejacobian="false"

if [ "$?" = "0" ] ; then
	echo -e "\n\n`date` - fMRIVolume pipeline complete! Check results before running fMRISurface pipeline."
	echo -e "     fslview ${home}/${ID}/MNINonLinear/Results/${Name}/${Name}.nii.gz"
else
	echo -e "\n\n`date` - ERROR: fMRI Volume Pipeline for subject $ID did not complete normally; check files and re-run."
	exit 47
fi

# options to minimize disk space
if [ "$TagMM" = "yes" ] ; then
	echo -e "\n\n`date` - Tagging intermediate files that can be deleted\n\n"
	mkdir -p ${home}/${ID}/MotionMatrices_${Name}_ToBeDeleted
	if [ "$?" != "0" ] ; then exit 48 ; fi
	mv ${home}/${ID}/${Name}/MotionMatrices/*.nii.gz ${home}/${ID}/MotionMatrices_${Name}_ToBeDeleted
	if [ "$?" != "0" ] ; then exit 49 ; fi
fi
if [ "$TarWD" = "yes" ] ; then
	echo -e "\n\n`date` - Compressing ${Name} working directory\n\n"
	tar -cvzf ${home}/${ID}/${Name}.tgz ${home}/${ID}/${Name}
	if [ "$?" != "0" ] ; then exit 50 ; fi
	mv ${home}/${ID}/${Name} ${home}/${ID}/${Name}_ToBeDeleted 
	if [ "$?" != "0" ] ; then exit 51 ; fi
fi
