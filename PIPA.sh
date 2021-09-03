#!/bin/bash 

usage="

------ PARCELLATED INTER-HEMISPHERIC PET ASYMMETRY (PIPA) V1.0 --------
        
authored by aaron warren 10/07/2020 
aaron.warren@unimelb.edu.au

this script performs freesurfer, PET-to-T1 registration, and calculates asymmetry indices from PET data using freesurfer parcellation (HCPMMP1 Glasser atlas)

USAGE: PIPA.sh -s <PATH TO SUBJECT FOLDER> -i <SUBJECT ID> -t <PATH TO T1 IMAGE> -p <PATH TO PET IMAGE> -f <OPTIONAL PATH TO 3D FLAIR IMAGE>

[-h] = show this usage/help text 

[-s] = full path to top-level subject folder where all output will be saved 

[-i] = subject ID (this is arbitrary - use whatever you like)

[-t] = path to T1 image (in .nii.gz format)

[-p = path to PET image (in .nii.gz format)

[-f] = optional path to 3D FLAIR image (in .nii.gz format - if set, a FLAIR image will be incorporated into Freesurfer recon-all, attempting to improve pial surface recon)

"

flair=false
options==':hs:i:t:p:f:'
while getopts $options option; do
    case "$option" in 
        h) echo "$usage"; exit;;
        s) subdir="$OPTARG";;
		i) id="$OPTARG";;
        t) t1="$OPTARG";;
        p) pet="$OPTARG";;
		f) flair="$OPTARG";;
		:) printf "missing argument for -%s\n" "$OPTARG" >&2; echo "$usage" >&2; exit 1;;
        \?) printf "illegal option: -%s\n" "$OPTARG" >&2; echo "$usage" >&2; exit 1;;
		
    esac	
done

# mandatory arguments
if [ ! "$subdir" ] || [ ! "$id" ] || [ ! "$t1" ] || [ ! "$pet" ]; then
  echo "arguments -s -i -t and -p must be provided"
  echo "$usage" >&2; exit 1
