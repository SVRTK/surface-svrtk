#!/bin/bash

# ============================================================================
# SVRTK : SVR reconstruction based on MIRTK
#
# Copyright 2018-... King's College London
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================


echo
echo ".........................................................................."
echo ".........................................................................."
echo




if [ "$#" -ne 7 ]; then
    echo ""
    echo "Draw-EM based fetal brain surface generation from BOUNTI-V1.0 19 tissue labels"
    echo
    echo "Source code: https://github.com/SVRTK/surface-svrtk"
    echo "Docker: https://hub.docker.com/r/fetalsvrtk/surface"
    echo
    echo "Usage : bash /software/surface-scripts/bounti-surface-generation-v3-tissue-internal-update.sh "
    echo "[subject ID - e.g., sub-1234_ses-000]"
    echo "[full path to T2 file - e.g., /home/data/in-files/sub-1234_ses-000-T2.nii.gz]"
    echo "[full path to BOUNTI labels file - e.g., /home/data/in-files/sub-1234_ses-000-mask-brain_dhcp-19.nii.gz]"
    echo "[full path to BET labels file - e.g., /home/data/in-files/sub-1234_ses-000-mask-brain_bet-1.nii.gz]"
    echo "[full path to CC labels file - e.g., /home/data/in-files/sub-1234_ses-000-mask-brain_cc-2.nii.gz]"
    echo "[full path to the folder for processing outputs - e.g., /home/data/proc/sub-1234_ses]"
    echo "[flag to cleaning the output processing folder - e.g., 0 - no cleaning, 1 - remove all old files]"
    echo ""
    
    echo
    echo ".........................................................................."
    echo ".........................................................................."
    echo

    
    exit
fi



subj=$1
T2_in=$2
bounti_label_in=$3
bet_label_in=$4
cc_label_in=$5
workdir=$6
clean_flag=$7



echo ""
echo "Inputs: "
echo " - subject ID : " ${subj}
echo " - input T2 file : " ${T2_in}
echo " - BOUNTI labels file : " ${bounti_label_in}
echo " - BET labels file : " ${bet_label_in}
echo " - CC labels file : " ${cc_label_in}
echo " - folder for processing outputs : " ${workdir}
echo " - flag for cleaning the output folder : " ${clean_flag}
echo ""


echo
echo ".........................................................................."
echo ".........................................................................."
echo


echo " - Copying files and creating folders ..."


t2dir=T2
surfacedir=surfaces
segdir=segmentations
outwb=${surfacedir}/${subj}/workbench
outvtk=${surfacedir}/${subj}/vtk
outtmp=${surfacedir}/${subj}/temp

mirtk_dir=/software/MIRTK/build/lib/tools
wb_dir=/software/workbench/bin_linux64
meshtosphere_dir=/software/SphericalMesh/build/bin



parameters_dir=/software/surface-scripts


bounti_labels_roi=mask-brain_dhcp-19
cc_labels_roi=mask-brain_cc-2
bet_labels_roi=mask-brain_bet-1
bounti_cc_labels_roi=mask-brain_dhcp-cc-20
internal_labels_roi=mask-brain_internal-1


if [ ${clean_flag} -eq 1 ]; then
    rm -r ${workdir}
fi


if [ ! -d ${workdir} ];then
    mkdir -p ${workdir}
fi



if [ ! -d ${workdir}/${t2dir} ];then
    mkdir -p ${workdir}/${t2dir}
fi 

if [ ! -d ${workdir}/${segdir} ];then
    mkdir -p ${workdir}/${segdir}
fi 


if [ ! -f ${workdir}/${t2dir}/${subj}.nii.gz ];then
    cp ${T2_in} ${workdir}/${t2dir}/${subj}.nii.gz
fi

test_file=${workdir}/${t2dir}/${subj}.nii.gz
if [ ! -f ${test_file} ];then
    echo "ERROR : no input file " ${T2_in} " / " ${test_file}
fi


if [ ! -f ${workdir}/${segdir}/${subj}-${bounti_labels_roi}.nii.gz ];then
    cp ${bounti_label_in} ${workdir}/${segdir}/${subj}-${bounti_labels_roi}.nii.gz
fi

