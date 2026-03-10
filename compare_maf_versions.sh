#!/bin/bash
# Compare the three MAF versions

WORK_DIR="/scratch/frans/rna-seq"
OUTPUT="${WORK_DIR}/version_comparison.txt"

echo "MAF Version Comparison Report" > ${OUTPUT}
echo "=============================" >> ${OUTPUT}
echo "" >> ${OUTPUT}

printf "%-12s %12s %12s %12s\n" "Sample" "All" "Somatic" "PASS" >> ${OUTPUT}
printf "%-12s %12s %12s %12s\n" "------" "---" "-------" "----" >> ${OUTPUT}

for pair_id in pair_{01..66}; do
    ALL=$(grep -v "^#\|^Hugo_Symbol" \
          ${WORK_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf 2>/dev/null | wc -l)
    
    SOMATIC=$(grep -v "^#\|^Hugo_Symbol" \
              ${WORK_DIR}/results/funcotator_somatic_only/${pair_id}_somatic_only.maf 2>/dev/null | wc -l)
    
    PASS=$(grep -v "^#\|^Hugo_Symbol" \
           ${WORK_DIR}/results/funcotator_pass_only/${pair_id}_pass_only.maf 2>/dev/null | wc -l)
    
    printf "%-12s %12d %12d %12d\n" ${pair_id} ${ALL} ${SOMATIC} ${PASS} >> ${OUTPUT}
done

echo "" >> ${OUTPUT}
echo "Summary:" >> ${OUTPUT}

TOTAL_ALL=$(cat ${WORK_DIR}/results/funcotator_annotated/*.maf | grep -v "^#\|^Hugo_Symbol" | wc -l)
TOTAL_SOMATIC=$(cat ${WORK_DIR}/results/funcotator_somatic_only/*.maf | grep -v "^#\|^Hugo_Symbol" | wc -l)
TOTAL_PASS=$(cat ${WORK_DIR}/results/funcotator_pass_only/*.maf | grep -v "^#\|^Hugo_Symbol" | wc -l)

echo "Total All: ${TOTAL_ALL}" >> ${OUTPUT}
echo "Total Somatic: ${TOTAL_SOMATIC}" >> ${OUTPUT}
echo "Total PASS: ${TOTAL_PASS}" >> ${OUTPUT}

cat ${OUTPUT}