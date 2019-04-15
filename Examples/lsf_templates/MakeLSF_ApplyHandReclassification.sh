#!/bin/bash

home="/sc/orga/projects/adolpvs/PreProcPipeline/"
TMPPath="${home}/Scripts/HCPpipelines-3.27.0-Sinai/Examples/lsf_templates_submit/"
SinkPath="${home}/LSF_scripts/ApplyHandReclassification_3.27.0-Sinai/"
logPath="$home/logs/ApplyHandReClassfications_3.27.0-Sinai/"
if [[ ! -d $SinkPath || ! -d $logPath ]]; then
        mkdir $SinkPath $logPath
fi


SubjectList=`cat ${home}/sublists/Sublist_ApplyManualClassification.txt|tail -n 15`


for sub in $SubjectList; do
	echo $sub
	TMPFile="${TMPPath}/ApplyHandReclassification_TMP.lsf"
	GoalFile="${SinkPath}/ApplyHandReclassification_${sub}.lsf"

	sed "s/VAR_SUB/${sub}/g" ${TMPFile} > ${GoalFile}
	bsub < ${GoalFile}
done