fi

    currdir=$(pwd);

    #freesurfer stuff
    export FREESURFER_HOME=/usr/local/freesurfer-7.1.1 #################################### CHANGE!
    source $FREESURFER_HOME/SetUpFreeSurfer.sh
    
    #path to required software/scripts
    software=/PATH/TO/PIPA_v1.0    #################################### CHANGE! 
    matlabdir=/PATH/TO/MATLAB/BIN/FOLDER #################################### CHANGE! for example: /home/MATLAB/bin
    
    #note on dependencies:
    #the HCPMMP1 .annot files are projected on fsaverage, and were obtained from here:
    #https://figshare.com/articles/dataset/HCP-MMP1_0_projected_on_fsaverage/3498446
    
    
    #create some sub-directories 
    anatdir=${subdir}/ANAT; if [ ! -d ${anatdir} ]; then mkdir ${anatdir}; fi 
    movdir=${subdir}/MOVING; if [ ! -d ${movdir} ]; then mkdir ${movdir}; fi
    outdir=${subdir}/OUTPUT; if [ ! -d ${outdir} ]; then mkdir ${outdir}; fi
    SUBJECTS_DIR=${outdir}/FREESURFER; if [ ! -d ${SUBJECTS_DIR} ]; then mkdir ${SUBJECTS_DIR}; fi
   
   
    ######STEP 1: T1 STUFF (CROP, REORIENT, FREESURFER, BIASCORRECT, CREATE HEAD/BRAIN MASKS)
    
   
    #preprocess the T1   
    if [ ! -f ${anatdir}/T1.nii.gz ]; then
    cmd="cp ${t1} ${anatdir}/T1.nii.gz"
    echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
    fi

    if [ ! -f ${anatdir}/T1_crop_ro.nii.gz ]; then 
    cmd="fslreorient2std ${anatdir}/T1.nii.gz ${anatdir}/T1_ro.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi    
    cmd="robustfov -i ${anatdir}/T1_ro.nii.gz -r ${anatdir}/T1_crop_ro.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
    fi
	
	if [ ! -f ${SUBJECTS_DIR}/${id}/mri/aparc+aseg.mgz ]; then #only run freesurfer if freesurfer output not already there ... 

        echo "Running Freesurfer on subject ${id}. This might take a while ...."
               		
		#run recon-all. if available, use a FLAIR image to improve pial reconstruction (requires minimum freesurfer 6.0), see: https://surfer.nmr.mgh.harvard.edu/fswiki/recon-all#UsingT2orFLAIRdatatoimprovepialsurfaces
		if [ -f ${flair} ]; then           
            echo "a FLAIR image is available for subject ${id}. Using FLAIR image in freesrufer recon-all ... "
	        cmd="recon-all -i ${anatdir}/T1_crop_ro.nii.gz -subjid $id -FLAIR ${flair} -FLAIRpial -all -openmp 8 -parallel"
		    echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
		 
		#if no flair is available, run recon-all without one    
		else
            echo "a FLAIR image is NOT available for subject ${id}. Running standard recon-all ... "
		    cmd="recon-all -i ${anatdir}/T1_crop_ro.nii.gz -subjid $id -all -openmp 8 -parallel"
		    echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi       
		    fi		
		echo "FINISHED running freesurfer recon-all for subject ${id} !!!"
		
	fi
	
	#convert the freesurfer output to nii.gz format using mrtrix
	if [ ! -f ${anatdir}/T1_headmask.nii.gz ]; then
    cmd="mrconvert ${SUBJECTS_DIR}/${id}/mri/orig/001.mgz ${anatdir}/origanat.nii.gz -stride +1,+2,+3 -force"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
		
    #create head mask (not brain mask) of anat file using bet	
    cmd="bet ${anatdir}/origanat.nii.gz ${anatdir}/bet -A"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
	
    #delete bet files we don't need
    rm -f ${anatdir}/bet*mesh* ${anatdir}/bet.nii.gz ${anatdir}/bet*skull*
     	
	#rename the head mask
    mv ${anatdir}/bet_outskin_mask.nii.gz ${anatdir}/T1_headmask.nii.gz
	fi
        
	#generate masked head
	if [ ! -f ${anatdir}/T1_head.nii.gz ]; then
    cmd="fslmaths ${anatdir}/origanat.nii.gz -mul ${anatdir}/T1_headmask.nii.gz ${anatdir}/T1_head.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
	fi
	
    #bias correct the head-masked T1 using ANTs
	if [ ! -f ${anatdir}/T1_head_biascorr.nii.gz ]; then
    cmd="N4BiasFieldCorrection -d 3 -i ${anatdir}/T1_head.nii.gz -x ${anatdir}/T1_headmask.nii.gz -o ${anatdir}/T1_head_biascorr.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
	fi
		
    #transform aparc+aseg back into original (scanned T1) space
	if [ ! -f ${anatdir}/T1_brainmask.nii.gz ]; then
    cmd="mri_label2vol --seg ${SUBJECTS_DIR}/${id}/mri/aparc+aseg.mgz --temp ${SUBJECTS_DIR}/${id}/mri/rawavg.mgz --o ${anatdir}/aparc+aseg2rawavg.mgz --regheader ${SUBJECTS_DIR}/${id}/mri/aparc+aseg.mgz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
		
    #convert to nii.gz
    cmd="mrconvert ${anatdir}/aparc+aseg2rawavg.mgz ${anatdir}/aparc+aseg.nii.gz -stride +1,+2,+3 -force"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
		
    #make aparc+aseg parcellation into a brainmask by thresholding, close with 3mm kernel x3, then invert
    cmd="fslmaths ${anatdir}/aparc+aseg.nii.gz -bin -kernel sphere 3 -dilM -ero -dilM -ero -dilM -ero -binv ${anatdir}/anat_mask_tmp1.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
		
    #close holes by finding largest connected component using FSL, then re-invert
    cmd="connectedcomp ${anatdir}/anat_mask_tmp1.nii.gz ${anatdir}/anat_mask_tmp2.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
		
    cmd="fslmaths ${anatdir}/anat_mask_tmp2.nii.gz -uthr 1 -binv ${anatdir}/T1_brainmask.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
		
    #remove files we don't need
    rm ${anatdir}/anat_mask_tmp?.nii.gz ${anatdir}/aparc+aseg2rawavg.mgz ${anatdir}/origanat.nii.gz 
	fi
	    
	#skull strip by masking with output of above
	if [ ! -f ${anatdir}/T1_brain_biascorr.nii.gz ]; then
    cmd="fslmaths ${anatdir}/T1_head_biascorr.nii.gz -mul ${anatdir}/T1_brainmask.nii.gz ${anatdir}/T1_brain_biascorr.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
	fi
	
	
	######STEP 2: PET STUFF (COREG TO T1)
	
	
	if [ ! -f ${movdir}/PET.nii.gz ]; then
    cmd="cp ${pet} ${movdir}/PET.nii.gz"
    echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
    fi
    
	if [ ! -f ${outdir}/PET2T1.nii.gz ]; then
    #calc transform
    cmd="ANTS 3 -m MI[${anatdir}/T1_brain_biascorr.nii.gz,${movdir}/PET.nii.gz,1,32] -o ${outdir}/PET2T1 --do-rigid true --rigid-affine true --MI-option 32x64000 -i 0"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
		
    #apply transform
    cmd="WarpImageMultiTransform 3 ${movdir}/PET.nii.gz ${outdir}/PET2T1.nii.gz -R ${anatdir}/T1_brain_biascorr.nii.gz ${outdir}/PET2T1Affine.txt"
    echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	fi		

	
	######STEP 3: PROJECT HCPMMP GLASSER ATLAS (+SUBCORTEX) TO FREESURFER SUBJECT SURFACE SPACE, THEN TO SUBJECT VOLUME SPACE
	
	
	if [ ! -f ${SUBJECTS_DIR}/${id}/label/lh.hcpmmp1.annot ]; then
	cmd="mri_surf2surf --srcsubject fsaverage --trgsubject ${id} --hemi lh --sval-annot ${software}/lh.HCPMMP1.annot --tval ${SUBJECTS_DIR}/${id}/label/lh.hcpmmp1.annot"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	fi	
	
	if [ ! -f ${SUBJECTS_DIR}/${id}/label/rh.hcpmmp1.annot ]; then
	cmd="mri_surf2surf --srcsubject fsaverage --trgsubject ${id} --hemi rh --sval-annot ${software}/rh.HCPMMP1.annot --tval ${SUBJECTS_DIR}/${id}/label/rh.hcpmmp1.annot"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	fi	
	
	if [ ! -f ${SUBJECTS_DIR}/${id}/mri/HCPMMP1.mgz ]; then
	cmd="mri_aparc2aseg --old-ribbon --s ${id} --annot hcpmmp1 --o ${SUBJECTS_DIR}/${id}/mri/HCPMMP1.mgz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	fi
	
	if [ ! -f ${outdir}/HCPMMP1.nii.gz ]; then
	cmd="mri_label2vol --seg ${SUBJECTS_DIR}/${id}/mri/HCPMMP1.mgz --temp ${SUBJECTS_DIR}/${id}/mri/rawavg.mgz --o ${outdir}/HCPMMP12rawavg.mgz --regheader ${SUBJECTS_DIR}/${id}/mri/HCPMMP1.mgz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi	
    #convert to nii.gz
    cmd="mrconvert ${outdir}/HCPMMP12rawavg.mgz ${outdir}/HCPMMP1.nii.gz -stride +1,+2,+3 -force"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi
    #clean up
    rm -f ${outdir}/HCPMMP12rawavg.mgz
	fi
	
	if [ ! -f ${outdir}/HCPMMP1_REORD.nii.gz ]; then
	cmd="labelconvert ${outdir}/HCPMMP1.nii.gz ${software}/hcpmmp1_original.txt ${software}/hcpmmp1_ordered.txt ${outdir}/HCPMMP1_REORD.nii.gz"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	fi
		
	
	######STEP 4: EXTRACT MEAN PET SIGNAL FROM EACH PARCEL WITHIN REORDERED ATLAS AND CALCULATE ASYMMETRY INDICES
		#(this step is not very elegant ... could definitelyyyyy be scripted more succinctly ... but hey it does the job). 
	
	
	#extract signal 
	if [ ! -f ${outdir}/HCPMMP1_REORD_MEANPET.txt ]; then
	cmd="fslmeants -i ${outdir}/PET2T1.nii.gz --label=${outdir}/HCPMMP1_REORD.nii.gz -o ${outdir}/HCPMMP1_REORD_MEANPET.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi	
	fi	
	
	#calculate asymmetry indices
	if [ ! -f ${outdir}/HCPMMP1_REORD_MEANPET_AI.txt ]; then
	cd ${outdir};
	cmd="xargs -n1 < HCPMMP1_REORD_MEANPET.txt | awk 'NR >= 1 && NR <= 180' > HCPMMP1_REORD_MEANPET_LHCORT.txt" 
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="xargs -n1 < HCPMMP1_REORD_MEANPET.txt | awk 'NR >= 181 && NR <= 360' > HCPMMP1_REORD_MEANPET_RHCORT.txt" 
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="xargs -n1 < HCPMMP1_REORD_MEANPET.txt | awk 'NR >= 361 && NR <= 368' > HCPMMP1_REORD_MEANPET_LHSUBCORT.txt" 
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="xargs -n1 < HCPMMP1_REORD_MEANPET.txt | awk 'NR >= 369 && NR <= 376' > HCPMMP1_REORD_MEANPET_RHSUBCORT.txt" 
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="paste HCPMMP1_REORD_MEANPET_LHCORT.txt HCPMMP1_REORD_MEANPET_RHCORT.txt | awk '{print \$1+\$2}' > HCPMMP1_REORD_MEANPET_LH+RHCORT.txt" #note '\' before awk's $1 and $2 to prevent conflict with $1 and $2 in bash script 
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="paste HCPMMP1_REORD_MEANPET_LHSUBCORT.txt HCPMMP1_REORD_MEANPET_RHSUBCORT.txt | awk '{print \$1+\$2}' > HCPMMP1_REORD_MEANPET_LH+RHSUBCORT.txt" 
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="paste HCPMMP1_REORD_MEANPET_LHCORT.txt HCPMMP1_REORD_MEANPET_RHCORT.txt | awk '{print \$1-\$2}' > HCPMMP1_REORD_MEANPET_LH-RHCORT.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
    cmd="paste HCPMMP1_REORD_MEANPET_LHSUBCORT.txt HCPMMP1_REORD_MEANPET_RHSUBCORT.txt | awk '{print \$1-\$2}' > HCPMMP1_REORD_MEANPET_LH-RHSUBCORT.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="paste HCPMMP1_REORD_MEANPET_LHCORT.txt HCPMMP1_REORD_MEANPET_RHCORT.txt | awk '{print \$2-\$1}' > HCPMMP1_REORD_MEANPET_RH-LHCORT.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="paste HCPMMP1_REORD_MEANPET_LHSUBCORT.txt HCPMMP1_REORD_MEANPET_RHSUBCORT.txt | awk '{print \$2-\$1}' > HCPMMP1_REORD_MEANPET_RH-LHSUBCORT.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="paste HCPMMP1_REORD_MEANPET_LH-RHCORT.txt HCPMMP1_REORD_MEANPET_LH+RHCORT.txt | awk '{print \$1/\$2}' > HCPMMP1_REORD_MEANPET_LH-RHCORT_AI.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="paste HCPMMP1_REORD_MEANPET_RH-LHCORT.txt HCPMMP1_REORD_MEANPET_LH+RHCORT.txt | awk '{print \$1/\$2}' > HCPMMP1_REORD_MEANPET_RH-LHCORT_AI.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
    cmd="paste HCPMMP1_REORD_MEANPET_LH-RHSUBCORT.txt HCPMMP1_REORD_MEANPET_LH+RHSUBCORT.txt | awk '{print \$1/\$2}' > HCPMMP1_REORD_MEANPET_LH-RHSUBCORT_AI.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
    cmd="paste HCPMMP1_REORD_MEANPET_RH-LHSUBCORT.txt HCPMMP1_REORD_MEANPET_LH+RHSUBCORT.txt | awk '{print \$1/\$2}' > HCPMMP1_REORD_MEANPET_RH-LHSUBCORT_AI.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	cmd="cat HCPMMP1_REORD_MEANPET_LH-RHCORT_AI.txt HCPMMP1_REORD_MEANPET_RH-LHCORT_AI.txt HCPMMP1_REORD_MEANPET_LH-RHSUBCORT_AI.txt HCPMMP1_REORD_MEANPET_RH-LHSUBCORT_AI.txt > HCPMMP1_REORD_MEANPET_AI.txt"
	echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi		
	
	#cleanup
	cmd="rm -f *CORT*txt"
    echo ${LINENO}": "$cmd; eval $cmd; if [ ! $? -eq 0 ]; then exit $?; fi	
    
    #return to current dir
    cd $currdir; 	
	fi
	
	#replace HCPMMP1 parcel values with asymmetry indicies, and threshold, using matlab 
	if [ ! -f ${outdir}/HCPMMP1_REORD_MEANPET_AI.nii.gz ]; then	
	
	cd $outdir;
	gunzip HCPMMP1_REORD.nii.gz; #temporarily unzip to keep matlab functions happy
	cp ${software}/populate.m .;
	#edit to add appropriate path to required dependencies (software dir set at start of this script)
    reps=(REPLACE:${software}); for row in "${reps[@]}"; do orig="$(echo $row | cut -d: -f1)"; new="$(echo $row | cut -d: -f2)"; sed -i -e "s@${orig}@${new}@g" populate.m; done
	#run in matlab 
	${matlabdir}/matlab -nodesktop -nosplash -r "run populate.m; exit"	
	#rezip to save space
	gzip *.nii 
	rm -f populate.m;	
	#invert the "bottom 5/10 percent" images so the colour range works correctly with MRView (?strangely, the most negative values display as transparent in MRview)
    for inv in HCPMMP1_REORD_PETAI_NEG5PCNT HCPMMP1_REORD_PETAI_NEG10PCNT; do fslmaths ${inv}.nii.gz -mul -1 ${inv}_INV.nii.gz; done   
    #create zero-threshold "positive" and "negative" asymmetry maps (note: the "negative" map is inverted so colour range works correctly with MRView)
    fslmaths HCPMMP1_REORD_PETAI.nii.gz -thr 0 HCPMMP1_REORD_PETAI_POS.nii.gz
    fslmaths HCPMMP1_REORD_PETAI.nii.gz -uthr 0 -mul -1 HCPMMP1_REORD_PETAI_NEG_INV.nii.gz
    
	cd $currdir
	fi
	
	if [ -f ${outdir}/HCPMMP1_REORD_PETAI_NEG_INV.nii.gz ]; then
	echo "
	
	
	------ FINISHED PARCELLATED INTER-HEMISPHERIC PET ASYMMETRY (PIPA) FOR SUBJECT ${id} --------
	
	------ RESULTS ARE SAVED HERE: ${outdir} --------
	
	------ ENJOY! --------
	                           
	                           
	"
	else
	
	echo "
	
	
	------ OOPS SOMETHING WENT WRONG !!!!! --------
	
	------ ANALYSIS DID NOT FINISH CORRECTLY FOR SUBJECT ${id} --------
	
	
	"
	fi
