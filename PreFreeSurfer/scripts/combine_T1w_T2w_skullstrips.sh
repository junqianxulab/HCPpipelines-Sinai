#!/bin/bash
# Created by B. Ely 26 Oct 2017 to combine initial HCP PreFS pipeline T1w and T2w brain masks.
# These combined masks generally give better brain extraction results than either mask alone in the 3T Skyra, 16-ch adolescent sample from acquired at ISMMS
# Usage: sh combine_T1w_T2w_skullstrips.sh "$StudyFolder/$Subject"

if [ -z $1 ] ; then
	echo "ERROR: subject must be specified"
	exit 42
else
	subdir=$1
fi

# rename original TXw brain and brain mask files
mv $subdir/T1w/T1w_acpc_brain.nii.gz $subdir/T1w/T1w_acpc_brain_orig.nii.gz
mv $subdir/T1w/T1w_acpc_brain_mask.nii.gz $subdir/T1w/T1w_acpc_brain_mask_orig.nii.gz
mv $subdir/T2w/T2w_acpc_brain.nii.gz $subdir/T2w/T2w_acpc_brain_orig.nii.gz
mv $subdir/T2w/T2w_acpc_brain_mask.nii.gz $subdir/T2w/T2w_acpc_brain_mask_orig.nii.gz

# combine original T1w and T2w brain masks
fslmaths $subdir/T1w/T1w_acpc_brain_mask_orig.nii.gz -add $subdir/T2w/T2w_acpc_brain_mask_orig.nii.gz -bin $subdir/T1w/T1w_acpc_brain_mask.nii.gz
if [ ! $? -eq 0 ] ; then exit 43 ; fi

# apply new combined brain mask to T1w and T2w data
fslmaths $subdir/T1w/T1w_acpc.nii.gz -mas $subdir/T1w/T1w_acpc_brain_mask.nii.gz $subdir/T1w/T1w_acpc_brain.nii.gz
if [ ! $? -eq 0 ] ; then exit 44 ; fi
cp $subdir/T1w/T1w_acpc_brain_mask.nii.gz $subdir/T2w/T2w_acpc_brain_mask.nii.gz
fslmaths $subdir/T2w/T2w_acpc.nii.gz -mas $subdir/T2w/T2w_acpc_brain_mask.nii.gz $subdir/T2w/T2w_acpc_brain.nii.gz
if [ ! $? -eq 0 ] ; then exit 45 ; fi
