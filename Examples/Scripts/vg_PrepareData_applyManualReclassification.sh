#!/bin/bash


OrigFolder="/sc/orga/projects/adolpvs/TMP/FIX_manualClassification/HandNoises/" ## save manual reclassified ICA labels.
StudyFolder="/sc/orga/projects/adolpvs/Subjects/"
SubjectList=`cat /sc/orga/projects/adolpvs/PreProcPipeline/sublists/Sublist_ApplyManualClassification.txt`

ReconcatenateSurface=0 ## if the original ICA fix were not done with MSMSulc surface. and fMRI Surface MSMSulc were done before reapply manual reclassification.

for sub in $SubjectList; do
	echo $sub
	###copy reclassified ICA labels to subject folder###
        OrigFile=${OrigFolder}/${sub}_fix4melview_HCP_hp2000_thr10_reclassified.txt
        NewFile=${StudyFolder}/${sub}/MNINonLinear/Results/fMRI_merged/fMRI_merged_hp2000.ica/fix4melview_HCP_hp2000_thr10_reclassified.txt
	NoiseFile=${StudyFolder}/${sub}/MNINonLinear/Results/fMRI_merged/fMRI_merged_hp2000.ica/Noise.txt
        SignalFile=${StudyFolder}/${sub}/MNINonLinear/Results/fMRI_merged/fMRI_merged_hp2000.ica/Signal.txt
	
	if [[ -e "${OrigFile}"  &&  ! -e "${NewFile}" ]]; then
		cp ${OrigFile} ${NewFile}
		rm ${NoiseFile} ${SignalFile}
	fi

	### generate Noise.txt and Signal.txt in subject folder ###
	if [[ ! -e ${NoiseFile} || ! -e ${SignalFile} ]]; then
		rm ${NoiseFile} ${SignalFile}
		# noise ##
		Noises=""
		cat ${NewFile}|grep 'True'>tmp.txt
		while read -r line; do
			Noise_id=`echo $line|cut -d ',' -f1`
                	Noises="$Noises $Noise_id"
		done < tmp.txt
		echo ${Noises}>${NoiseFile}
		rm tmp.txt

		# signal ##
		Signals=""
		cat ${NewFile}|grep 'False'>tmp.txt
		while read -r line; do
			Signal_id=`echo $line|cut -d ',' -f1`
	                Signals="$Signals $Signal_id"
		done < tmp.txt
		echo ${Signals}>${SignalFile}
		rm tmp.txt
	fi

	### delete surface file for Reconcatenate MSMSulc Surface file
	if [ ${ReconcatenateSurface} = "1" ]; then
		ICASurfaceFiles=`ls ${StudyFolder}/${sub}/MNINonLinear/Results/fMRI_merged/*nii`
		fMRISurfaceFiles=`ls ${StudyFolder}/${sub}/MNINonLinear/Results/REST/REST_Atlas_*nii ${StudyFolder}/${sub}/MNINonLinear/Results/RFT_run*/RFT_run*_Atlas_*nii`
		rm ${ICASurfaceFiles} ${fMRISurfaceFiles}
	fi
done