test_file=${workdir}/${segdir}/${subj}-${bounti_labels_roi}.nii.gz
if [ ! -f ${test_file} ];then
    echo "ERROR : no input file " ${bounti_label_in} " / " ${test_file}
fi


if [ ! -f ${workdir}/${segdir}/${subj}-${bet_labels_roi}.nii.gz ];then
    cp ${bet_label_in} ${workdir}/${segdir}/${subj}-${bet_labels_roi}.nii.gz
fi


test_file=${workdir}/${segdir}/${subj}-${bet_labels_roi}.nii.gz
if [ ! -f ${test_file} ];then
    echo "ERROR : no input file " ${bet_label_in} " / " ${test_file}
fi


if [ ! -f ${workdir}/${segdir}/${subj}-${cc_labels_roi}.nii.gz ];then
    cp ${cc_label_in} ${workdir}/${segdir}/${subj}-${cc_labels_roi}.nii.gz
fi


test_file=${workdir}/${segdir}/${subj}-${cc_labels_roi}.nii.gz
if [ ! -f ${test_file} ];then
    echo "ERROR : no input file " ${cc_label_in} " / " ${test_file}
fi


if [ ! -f ${workdir}/${segdir}/${subj}-${internal_labels_roi}.nii.gz ];then
    echo
    echo "Generating internal label ... " ${workdir}/${segdir}/${subj}-${internal_labels_roi}.nii.gz
    echo
    
    bash /software/surface-scripts/slava_create_internal.sh ${workdir}/${segdir}/${subj}-${bounti_labels_roi}.nii.gz ${workdir}/${segdir}/${subj}-${internal_labels_roi}.nii.gz > /home/tmp.txt
    
fi



cd ${workdir}

if [ ! -d ${outvtk} ];then
    mkdir -p ${outvtk} ${outwb} ${outtmp} logs
fi 



Hemi=('L' 'R');
Cortex=('CORTEX_LEFT' 'CORTEX_RIGHT');
Surf=('white' 'pial' 'midthickness' 'inflated' 'very_inflated' 'sphere');


surfvars(){
    surf=${Surf[$si]}
    T=${Type[$si]}
    T2=${Type2[$si]}
}

vtktogii(){
    vtk=$1
    gii=$2
    giiT=$3
    giiT2=$4
    giibase=`basename ${gii}`; giidir=`echo ${gii}|sed -e "s:${giibase}::g"`; tempgii=${giidir}/temp-${giibase}
    ${mirtk_dir}/convert-pointset ${vtk} ${tempgii}
    ${wb_dir}/wb_command -set-structure ${tempgii} ${C} -surface-type ${giiT} -surface-secondary-type ${giiT2}
    mv ${tempgii} ${gii}
}

giimap(){
    vtk=$1
    gii=$2
    scalars=$3
    mapname=$4
    giibase=`basename ${gii}`; giidir=`echo ${gii}|sed -e "s:${giibase}::g"`; tempgii=${giidir}/temp-${giibase}; tempvtk=${tempgii}.vtk
    ${mirtk_dir}/delete-pointset-attributes ${vtk} ${tempvtk} -all
    ${mirtk_dir}/copy-pointset-attributes ${vtk} ${tempvtk} ${tempgii} -pointdata $scalars curv
    rm ${tempvtk}
    ${wb_dir}/wb_command -set-structure  ${tempgii} ${C}
    ${wb_dir}/wb_command -metric-math "var * -1" ${tempgii} -var var ${tempgii}
    ${wb_dir}/wb_command -set-map-name  ${tempgii} 1 ${subj}_${h}_${mapname}
    ${wb_dir}/wb_command -metric-palette ${tempgii} MODE_AUTO_SCALE_PERCENTAGE -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true
    if [ "$mapname" == "Thickness" ];then
      ${wb_dir}/wb_command -metric-math "abs(thickness)" ${tempgii} -var thickness ${tempgii}
      ${wb_dir}/wb_command -metric-palette ${tempgii} MODE_AUTO_SCALE_PERCENTAGE -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
    fi
    mv ${tempgii} ${gii}
}

cleanup(){
    rm -f ${outvtk}/${hs}.*
}



echo
echo ".........................................................................."
echo ".........................................................................."
echo

