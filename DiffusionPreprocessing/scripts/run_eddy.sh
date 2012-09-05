#!/bin/bash

workingdir=$1
topupdir=`dirname ${workingdir}`/topup

${FSLDIR}/bin/imcp ${topupdir}/nodif_brain_mask ${workingdir}/

${FSLDIR}/bin/eddy --imain=${workingdir}/Pos_Neg --mask=${workingdir}/nodif_brain_mask --index=${workingdir}/index.txt --acqp=${workingdir}/acqparams.txt --bvecs=${workingdir}/Pos_Neg.bvecs --bvals=${workingdir}/Pos_Neg.bvals --fwhm=5 --topup=${topupdir}/topup_Pos_Neg_b0 --out=${workingdir}/eddy_parameters.txt --iout=${workingdir}/eddy_unwarped_images --flm=quadratic -v