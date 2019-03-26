
### Use this for:
* PreFreeSurfer
* FreeSurfer
* fMRIVolume

### Source two setup files
```
source Examples/Scripts/SetUpHCPPipeline.sh
source Examples/Scripts/SetUpMinervaModules.sh
```

### Run PreeFreeSurfer and FreeSurfer pipelines using local wrapper script:
```
Examples/Scripts/vg_Anatomical_Preprocessing_preFS_FS_3.22.0-beta.2-Sinai.sh
```
Notes: 
 * Can skip PreFreeSurfer using flag "--preFS=skip"
 * Customized to combine T1w+T2w brainmasks during PreFreeSurfer for better brain coverage

### Run fMRIVolume pipeline using local wrapper script:
```
Examples/Scripts/vg_BOLD_Preprocessing_fMRIVolume_3.22.0-beta.2-Sinai.sh
```
Notes: 
 * Can tag large motion matrix files for deletion using flag "--TagMM=yes"
 * Can tarball working directories and flag originals for deletion using flag "--TarWD=yes"

### Log HCP Pipeline environmental variables
```
Examples/Scripts/env_report.sh
```
