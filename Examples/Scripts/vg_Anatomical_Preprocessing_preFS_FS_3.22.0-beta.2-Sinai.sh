#!/bin/bash

# Version date 18 March 2019 by Benjamin Ely
# Run HCP Pipelines v3.22.0-beta.2-Sinai PreFreeSurfer and FreeSurfer anatomical preprocessing scripts for Vilma's subjects
# Subsequent preprocessing steps (e.g. PostFreeSurfer) should use HCP Pipelines v3.27.0-Sinai
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
	echo -e "\nUSAGE: This script will run the HCP PreFreeSurfer and FreeSurfer anatomical preprocessing pipelines.\n"
	echo -e "   Protips:" 
	echo -e "   1) Having both .nii and .nii.gz versions of input files present in same folder will crash this script. Move or rename .nii versions before running."
	echo -e "   2) Standard usage: vg_Anatomical_Preprocessing_preFS_FS_3.22.0-beta.2-Sinai.sh --ID=<Subject ID> --T1=<T1w Folder No.> [ --T1b=<optional second T1w Folder No.> ] --T2=<T2w Folder No.> [ --LR=<LR Fieldmap Folder No.> --RL=<RL Fieldmap Folder No> ] or [ --AP=<AP Fieldmap Folder No.> --PA=<PA Fieldmap Folder No.> ]\n"
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
	echo -e 'Enter T1w folder number (e.g. 11)' ; read T1
	echo -e 'Enter second T1w folder number (optional)' ; read T1b
	echo -e 'Enter T2w folder number' ; read T2
	echo -e 'Enter LR Fieldmap folder number (blank if using AP/PA)' ; read LR
	echo -e 'Enter RL Fieldmap folder number (blank if using AP/PA)' ; read RL
	echo -e 'Enter AP Fieldmap folder number (blank if using LR/RL)' ; read AP
	echo -e 'Enter PA Fieldmap folder number (blank if using LR/RL)' ; read PA
else
	ID=`getopt1 "--ID" $@`
	T1=`getopt1 "--T1" $@`
	T1b=`getopt1 "--T1b" $@`
	T2=`getopt1 "--T2" $@`
	LR=`getopt1 "--LR" $@`
	RL=`getopt1 "--RL" $@`
	AP=`getopt1 "--AP" $@`
	PA=`getopt1 "--PA" $@`
	preFS=`getopt1 "--preFS" $@`
fi

home="/sc/orga/projects/adolpvs/Subjects"
#home="/sc/orga/projects/xuj09a/gabbay_storage/Subjects/test"
echo -e "`date` - home directory: $home"
cd ${home}/${ID}
if [ "$?" != "0" ] ; then
        echo -e "\n\n`date` - ERROR: subject directory not found at ${home}/${ID}"
        exit 45
fi

# Parse fieldmap inputs
if [ -n "$LR" ] && [ -z "$AP"] ; then
	encoding="-x"
	spacing=0.0006499955800300558
	negSEpath=$(dirname ${LR}_*/*.nii.gz)
	negSEfile=$(basename ${LR}_*/*.nii.gz)
	negFieldmap=${negSEpath}/${negSEfile}
	posSEpath=$(dirname ${RL}_*/*.nii.gz)
	posSEfile=$(basename ${RL}_*/*.nii.gz)
	posFieldmap=${posSEpath}/${posSEfile}
elif [ -n "$AP" ] && [ -z "$LR"] ; then
	encoding="-y"
	spacing=0.0006499829054495867 
	negSEpath=$(dirname ${AP}_*/*.nii.gz)
	negSEfile=$(basename ${AP}_*/*.nii.gz)
	negFieldmap=${negSEpath}/${negSEfile}
	posSEpath=$(dirname ${PA}_*/*.nii.gz)
	posSEfile=$(basename ${PA}_*/*.nii.gz)
	posFieldmap=${posSEpath}/${posSEfile}
else
	echo -e "\n\n`date` - ERROR: Fieldmaps must be a single paired LR/RL or AP/PA set. Check input options."
	exit 46
fi
# Parse other inputs
T1path=$(dirname ${T1}_*/oT*.nii.gz) #e.g. oT1wMPRBICv1.nii.gz. can also use coT*.nii.gz
T1file=$(basename ${T1}_*/oT*.nii.gz) # e.g. oT1wMPRBICv1.nii.gz, can also use coT*.nii.gz
T1run=${T1path}/${T1file}
if [ -n "$T1b" ] ; then
	T1bpath=$(dirname ${T1b}_*/oT*.nii.gz) #e.g. oT1wMPRBICv1.nii.gz. can also use coT*.nii.gz
	T1bfile=$(basename ${T1b}_*/oT*.nii.gz) # e.g. oT1wMPRBICv1.nii.gz, can also use coT*.nii.gz
	T1brun=${T1bpath}/${T1bfile}
	T1run="${T1run}@${T1brun}"
