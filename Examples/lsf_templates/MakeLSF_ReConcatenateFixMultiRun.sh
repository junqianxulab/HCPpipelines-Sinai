#!/bin/bash

home="/sc/orga/projects/adolpvs/PreProcPipeline/"
TMPPath="${home}/Scripts/HCPpipelines-3.27.0-Sinai/Examples/lsf_templates_submit/"
SinkPath="${home}/LSF_scripts/ReConcatenateFixMultiRun_3.27.0-Sinai/"
logPath="$home/logs/ReConcatenateFixMultiRun_3.27.0-Sinai/"

if [[ ! -d $SinkPath || ! -d $logPath ]]; then
        mkdir $SinkPath $logPath
fi


SubjectList=`cat ${home}/sublists/Sublist_ApplyManualClassification.txt`


for sub in $SubjectList; do
	echo $sub
	TMPFile="${TMPPath}/ReConcatenateFixMultiRun_TMP.lsf"
	GoalFile="${SinkPath}/ReConcatenateFixMultiRun_${sub}.lsf"

	sed "s/VAR_SUB/${sub}/g" ${TMPFile} > ${GoalFile}
	bsub < ${GoalFile}
done





