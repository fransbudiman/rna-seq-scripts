#!/bin/bash
# Calculate Tumor Mutation Burden for all samples

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
OUTPUT="${WORK_DIR}/mutation_burden_analysis.txt"

echo "Sample_ID,Total_Variants,Coding_Variants,TMB_per_Mb" > ${OUTPUT}

# Assuming ~30 Mb coding sequence coverage in WGS intervals
CODING_MB=30

for maf in ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf; do
    SAMPLE=$(basename ${maf} _pass_only.maf)
    
    TOTAL=$(grep -v "^#\|^Hugo_Symbol" ${maf} | wc -l)
    
    # Count coding variants (missense, nonsense, frameshift, splice)
    CODING=$(grep -v "^#\|^Hugo_Symbol" ${maf} | \
             grep "Missense_Mutation\|Nonsense_Mutation\|Frame_Shift\|Splice_Site" | \
             wc -l)
    
    TMB=$(awk "BEGIN {printf \"%.2f\", ${CODING}/${CODING_MB}}")
    
    echo "${SAMPLE},${TOTAL},${CODING},${TMB}" >> ${OUTPUT}
done

echo "Mutation burden analysis saved to: ${OUTPUT}"
cat ${OUTPUT}