echo " - Processing segmentations (adding CC & internal labels to BOUNTI-V1.0) ..."
if [ ! -f ${segdir}/${subj}-${bounti_cc_labels_roi}.nii.gz ];then
 
    ${mirtk_dir}/dilate-image ${segdir}/${subj}-${internal_labels_roi}.nii.gz ${segdir}/${subj}-${internal_labels_roi}.nii.gz
    # ${mirtk_dir}/fill-holes ${segdir}/${subj}-${internal_labels_roi}.nii.gz ${segdir}/${subj}-${internal_labels_roi}.nii.gz
    ${mirtk_dir}/replace-label-dhcp ${segdir}/${subj}-${internal_labels_roi}.nii.gz ${segdir}/${subj}-${bounti_labels_roi}.nii.gz ${segdir}/${subj}-${bounti_labels_roi}-internal.nii.gz
    ${mirtk_dir}/calculate-element-wise ${segdir}/${subj}-${cc_labels_roi}.nii.gz -binarize 0.5 -o ${segdir}/cc.nii.gz
    ${mirtk_dir}/dilate-image ${segdir}/cc.nii.gz ${segdir}/cc.nii.gz
    ${mirtk_dir}/calculate-element-wise ${segdir}/cc.nii.gz -add -1 -mul -1 = ${segdir}/inv-cc.nii.gz
    ${mirtk_dir}/calculate-element-wise ${segdir}/cc.nii.gz -mul 20 = ${segdir}/cc.nii.gz 
    ${mirtk_dir}/calculate-element-wise ${segdir}/${subj}-${bounti_labels_roi}-internal.nii.gz -mul ${segdir}/inv-cc.nii.gz -add ${segdir}/cc.nii.gz = ${segdir}/${subj}-${bounti_cc_labels_roi}.nii.gz
    ${mirtk_dir}/fix-internal ${segdir}/${subj}-${bounti_cc_labels_roi}.nii.gz ${segdir}/${subj}-${bounti_cc_labels_roi}.nii.gz 20 23

    cp ${segdir}/${subj}-${bounti_cc_labels_roi}.nii.gz ${segdir}/${subj}-${bounti_cc_labels_roi}-ORG.nii.gz


    ${mirtk_dir}/calculate-element-wise ${segdir}/${subj}-${cc_labels_roi}.nii.gz -binarize 0.5 -o ${segdir}/cc-org.nii.gz
     ${mirtk_dir}/extract-connected-components ${segdir}/cc-org.nii.gz ${segdir}/cc-org.nii.gz
    # ${mirtk_dir}/dilate-image ${segdir}/cc-org.nii.gz ${segdir}/cc-org.nii.gz
    # ${mirtk_dir}/erode-image ${segdir}/cc-org.nii.gz ${segdir}/cc-org.nii.gz


    ${mirtk_dir}/fix-wings ${segdir}/${subj}-${bounti_cc_labels_roi}-ORG.nii.gz ${segdir}/${subj}-${bounti_labels_roi}.nii.gz ${segdir}/cc-org.nii.gz ${segdir}/${subj}-${internal_labels_roi}.nii.gz ${segdir}/${subj}-${bounti_cc_labels_roi}.nii.gz



fi

echo
echo ".........................................................................."
echo ".........................................................................."
echo



completed=1
for surf in white pial;do
    for h in L R;do
        if [ ! -f ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk ];then
            completed=0
        fi
    done
done

echo " - Extracting surfaces (recon-neonatal-cortex) ..."
if [ ${completed} -eq 0 ]; then

    echo  /home/data/recon_config-bounti.cfg

    python3 ${mirtk_dir}/recon-neonatal-cortex --config /home/data/bin/recon_config-bounti.cfg --sessions=${subj} --prefix=surfaces/${subj}/vtk/${subj} --temp=surfaces/${subj}/vtk/temp-recon/${subj} --white --pial --verbose

fi



if  [ ! -f ${outvtk}/${subj}.L.pial.native.surf.vtk ];then


    echo ${subj} >  /home/bin/rerun/${subj}.txt

    exit 

fi 

echo
echo ".........................................................................."
echo ".........................................................................."
echo