fi
T2path=$(dirname ${T2}_*/oT*.nii.gz) #e.g. oT2wSPCBICv1.nii.gz
T2file=$(basename ${T2}_*/oT*.nii.gz) #e.g. oT2wSPCBICv1.nii.gz
T2run=${T2path}/${T2file}

# option to skip PreFreeSurfer if re-running due to FreeSurfer crash
if [ "$preFS" = "skip" ] ; then 
	echo -e "\n\n`date` - Skipping PreFreeSurfer pipeline.\n\n"
else
	echo -e "\n\n`date` - Running PreFreeSurfer pipeline.\n\n"
	${HCPPIPEDIR}/PreFreeSurfer/PreFreeSurferPipeline.sh \
		--path=${home} \
		--subject=${ID} \
		--t1=${T1run} \
		--t2=${T2run} \
		--SEPhaseNeg=${negFieldmap} \
		--SEPhasePos=${posFieldmap} \
		--echospacing=${spacing} \
		--seunwarpdir=${encoding} \
		--t1samplespacing=0.0000085 \
		--t2samplespacing=0.0000026 \
		--unwarpdir=z \
		--gdcoeffs=${HCPPIPEDIR_Config}/Skyra_coeff.grad \
		--avgrdcmethod=TOPUP \
		--topupconfig=${HCPPIPEDIR_Config}/b02b0.cnf \
		--t1template=${HCPPIPEDIR_Templates}/MNI152_T1_0.9mm.nii.gz \
		--t1templatebrain=${HCPPIPEDIR_Templates}/MNI152_T1_0.9mm_brain.nii.gz \
		--t1template2mm=${HCPPIPEDIR_Templates}/MNI152_T1_2mm.nii.gz \
		--t2template=${HCPPIPEDIR_Templates}/MNI152_T2_0.9mm.nii.gz \
		--t2templatebrain=${HCPPIPEDIR_Templates}/MNI152_T2_0.9mm_brain.nii.gz \
		--t2template2mm=${HCPPIPEDIR_Templates}/MNI152_T2_2mm.nii.gz \
		--templatemask=${HCPPIPEDIR_Templates}/MNI152_T1_0.9mm_brain_mask.nii.gz \
		--template2mmmask=${HCPPIPEDIR_Templates}/MNI152_T1_2mm_brain_mask_dil.nii.gz \
		--brainsize=150 \
		--fnirtconfig=${HCPPIPEDIR_Config}/T1_2_MNI152_2mm.cnf \
		--fmapmag=NONE \
		--fmapphase=NONE \
		--fmapgeneralelectric=NONE \
		--echodiff=NONE #\
	#	--bfsigma="" \ # optional smoothing sigma for bias field, not sure why this is useful
	#	--UseJacobian=false \ # not currently in use by HCP pipelines
	#	--printcom=echo # in principle just prints commands rather than running, in practice doesn't seem to work
	if [ "$?" = "0" ] ; then
		echo -e "\n\n`date` - PreFreeSurfer pipeline complete. Phew!"
	else
		echo -e "\n\n`date` - ERROR: PreFreeSurfer pipeline did not complete normally; check files and re-run."
		exit 47
	fi
fi

echo -e "\n\n`date` - Running FreeSurfer pipeline.\n\n"
cd ${home}/${ID}
${HCPPIPEDIR}/FreeSurfer/FreeSurferPipeline.sh \
	--subject=${ID} \
	--subjectDIR=${home}/${ID}/T1w \
	--t1=${home}/${ID}/T1w/T1w_acpc_dc_restore.nii.gz \
	--t1brain=${home}/${ID}/T1w/T1w_acpc_dc_restore_brain.nii.gz \
	--t2=${home}/${ID}/T1w/T2w_acpc_dc_restore.nii.gz #\
#	--seed=true # optionally turn on random seed generation for recon-all, I believe this can help if FS segmentation is performing poorly
if [ "$?" = "0" ] ; then
	echo -e "\n\n`date` - FreeSurfer pipeline complete! Check results before running PostFreeSurfer pipeline."
	echo -e "     fslview $home/$ID/T1w/T1w_acpc_dc_restore_brain $home/$ID/MNINonLinear/T1w_restore_brain"
else
	echo -e "\n\n`date` - ERROR: FreeSurfer pipeline did not complete normally; check files and re-run."
	exit 48
fi
