#!/bin/bash

home="/sc/orga/projects/adolpvs/PreProcPipeline/"
TMPPath="${home}/Scripts/HCPpipelines-3.27.0-Sinai/Examples/lsf_templates_submit/"
SinkPath="${home}/LSF_scripts/DeDriftAndResample_3.27.0-Sinai_step9/"
logPath="$home/logs/DeDriftAndResample_3.27.0-Sinai/"
if [[ ! -d $SinkPath || ! -d $logPath ]]; then
	mkdir $SinkPath $logPath
fi


SubjectList=`cat ${home}/sublists/Sublist_ApplyManualClassification.txt`

cd $logPath

for sub in $SubjectList; do
	echo $sub
	TMPFile="${TMPPath}/DeDriftAndResample_TMP.lsf"
	GoalFile="${SinkPath}/DeDriftAndResample_${sub}.lsf"

	sed "s/VAR_SUB/${sub}/g" ${TMPFile} > ${GoalFile}
	bsub < ${GoalFile}
done





