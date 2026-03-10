#!/bin/bash
# Generate summary for all three MAF versions

WORK_DIR="/scratch/rad123/FINAL_MUTECT2_ANALYSIS"
OUTPUT="${WORK_DIR}/maf_summary_report.txt"

echo "================================================" > ${OUTPUT}
echo "MAF Annotation Summary - All Three Versions" >> ${OUTPUT}
echo "================================================" >> ${OUTPUT}
echo "Generated: $(date)" >> ${OUTPUT}
echo "" >> ${OUTPUT}

# Per-pair summary
echo "Per-Pair Variant Counts:" >> ${OUTPUT}
echo "------------------------" >> ${OUTPUT}
printf "%-12s %12s %12s %12s\n" "Pair" "All" "Somatic-Only" "PASS-Only" >> ${OUTPUT}

for pair_id in pair_{01..66}; do
    ALL_MAF="${WORK_DIR}/results/funcotator_annotated/${pair_id}_all_variants.maf"
    SOMATIC_MAF="${WORK_DIR}/results/funcotator_somatic_only/${pair_id}_somatic_only.maf"
    PASS_MAF="${WORK_DIR}/results/funcotator_pass_only/${pair_id}_pass_only.maf"
    
    if [ -f "${ALL_MAF}" ]; then
        ALL_COUNT=$(grep -v "^#" ${ALL_MAF} | grep -v "^Hugo_Symbol" | wc -l)
    else
        ALL_COUNT=0
    fi
    
    if [ -f "${SOMATIC_MAF}" ]; then
        SOMATIC_COUNT=$(grep -v "^Hugo_Symbol" ${SOMATIC_MAF} | wc -l)
    else
        SOMATIC_COUNT=0
    fi
    
    if [ -f "${PASS_MAF}" ]; then
        PASS_COUNT=$(grep -v "^Hugo_Symbol" ${PASS_MAF} | wc -l)
    else
        PASS_COUNT=0
    fi
    
    printf "%-12s %12s %12s %12s\n" ${pair_id} ${ALL_COUNT} ${SOMATIC_COUNT} ${PASS_COUNT} >> ${OUTPUT}
done

echo "" >> ${OUTPUT}

# Overall totals
echo "Overall Totals:" >> ${OUTPUT}
echo "---------------" >> ${OUTPUT}

TOTAL_ALL=0
TOTAL_SOMATIC=0
TOTAL_PASS=0

for maf in ${WORK_DIR}/results/funcotator_annotated/*_all_variants.maf; do
    COUNT=$(grep -v "^#" ${maf} | grep -v "^Hugo_Symbol" | wc -l)
    TOTAL_ALL=$((TOTAL_ALL + COUNT))
done

for maf in ${WORK_DIR}/results/funcotator_somatic_only/*_somatic_only.maf; do
    COUNT=$(grep -v "^Hugo_Symbol" ${maf} | wc -l)
    TOTAL_SOMATIC=$((TOTAL_SOMATIC + COUNT))
done

for maf in ${WORK_DIR}/results/funcotator_pass_only/*_pass_only.maf; do
    COUNT=$(grep -v "^Hugo_Symbol" ${maf} | wc -l)
    TOTAL_PASS=$((TOTAL_PASS + COUNT))
done

echo "Total all variants: ${TOTAL_ALL}" >> ${OUTPUT}
echo "Total somatic-only: ${TOTAL_SOMATIC}" >> ${OUTPUT}
echo "Total PASS-only: ${TOTAL_PASS}" >> ${OUTPUT}
echo "" >> ${OUTPUT}

echo "Averages per pair:" >> ${OUTPUT}
echo "  All: $((TOTAL_ALL / 66))" >> ${OUTPUT}
echo "  Somatic-only: $((TOTAL_SOMATIC / 66))" >> ${OUTPUT}
echo "  PASS-only: $((TOTAL_PASS / 66))" >> ${OUTPUT}

cat ${OUTPUT}