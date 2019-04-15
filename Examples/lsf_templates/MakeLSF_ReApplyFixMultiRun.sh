#!/bin/bash

home="/sc/orga/projects/adolpvs/PreProcPipeline/"
TMPPath="${home}/Scripts/HCPpipelines-3.27.0-Sinai/Examples/lsf_templates_submit/"
SinkPath="${home}/LSF_scripts/ReApplyFixMultiRun_3.27.0-Sinai_step7/"
logPath="$home/logs/ReApplyFixMultiRun_3.27.0-Sinai/"

if [[ ! -d $SinkPath || ! -d $logPath ]]; then
        mkdir $SinkPath $logPath
fi

cd $logPath
SubjectList=`cat ${home}/sublists/Sublist_ApplyManualClassification.txt`


for sub in $SubjectList; do
	echo $sub
	TMPFile="${TMPPath}/ReApplyFixMultiRun_TMP.lsf"
	GoalFile="${SinkPath}/ReApplyFixMultiRun_${sub}.lsf"

	sed "s/VAR_SUB/${sub}/g" ${TMPFile} > ${GoalFile}
	bsub < ${GoalFile}
done





