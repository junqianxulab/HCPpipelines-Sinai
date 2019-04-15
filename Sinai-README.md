
### Use these scripts for:
* PostFreeSurfer
* fMRISurface
* multirun ICAFIX
    * [debug] concatenate files only
    * [debug] skip to FIX
* change manual reclassified ICA components to HCP recognized format
* reapply ICA manual reclassification
* MSMAll
* DeDrift and resample



### Source two setup files
```
source Examples/Scripts/SetUpHCPPipeline.sh
source Examples/Scripts/SetUpMinervaModules.sh
```

### Run PostFreeSurfer using local wrapper script:
```
Examples/Scripts/vg_Anatomical_Preprocessing_postFS_MSMSulc_3.27.0-Sinai.sh
```

### Run fMRISurface (including MSMSulc) using local wrapper script:
```
Examples/Scripts/vg_BOLD_Preprocessing_fMRISurface_MSMSulc_3.27.0-Sinai.sh
```

### Log HCP Pipeline environmental variables
```
Examples/Scripts/env_report.sh
```

### Prepare data of manual reclassifed ICA components
```
Examples/Scripts/vg_PrepareData_applyManualReclassification.sh
```

### Run Reapply manual reclassification for multi-run ICA fix  
```
Examples/Scripts/vg_ReApplyFixMultiRunPipeline.sh
```

### Run MSMAll 
```
Examples/Scripts/vg_MSMAllPipelineBatch_fMRI_merged.sh
```

### Run DeDrift and Resample
```
Examples/Scripts/vg_DeDriftAndResamplePipelineBatch.sh
```

### LSF file templates for submitting jobs in minerva
```
Examples/lsf_templates
```

### debug files for multirun ICA fix 
```
ICAFIX/hcp_fix_multi_run_concatenate_files_only
ICAFIX/hcp_fix_multi_run_skip_to_FIX
```

