%populate.m

%authored by aaron warren 10/07/2020
%aaron.warren@unimelb.edu.au

%this matlab script will:

%1. load in parcel-wise asymmetry values and HCPMMP atlas
%2. threshold (5/10% most negative and most positive asymmetry values)
%3. populate atlas with asymmetry values, and save as .nii 

%note: script assumes it is already in directory containing results

clear all

%add dependencies
addpath REPLACE

%load in asymmetry values
aivals=load('HCPMMP1_REORD_MEANPET_AI.txt');

%threshold: most positive and most negative 5/10-ish %
[aivals_sort, aivals_sort_ind] = sort(aivals, 'descend');

%create vectors of 1s and 0s based on top/bottom 5/10-ish %, then use this to multiply by asymmetry values (i.e., to keep only top/bottom 5/10-ish %)
aivals_top5pcnt_ind=aivals_sort_ind(1:19);
aivals_top10pcnt_ind=aivals_sort_ind(1:38);
aivals_bot5pcnt_ind=aivals_sort_ind(358:376);
aivals_bot10pcnt_ind=aivals_sort_ind(339:376);
	
%temporary vectors of zeros 
keepind_aivals_top5pcnt=zeros(376,1);
keepind_aivals_top10pcnt=zeros(376,1);
keepind_aivals_bot5pcnt=zeros(376,1); 
keepind_aivals_bot10pcnt=zeros(376,1); 
	
%only parcels in top/bottom 5/10-ish% will have label of 1
keepind_aivals_top5pcnt(aivals_top5pcnt_ind)=1;
keepind_aivals_top10pcnt(aivals_top10pcnt_ind)=1;
keepind_aivals_bot5pcnt(aivals_bot5pcnt_ind)=1;
keepind_aivals_bot10pcnt(aivals_bot10pcnt_ind)=1;

%now multiply
aivals_top5pcnt=aivals.*keepind_aivals_top5pcnt;
aivals_top10pcnt=aivals.*keepind_aivals_top10pcnt;
aivals_bot5pcnt=aivals.*keepind_aivals_bot5pcnt;
aivals_bot10pcnt=aivals.*keepind_aivals_bot10pcnt;

%load in atlas
atlas=nii_tool('load', 'HCPMMP1_REORD.nii');

%create blank mask of size equal size to atlas (for filling with results)	
aivals_vol=zeros(size(atlas.img));
aivals_top5pcnt_vol=zeros(size(atlas.img));
aivals_top10pcnt_vol=zeros(size(atlas.img));
aivals_bot5pcnt_vol=zeros(size(atlas.img));
aivals_bot10pcnt_vol=zeros(size(atlas.img));
	
%populate
for iroi = 1:376;
    
    aivals_vol(find(atlas.img==iroi))=aivals(iroi);
	aivals_top5pcnt_vol(find(atlas.img==iroi))=aivals_top5pcnt(iroi);
	aivals_top10pcnt_vol(find(atlas.img==iroi))=aivals_top10pcnt(iroi);
	aivals_bot5pcnt_vol(find(atlas.img==iroi))=aivals_bot5pcnt(iroi);
	aivals_bot10pcnt_vol(find(atlas.img==iroi))=aivals_bot10pcnt(iroi);
    
end

%write out new atlas images populated with asymmetry indices (+thresholded)
mat2nii(aivals_vol, 'HCPMMP1_REORD_PETAI.nii', size(atlas.img), 32, 'HCPMMP1_REORD.nii'); %save map as nii file
mat2nii(aivals_top5pcnt_vol, 'HCPMMP1_REORD_PETAI_POS5PCNT.nii', size(atlas.img), 32, 'HCPMMP1_REORD.nii'); 
mat2nii(aivals_top10pcnt_vol, 'HCPMMP1_REORD_PETAI_POS10PCNT.nii', size(atlas.img), 32, 'HCPMMP1_REORD.nii'); 
mat2nii(aivals_bot5pcnt_vol, 'HCPMMP1_REORD_PETAI_NEG5PCNT.nii', size(atlas.img), 32, 'HCPMMP1_REORD.nii'); 
mat2nii(aivals_bot10pcnt_vol, 'HCPMMP1_REORD_PETAI_NEG10PCNT.nii', size(atlas.img), 32, 'HCPMMP1_REORD.nii');