echo " - Processing surfaces ..."
for hi in {0..1}; do

    h=${Hemi[$hi]}

    if [ "${h}" == "L" ];then
        C='CORTEX_LEFT'
    elif [ "${h}" == "R" ];then
        C='CORTEX_RIGHT';
    else 
        echo "hemisphere must be either L or R";exit 1;
    fi

    hs=`echo ${h} | tr '[:upper:]' '[:lower:]'`h

    mkdir -p ${outvtk} ${outwb} ${outtmp}

    echo "process surfaces for ${h} hemisphere"


    ###################### WHITE SURFACE ###################################################################

    surf='white'
    if  [ ! -f ${outwb}/${subj}.${h}.${surf}.native.surf.gii ];then
        vtktogii ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk ${outwb}/${subj}.${h}.${surf}.native.surf.gii ANATOMICAL GRAY_WHITE
    fi

    if  [ ! -f ${outwb}/${subj}.${h}.curvature.native.shape.gii ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Process ${h} curvature"
        ${mirtk_dir}/calculate-surface-attributes ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk ${outvtk}/${hs}.curvature.vtk -H Curvature -smooth-weighting Combinatorial -smooth-iterations 10 -vtk-curvatures 
        ${mirtk_dir}/calculate-element-wise ${outvtk}/${hs}.curvature.vtk -mul -1 -scalars Curvature -out ${outvtk}/${hs}.curvature.vtk
        giimap ${outvtk}/${hs}.curvature.vtk ${outwb}/${subj}.${h}.curvature.native.shape.gii Curvature Curvature
        ${wb_dir}/wb_command -metric-dilate ${outwb}/${subj}.${h}.curvature.native.shape.gii ${outwb}/${subj}.${h}.${surf}.native.surf.gii 10 ${outwb}/${subj}.${h}.curvature.native.shape.gii -nearest
    fi
    
    

    ###################### PIAL SURFACE ###################################################################

    surf='pial'
    if  [ ! -f ${outwb}/${subj}.${h}.${surf}.native.surf.gii ];then
        vtktogii ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk ${outwb}/${subj}.${h}.${surf}.native.surf.gii ANATOMICAL PIAL
    fi

    ###################### MID-THICKNESS SURFACE ###################################################################

    insurf1='white'; insurf2='pial'; surf='midthickness'
    if  [ ! -f ${outwb}/${subj}.${h}.${surf}.native.surf.gii ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Extract ${h} mid-thickness surface"
        ${mirtk_dir}/mid-surface ${outvtk}/${subj}.${h}.${insurf1}.native.surf.vtk ${outvtk}/${subj}.${h}.${insurf2}.native.surf.vtk ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk -ascii
        vtktogii ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk ${outwb}/${subj}.${h}.${surf}.native.surf.gii ANATOMICAL MIDTHICKNESS
    fi
    

    if  [ ! -f ${outwb}/${subj}.${h}.thickness.native.shape.gii ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Process ${h} thickness"
        ${mirtk_dir}/evaluate-distance ${outvtk}/${subj}.${h}.${insurf1}.native.surf.vtk ${outvtk}/${subj}.${h}.${insurf2}.native.surf.vtk ${outvtk}/${hs}.dist1.vtk -name Thickness
        ${mirtk_dir}/evaluate-distance ${outvtk}/${subj}.${h}.${insurf2}.native.surf.vtk ${outvtk}/${subj}.${h}.${insurf1}.native.surf.vtk ${outvtk}/${hs}.dist2.vtk -name Thickness
        ${mirtk_dir}/calculate-element-wise ${outvtk}/${hs}.dist1.vtk -scalars Thickness -add ${outvtk}/${hs}.dist2.vtk Thickness -div 2 -o ${outvtk}/${hs}.thickness.vtk
        giimap ${outvtk}/${hs}.thickness.vtk ${outwb}/${subj}.${h}.thickness.native.shape.gii Thickness Thickness
        ${wb_dir}/wb_command -metric-dilate ${outwb}/${subj}.${h}.thickness.native.shape.gii ${outwb}/${subj}.${h}.${insurf1}.native.surf.gii 10 ${outwb}/${subj}.${h}.thickness.native.shape.gii -nearest
    fi

    ###################### INFLATED SURFACE ###################################################################

    insurf='white'; surf='inflated_for_sphere'
    if  [ ! -f ${outwb}/${subj}.${h}.sulc.native.shape.gii ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Extract ${h} inflated surface from white (for sphere)"
        ${mirtk_dir}/deform-mesh ${outvtk}/${subj}.${h}.$insurf.native.surf.vtk ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk -inflate-brain -track SulcalDepth
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Process ${h} sulcal depth"
        giimap ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk ${outwb}/${subj}.${h}.sulc.native.shape.gii SulcalDepth Sulc
    fi

    insurf='midthickness'; surf='inflated'; surf2='very_inflated'
    if  [ ! -f ${outvtk}/${subj}.${h}.${surf2}.native.surf.vtk ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Extract ${h} inflated surface from midthickness (for workbench)"
        ${wb_dir}/wb_command -surface-generate-inflated ${outwb}/${subj}.${h}.$insurf.native.surf.gii ${outwb}/${subj}.${h}.${surf}.native.surf.gii ${outwb}/${subj}.${h}.${surf2}.native.surf.gii -iterations-scale 2.5
        ${mirtk_dir}/convert-pointset ${outwb}/${subj}.${h}.${surf}.native.surf.gii ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk
        ${mirtk_dir}/convert-pointset ${outwb}/${subj}.${h}.${surf2}.native.surf.gii ${outvtk}/${subj}.${h}.${surf2}.native.surf.vtk
    fi

    ###################### SPHERICAL SURFACE ###################################################################

    insurf1='white'; insurf2='inflated_for_sphere'; surf='sphere'
    if  [ ! -f ${outwb}/${subj}.${h}.${surf}.native.surf.gii ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Extract ${h} spherical surface"

        # v1.1 had this mesh-to-sphere, but it caused large distortions since the
        # templates were not being warped in the same way (I think). We've now
        # switched back to the original scheme.

        # comm="mesh-to-sphere ${outvtk}/${subj}.${h}.${insurf1}.native.surf.vtk ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk -inflated ${outvtk}/${subj}.${h}.${insurf2}.native.surf.vtk -parin ${parameters_dir}/spherical-mesh.cfg"
        # echo ${comm}
        # ${comm}

        # it'd be nice to use run here, but mesh-to-sphere exits with code 1 even on
        # success
        #
        # run mesh-to-sphere \
        #	  ${outvtk}/${subj}.${h}.${insurf2}.native.surf.vtk \
        #	  ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk \
        #	  -parin ${parameters_dir}/parin-4-levels.cfg

        comm="${meshtosphere_dir}/mesh-to-sphere 
            ${outvtk}/${subj}.${h}.${insurf2}.native.surf.vtk
            ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk 
            -parin ${parameters_dir}/parin-4-levels.cfg"
        echo ${comm}
        ${comm}

        vtktogii \
            ${outvtk}/${subj}.${h}.${surf}.native.surf.vtk \
            ${outwb}/${subj}.${h}.${surf}.native.surf.gii SPHERICAL GRAY_WHITE

    fi 
    
    ###################### LABELS ###################################################################


    insurf1='midthickness'; insurf2='white'; surf='drawem'
    if  [ ! -f ${outwb}/${subj}.${h}.${surf}.native.label.gii ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Project ${h} Draw-EM labels"
        # exclude csf,out and dilate tissues to cover space
        ${mirtk_dir}/padding ${segdir}/${subj}-${bounti_labels_roi}.nii.gz ${segdir}/${subj}-${bounti_labels_roi}.nii.gz ${outvtk}/${hs}.mask.nii.gz 2 1 2 0 
        
        ${mirtk_dir}/dilate-labels ${outvtk}/${hs}.mask.nii.gz ${outvtk}/${hs}.mask.nii.gz -blur 1
        # exclude subcortical structures and dilate cortical labels to cover space
        ${mirtk_dir}/padding ${segdir}/${subj}-${bounti_labels_roi}.nii.gz ${segdir}/${subj}-${bounti_labels_roi}.nii.gz ${outvtk}/${hs}.labels.nii.gz 2 3 4 0 -invert
        if [ "${h}" == "L" ];then oh=R;else oh=L;fi
        ${mirtk_dir}/padding ${outvtk}/${hs}.labels.nii.gz ${segdir}/${subj}_${oh}_pial.nii.gz ${outvtk}/${hs}.labels.nii.gz 1 0 
            
        ${mirtk_dir}/dilate-labels ${outvtk}/${hs}.labels.nii.gz ${outvtk}/${hs}.labels.nii.gz -blur 1

        # project to surface

        ${mirtk_dir}/extend-image-slices ${outvtk}/${hs}.labels.nii.gz ${outvtk}/${hs}.labels.ext.nii.gz -xyz 10
        # TODO: replace the next (uncommented) line with the following
        ${mirtk_dir}/project-onto-surface ${outvtk}/${subj}.${h}.${insurf1}.native.surf.vtk ${outvtk}/${subj}.${h}.${surf}.native.label.vtk -labels ${outvtk}/${hs}.labels.ext.nii.gz -name curv -pointdata -smooth 10 -fill -min-ratio 0.05 
        # run surface-assign-labels ${outvtk}/${subj}.${h}.${insurf1}.native.surf.vtk ${outvtk}/${subj}.${h}.${surf}.native.label.vtk -labels ${outvtk}/${hs}.labels.ext.nii.gz -name curv -pointdata -smooth 10 -fill -min-ratio 0.05 
        
        # mask out the subcortical structures (both original and dilated)
        ${mirtk_dir}/copy-pointset-attributes ${outvtk}/${subj}.${h}.${insurf2}.native.surf.vtk ${outvtk}/${subj}.${h}.${surf}.native.label.vtk -celldata-as-pointdata RegionId
        ${mirtk_dir}/calculate-element-wise ${outvtk}/${subj}.${h}.${surf}.native.label.vtk -scalars RegionId -clamp 0 1 -mul curv -clamp-lt 0 -out ${outvtk}/${subj}.${h}.${surf}.native.label.vtk int curv
        ${mirtk_dir}/convert-pointset ${outvtk}/${subj}.${h}.${surf}.native.label.vtk ${outvtk}/${hs}.labels.shape.gii
        ${mirtk_dir}/copy-pointset-attributes ${outvtk}/${subj}.${h}.${surf}.native.label.vtk ${outvtk}/${subj}.${h}.${surf}.native.label.vtk -pointdata curv Labels
        ${mirtk_dir}/delete-pointset-attributes ${outvtk}/${subj}.${h}.${surf}.native.label.vtk ${outvtk}/${subj}.${h}.${surf}.native.label.vtk -pointdata curv -pointdata RegionId

        ${wb_dir}/wb_command -metric-label-import ${outvtk}/${hs}.labels.shape.gii ${parameters_dir}/LUT.txt ${outwb}/temp.${subj}.${h}.${surf}.native.label.gii -drop-unused-labels
        ${wb_dir}/wb_command -set-structure ${outwb}/temp.${subj}.${h}.${surf}.native.label.gii ${C}
        ${wb_dir}/wb_command -set-map-names ${outwb}/temp.${subj}.${h}.${surf}.native.label.gii -map 1 ${subj}_${h}_${surf}
        mv ${outwb}/temp.${subj}.${h}.${surf}.native.label.gii ${outwb}/${subj}.${h}.${surf}.native.label.gii
    fi


    insurf2=drawem
    if  [ ! -f ${outwb}/${subj}.${h}.roi.native.shape.gii ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Process ${h} roi"
        ${wb_dir}/wb_command -metric-math "(Labels > 0) * (thickness>0)" ${outwb}/temp.${subj}.${h}.roi.native.shape.gii -var Labels  ${outwb}/${subj}.${h}.${insurf2}.native.label.gii -var thickness ${outwb}/${subj}.${h}.thickness.native.shape.gii
        ${wb_dir}/wb_command -metric-fill-holes ${outwb}/${subj}.${h}.${insurf1}.native.surf.gii ${outwb}/temp.${subj}.${h}.roi.native.shape.gii ${outwb}/temp.${subj}.${h}.roi.native.shape.gii
        ${wb_dir}/wb_command -metric-remove-islands ${outwb}/${subj}.${h}.${insurf1}.native.surf.gii ${outwb}/temp.${subj}.${h}.roi.native.shape.gii ${outwb}/temp.${subj}.${h}.roi.native.shape.gii
        ${wb_dir}/wb_command -set-map-names ${outwb}/temp.${subj}.${h}.roi.native.shape.gii -map 1 ${subj}_${h}_ROI
        mv ${outwb}/temp.${subj}.${h}.roi.native.shape.gii ${outwb}/${subj}.${h}.roi.native.shape.gii
    fi


    if  [ ! -f ${outwb}/${subj}.${h}.corrThickness.native.shape.gii ];then
        echo
        echo "-------------------------------------------------------------------------------------"
        echo "Process ${h} corr thickness"
        ${wb_dir}/wb_command -metric-regression ${outwb}/${subj}.${h}.thickness.native.shape.gii ${outwb}/${subj}.${h}.corrThickness.native.shape.gii -roi ${outwb}/${subj}.${h}.roi.native.shape.gii -remove ${outwb}/${subj}.${h}.curvature.native.shape.gii
        ${wb_dir}/wb_command -set-map-name ${outwb}/${subj}.${h}.corrThickness.native.shape.gii 1 ${subj}_${h}_corrThickness
        ${wb_dir}/wb_command -metric-palette ${outwb}/${subj}.${h}.corrThickness.native.shape.gii MODE_USER_SCALE -pos-user 1 1.7 -neg-user 0 0 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
    fi


    cleanup

done


echo
echo ".........................................................................."
echo ".........................................................................."
echo

echo " - Processing outputs for WB ..."


if  [ ! -f ${outwb}/${subj}.sulc.native.dscalar.nii ];then
  ${wb_dir}/wb_command -cifti-create-dense-scalar ${outwb}/temp.${subj}.sulc.native.dscalar.nii -left-metric ${outwb}/${subj}.L.sulc.native.shape.gii -right-metric ${outwb}/${subj}.R.sulc.native.shape.gii
  ${wb_dir}/wb_command -set-map-names ${outwb}/temp.${subj}.sulc.native.dscalar.nii -map 1 "${subj}_Sulc"
  ${wb_dir}/wb_command -cifti-palette ${outwb}/temp.${subj}.sulc.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE ${outwb}/temp.${subj}.sulc.native.dscalar.nii -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true
  mv ${outwb}/temp.${subj}.sulc.native.dscalar.nii ${outwb}/${subj}.sulc.native.dscalar.nii
fi


if  [ ! -f ${outwb}/${subj}.curvature.native.dscalar.nii ];then
  ${wb_dir}/wb_command -cifti-create-dense-scalar ${outwb}/temp.${subj}.curvature.native.dscalar.nii -left-metric ${outwb}/${subj}.L.curvature.native.shape.gii -roi-left ${outwb}/${subj}.L.roi.native.shape.gii -right-metric ${outwb}/${subj}.R.curvature.native.shape.gii -roi-right ${outwb}/${subj}.R.roi.native.shape.gii
  ${wb_dir}/wb_command -set-map-names ${outwb}/temp.${subj}.curvature.native.dscalar.nii -map 1 "${subj}_Curvature"
  ${wb_dir}/wb_command -cifti-palette ${outwb}/temp.${subj}.curvature.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE ${outwb}/temp.${subj}.curvature.native.dscalar.nii -pos-percent 2 98 -palette-name Gray_Interp -disp-pos true -disp-neg true -disp-zero true
  mv ${outwb}/temp.${subj}.curvature.native.dscalar.nii ${outwb}/${subj}.curvature.native.dscalar.nii
fi



if  [ ! -f ${outwb}/${subj}.thickness.native.dscalar.nii ];then
  ${wb_dir}/wb_command -cifti-create-dense-scalar ${outwb}/temp.${subj}.thickness.native.dscalar.nii -left-metric ${outwb}/${subj}.L.thickness.native.shape.gii -roi-left ${outwb}/${subj}.L.roi.native.shape.gii -right-metric ${outwb}/${subj}.R.thickness.native.shape.gii -roi-right ${outwb}/${subj}.R.roi.native.shape.gii
  ${wb_dir}/wb_command -set-map-names ${outwb}/temp.${subj}.thickness.native.dscalar.nii -map 1 "${subj}_Thickness"
  ${wb_dir}/wb_command -cifti-palette ${outwb}/temp.${subj}.thickness.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE ${outwb}/temp.${subj}.thickness.native.dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
  mv ${outwb}/temp.${subj}.thickness.native.dscalar.nii ${outwb}/${subj}.thickness.native.dscalar.nii
fi




if  [ ! -f ${outwb}/${subj}.corr_thickness.native.dscalar.nii ];then
  ${wb_dir}/wb_command -cifti-create-dense-scalar ${outwb}/temp.${subj}.corrThickness.native.dscalar.nii -left-metric ${outwb}/${subj}.L.corrThickness.native.shape.gii -roi-left ${outwb}/${subj}.L.roi.native.shape.gii -right-metric ${outwb}/${subj}.R.corrThickness.native.shape.gii -roi-right ${outwb}/${subj}.R.roi.native.shape.gii
  ${wb_dir}/wb_command -set-map-names ${outwb}/temp.${subj}.corrThickness.native.dscalar.nii -map 1 "${subj}_corrThickness"
  ${wb_dir}/wb_command -cifti-palette ${outwb}/temp.${subj}.corrThickness.native.dscalar.nii MODE_AUTO_SCALE_PERCENTAGE ${outwb}/temp.${subj}.corrThickness.native.dscalar.nii -pos-percent 4 96 -interpolate true -palette-name videen_style -disp-pos true -disp-neg false -disp-zero false
  mv ${outwb}/temp.${subj}.corrThickness.native.dscalar.nii ${outwb}/${subj}.corrThickness.native.dscalar.nii
fi



if [ ! -f ${outwb}/${subj}.drawem.native.dlabel.nii ];then
  ${wb_dir}/wb_command -cifti-create-label ${outwb}/temp.${subj}.drawem.native.dlabel.nii -left-label ${outwb}/${subj}.L.drawem.native.label.gii -roi-left ${outwb}/${subj}.L.roi.native.shape.gii -right-label ${outwb}/${subj}.R.drawem.native.label.gii -roi-right ${outwb}/${subj}.R.roi.native.shape.gii
  ${wb_dir}/wb_command -set-map-names ${outwb}/temp.${subj}.drawem.native.dlabel.nii -map 1 ${subj}_drawem
  mv ${outwb}/temp.${subj}.drawem.native.dlabel.nii ${outwb}/${subj}.drawem.native.dlabel.nii
fi


if [ ! -f ${outwb}/${subj}.T2.nii.gz ];then
  ln ${t2dir}/${subj}.nii.gz  ${outwb}/${subj}.T2.nii.gz
fi

# add them to .spec file
cd ${outwb}
rm -f ${subj}.native.wb.spec


for hi in {0..1}; do
    h=${Hemi[$hi]}
    C=${Cortex[$hi]}

    for surf in "${Surf[@]}"; do
      if [ -f ${subj}.$h.${surf}.native.surf.gii ];then
        ${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.$h.${surf}.native.surf.gii
      fi
    done
done

C=INVALID
${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.sulc.native.dscalar.nii
${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.curvature.native.dscalar.nii
${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.thickness.native.dscalar.nii
${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.corrThickness.native.dscalar.nii
${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.drawem.native.dlabel.nii
${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.T2.nii.gz


echo
echo ".........................................................................."
echo ".........................................................................."
echo

cd ${workdir}

if [ -f ${outwb}/${subj}.corrThickness.native.dscalar.nii ];then

    echo " - Surface extraction worked :) "
    echo " - Final processing outputs are in : " ${workdir}
    
else

    echo " - Errors ... No output files :( "
    echo " - Something went wrong - please inspect the log."

fi

echo
echo ".........................................................................."
echo ".........................................................................."
echo




# if [ -f restore/T1/${subj}.nii.gz ];then
#   ${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.T1.nii.gz
#   ${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.T1wDividedByT2w_defaced.nii.gz
#   ${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.T1wDividedByT2w_ribbon.nii.gz
#   ${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.MyelinMap.native.dscalar.nii
#   ${wb_dir}/wb_command -add-to-spec-file ${subj}.native.wb.spec ${C} ${subj}.SmoothedMyelinMap.native.dscalar.nii
# fi












