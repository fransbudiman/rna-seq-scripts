#!/bin/bash
# Summarize variant types per sample

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
OUTPUT="${WORK_DIR}/variant_classification_summary.txt"

echo "Sample,Missense,Nonsense,Frameshift_Ins,Frameshift_Del,Splice_Site,Silent,Total_Coding" > ${OUTPUT}

for maf in ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf; do
    SAMPLE=$(basename ${maf} _pass_only.maf)
    
    MISSENSE=$(grep "Missense_Mutation" ${maf} | wc -l)
    NONSENSE=$(grep "Nonsense_Mutation" ${maf} | wc -l)
    FS_INS=$(grep "Frame_Shift_Ins" ${maf} | wc -l)
    FS_DEL=$(grep "Frame_Shift_Del" ${maf} | wc -l)
    SPLICE=$(grep "Splice_Site" ${maf} | wc -l)
    SILENT=$(grep "Silent" ${maf} | wc -l)
    
    TOTAL_CODING=$((MISSENSE + NONSENSE + FS_INS + FS_DEL + SPLICE + SILENT))
    
    echo "${SAMPLE},${MISSENSE},${NONSENSE},${FS_INS},${FS_DEL},${SPLICE},${SILENT},${TOTAL_CODING}" >> ${OUTPUT}
done

echo "Variant classification summary saved to: ${OUTPUT}"

# Show summary statistics
echo ""
echo "Summary Statistics:"
awk -F',' 'NR>1 {miss+=$2; nons+=$3; fsi+=$4; fsd+=$5; splice+=$6; silent+=$7; total+=$8} 
            END {print "Total Missense:", miss; 
                 print "Total Nonsense:", nons; 
                 print "Total Frameshift Ins:", fsi;
                 print "Total Frameshift Del:", fsd;
                 print "Total Splice Site:", splice;
                 print "Total Silent:", silent;
                 print "Total Coding:", total}' ${OUTPUT}