# PIPA V1.0
Parcellated Inter-hemispheric PET Asymmetry (PIPA)

# REQUIRED SOFTWARE
- Freesurfer (ideally version >6): https://freesurfer.net/fswiki/DownloadAndInstall
- FSL: https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/FslInstallation
- ANTs: https://github.com/stnava/ANTs
- MRtrix3: https://mrtrix.readthedocs.io/en/latest/installation/package_install.html
- MATLAB: https://www.mathworks.com/products/get-matlab.html

# USAGE

This Bash script performs Freesurfer recon-all, PET-to-T1 co-registration, and calculates asymmetry indices from PET data using HCPMMP1 cortical parcellation (+ Freesurfer subcortical parcellation). 

USAGE: PIPA.sh -s <PATH TO SUBJECT FOLDER> -i <SUBJECT ID> -t <PATH TO T1 IMAGE> -p <PATH TO PET IMAGE> -f <OPTIONAL PATH TO 3D FLAIR IMAGE>

[-h] = show this usage/help text 

[-s] = full path to top-level subject folder where all output will be saved 

[-i] = subject ID (arbitrary)

[-t] = path to T1 image (in .nii.gz format)

[-p = path to PET image (in .nii.gz format)
  
[-f] = optional path to FLAIR image (in .nii.gz format - if set, FLAIR will be incorporated into Freesurfer recon-all, attempting to improve pial surface recon)
