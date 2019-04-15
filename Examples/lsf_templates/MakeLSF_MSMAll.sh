#!/bin/bash

##please submit lsf file in the log folder, as other log files would be generated in the same folder.


home="/sc/orga/projects/adolpvs/PreProcPipeline/"
TMPPath="${home}/Scripts/HCPpipelines-3.27.0-Sinai/Examples/lsf_templates_submit/"
SinkPath="${home}/LSF_scripts/MSMAll_3.27.0-Sinai_step8/"
logPath="$home/logs/MSMAll_3.27.0-Sinai/"
if [[ ! -d $SinkPath || ! -d $logPath ]]; then
	mkdir $SinkPath $logPath
fi


SubjectList=`cat ${home}/sublists/Sublist_ApplyManualClassification.txt`

cd $logPath

for sub in $SubjectList; do
	echo $sub
	TMPFile="${TMPPath}/MSMAll_TMP.lsf"
	GoalFile="${SinkPath}/MSMAll_${sub}.lsf"

	sed "s/VAR_SUB/${sub}/g" ${TMPFile} > ${GoalFile}
	bsub < ${GoalFile}
done





